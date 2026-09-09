import 'package:flutter/foundation.dart';
import 'package:stok_anandam/core/auth/current_user_store.dart';
import 'package:stok_anandam/core/auth/global_state_resetter.dart';
import 'package:stok_anandam/core/services/delivery_location_service.dart';
import 'package:stok_anandam/core/services/heartbeat_service.dart';
import 'package:stok_anandam/injection.dart';
import 'package:stok_anandam/token_storage.dart';
import 'package:my_api_client/my_api_client.dart';
import 'package:dio/dio.dart';

class AuthService {
  bool _isLoggingOut = false;

  /// Melakukan logout: Invalidate token di backend, hapus local storage, dan reset state.
  Future<void> logout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    try {
      // 1. Panggil API Logout di backend (best effort)
      // Kirim refreshToken agar backend bisa menghapus sesi yang tepat
      final refreshToken = getIt<TokenStorage>().refreshToken;
      final accessToken = getIt<TokenStorage>().token;

      // Gunakan Dio terpisah untuk menghindari interceptor loop
      final logoutDio = Dio(BaseOptions(
        baseUrl: getIt<MyApiClient>().dio.options.baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        },
      ));

      await logoutDio.post('/api/v1/auth/logout', data: {
        if (refreshToken != null) 'refreshToken': refreshToken,
      });
      debugPrint('[AuthService] Backend logout berhasil.');
    } catch (e) {
      // Abaikan error jika gagal panggil API logout (misal karena token sudah expired)
      debugPrint('[AuthService] Backend logout gagal (expected): $e');
    } finally {
      // 2. Clear local storage
      await getIt<TokenStorage>().clear();
      getIt<CurrentUserStore>().clear();

      // 3. Reset all static filter states
      GlobalStateResetter.resetAll();

      // 4. Hentikan heartbeat (user tidak lagi login)
      HeartbeatService.instance.stop();
      // 5. Hentikan semua GPS tracking delivery (sisa queue tetap di-flush).
      DeliveryLocationService.instance.stopAll();
      
      _isLoggingOut = false;
    }
  }

  /// Pengecekan session habis secara manual/proaktif jika dibutuhkan.
  /// Biasanya ditangani oleh AuthRefreshInterceptor.
  void handleSessionExpired() {
    logout();
  }
}
