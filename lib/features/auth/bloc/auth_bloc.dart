import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stok_anandam/core/auth/current_user_store.dart';
import 'package:stok_anandam/core/errors/app_errors.dart';
import 'package:my_api_client/my_api_client.dart';
import 'package:stok_anandam/core/network/websocket_service.dart';
import '../../../../injection.dart';
import '../../../../token_storage.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final authApi = getIt<AuthControllerApi>();

  /// Menyimpan kredensial terakhir untuk auto-retry saat server sibuk.
  String? _lastUsername;
  String? _lastPassword;

  /// Timer untuk auto-retry.
  Timer? _retryTimer;

  /// Hitung berapa kali retry sudah dilakukan (untuk exponential backoff).
  int _retryCount = 0;
  static const int _maxRetries = 10;
  static const Duration _initialRetryDelay = Duration(seconds: 3);

  AuthBloc() : super(AuthInitial()) {
    on<LoginSubmitted>((event, emit) async {
      // Cancel retry yang sedang berjalan jika user mencoba login ulang
      _cancelRetry();
      _lastUsername = event.username;
      _lastPassword = event.password;
      _retryCount = 0;
      await _performLogin(event.username, event.password, emit);
    });

    on<RetryLogin>((event, emit) async {
      await _performLogin(event.username, event.password, emit);
    });
  }
Future<void> _performLogin(
    String username,
    String password,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      debugPrint(
          '[AuthBloc] Attempting login with username: $username');
      final response = await authApi.login(
        loginUserRequest: LoginUserRequest(
          username: username,
          password: password,
        ),
      );

      final data = response.data?.data;
      debugPrint('[AuthBloc] Login response data: $data');
      final token = data?.accessToken?.toString() ?? "";
      final refresh = data?.refreshToken?.toString();

      if (token.isNotEmpty) {
        // Cancel retry jika ada — login berhasil
        _cancelRetry();
        _retryCount = 0;

        await getIt<TokenStorage>()
            .setTokens(accessToken: token, refreshToken: refresh);

        // Load user data with a short timeout to keep login feeling fast.
        try {
          debugPrint('AuthBloc: Background loading user info...');
          await getIt<CurrentUserStore>().loadFromApi().timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              debugPrint(
                  'AuthBloc: User info load is taking longer than 3s, proceeding in background.');
              return;
            },
          ).catchError((e) {
            debugPrint('AuthBloc: Background user info load error: $e');
          });
        } catch (e) {
          debugPrint('AuthBloc: Error initiating user info load: $e');
        }

        // Aktifkan WebSocket setelah login berhasil
        final userId = getIt<CurrentUserStore>().userId?.toString();
        final name = getIt<CurrentUserStore>().displayName;
        getIt<WebSocketService>().connect(userId: userId, name: name);
        emit(AuthSuccess(token));
      } else {
        emit(AuthFailure("Login Gagal: Token tidak ditemukan."));
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;

      // 403: Akun dinonaktifkan
      if (status == 403) {
        _cancelRetry();
        final serverMsg = _extractMessage(body);
        emit(AuthFailure(
          serverMsg ?? 'Akun Anda telah dinonaktifkan.',
          isDeactivated: true,
        ));
        return;
      }

      // Server error (502/503/504): server sibuk atau restart
      if (status == 502 || status == 503 || status == 504) {
        _scheduleRetry(emit,
            message: 'Server sedang sibuk atau dalam perbaikan. '
                'Menunggu server siap...');
        return;
      }

      // Error koneksi / timeout: server tidak bisa dihubungi
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        _scheduleRetry(emit,
            message: 'Tidak dapat terhubung ke server. '
                'Pastikan koneksi internet Anda stabil. '
                'Mencoba lagi secara otomatis...');
        return;
      }

      // Other HTTP errors (400, 401, 422, 500, dll): kegagalan login biasa
      _cancelRetry();
      String message = 'Password salah atau username salah.';
      if (status == 401) {
        final serverMsg = _extractMessage(body);
        message = serverMsg ?? 'Password atau username salah.';
      } else if (status != null && status >= 500 && status < 600) {
        message = 'Server mengalami gangguan internal. Coba lagi nanti.';
      } else {
        message = AppErrors.userMessageFromDio(e);
      }

      emit(AuthFailure(message));
    } catch (e) {
      _cancelRetry();
      emit(AuthFailure(AppErrors.userMessageFromException(e,
          fallback: 'Login gagal. Coba lagi.')));
    }
  }

  /// Jadwalkan retry otomatis setelah delay (exponential backoff).
  void _scheduleRetry(Emitter<AuthState> emit, {required String message}) {
    _retryCount++;
    if (_retryCount > _maxRetries) {
      // Sudah terlalu banyak retry, beri tahu user dan berhenti
      emit(AuthServerBusy(
        'Server tidak merespon setelah beberapa kali percobaan. '
        'Silakan coba lagi nanti atau hubungi administrator.',
      ));
      return;
    }

    // Exponential backoff: 3s, 6s, 12s, 24s, ... (max 60s)
    final delay = Duration(
      seconds: (_initialRetryDelay.inSeconds * (1 << (_retryCount - 1)))
          .clamp(1, 60),
    );

    emit(AuthServerBusy(
      message,
      isRetrying: true,
    ));

    debugPrint(
        '[AuthBloc] Server busy. Auto-retry #$_retryCount in ${delay.inSeconds}s...');

    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (!isClosed && _lastUsername != null && _lastPassword != null) {
        debugPrint('[AuthBloc] Auto-retry #$_retryCount...');
        add(RetryLogin(_lastUsername!, _lastPassword!));
      }
    });
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  @override
  Future<void> close() {
    _cancelRetry();
    return super.close();
  }

  static String? _extractMessage(dynamic body) {
    if (body == null) return null;
    if (body is Map && body['message'] != null) {
      return body['message'].toString();
    }
    if (body is String) return body.isNotEmpty ? body : null;
    return null;
  }
}

/// Event untuk auto-retry login saat server sibuk.
class RetryLogin extends AuthEvent {
  final String username;
  final String password;
  RetryLogin(this.username, this.password);
}
