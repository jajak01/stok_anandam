import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:stok_anandam/core/auth/current_user_store.dart';
import 'package:stok_anandam/core/widgets/app_feedback.dart';
import 'package:stok_anandam/core/widgets/app_version_label.dart';
import 'package:stok_anandam/core/routing/app_router.dart';
import 'package:stok_anandam/injection.dart';
import 'package:local_auth/local_auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:stok_anandam/token_storage.dart';
import '../../../Biometric/api/biometric_api.dart';
import '../../../Biometric/repositories/biometric_repository.dart';
import '../../../Biometric/services/biometric_crypto_service.dart';
import '../../../../core/network/websocket_service.dart';
import '../auth_bloc.dart';
import '../auth_event.dart';
import '../auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscurePassword = true;
  String? _serverBusyMessage;

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  static const double _breakpoint = 850;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= _breakpoint;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB), // Light crisp canvas
      body: Stack(
        children: [
          // Ambient Background Blobs
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.22),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -60,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.lightBlue.withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.sizeOf(context).height * 0.4,
            right: -100,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.indigoAccent.withValues(alpha: 0.12),
              ),
            ),
          ),

          // Gaussian Blur Overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
              child: Container(
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ),

          // Main Responsive Content Body
          SafeArea(
            child: BlocConsumer<AuthBloc, AuthState>(
              buildWhen: (previous, current) =>
                  previous.runtimeType != current.runtimeType,
              listener: (context, state) {
                if (state is AuthSuccess) {
                  final userId = getIt<CurrentUserStore>().userId?.toString();
                  final name = getIt<CurrentUserStore>().displayName;
                  if (userId != null && userId.isNotEmpty) {
                    getIt<WebSocketService>().connectPresence(
                      userId: userId,
                      name: name,
                    );
                  }

                  final userRole =
                      getIt<CurrentUserStore>().userRole?.toUpperCase();
                  if (userRole == null) return;

                  if (userRole == 'TEKNISI' || userRole == 'DELIVERY') {
                    context.go(AppRoutes.pengiriman);
                  } else if (userRole.contains('NOTA')) {
                    context.go(AppRoutes.memo);
                  } else if (userRole == 'GUDANG' ||
                      userRole.startsWith('MARKETING')) {
                    context.go(AppRoutes.stok);
                  } else {
                    context.go(AppRoutes.stok);
                  }
                } else if (state is AuthFailure) {
                  if (state.isDeactivated) {
                    context.go(AppRoutes.accessDenied);
                  } else {
                    AppFeedback.showError(context, state.error);
                  }
                } else if (state is AuthInitial) {
                  setState(() => _serverBusyMessage = null);
                }
              },
              builder: (context, state) {
                if (state is AuthServerBusy) {
                  _serverBusyMessage = state.message;
                } else if (state is AuthInitial || state is AuthLoading) {
                  // Keep banner during loading
                } else {
                  _serverBusyMessage = null;
                }

                Widget? serverBanner;
                if (state is AuthServerBusy ||
                    (_serverBusyMessage != null &&
                        state is! AuthSuccess &&
                        state is! AuthFailure)) {
                  serverBanner = _ServerBusyBanner(
                    message: _serverBusyMessage ?? 'Server sedang sibuk...',
                    isRetrying: state is AuthServerBusy && state.isRetrying,
                  );
                }

                return Column(
                  children: [
                    if (serverBanner != null) serverBanner,
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24.0),
                          child: isWide
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 460),
                                      child: _FormPanel(
                                        userController: _userController,
                                        passController: _passController,
                                        obscurePassword: _obscurePassword,
                                        onTogglePassword: () => setState(() =>
                                            _obscurePassword =
                                                !_obscurePassword),
                                        isLoading: state is AuthLoading,
                                        onSubmit: () {
                                          context.read<AuthBloc>().add(
                                                LoginSubmitted(
                                                    _userController.text,
                                                    _passController.text),
                                              );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 32),
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 420),
                                      child: const _IllustrationPanel(),
                                    ),
                                  ],
                                )
                              : ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 440),
                                  child: _FormPanel(
                                    userController: _userController,
                                    passController: _passController,
                                    obscurePassword: _obscurePassword,
                                    onTogglePassword: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                    isLoading: state is AuthLoading,
                                    onSubmit: () {
                                      context.read<AuthBloc>().add(
                                            LoginSubmitted(_userController.text,
                                                _passController.text),
                                          );
                                    },
                                  ),
                                ),
                        ),
                      ),
                    ),
                    // Versi aplikasi (dari pubspec.yaml) di bagian bawah layar,
                    // supaya pengguna tahu build mana yang sedang dipakai.
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14, top: 4),
                      child: AppVersionLabel(
                        textStyle: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Glassmorphic Server Busy Banner
class _ServerBusyBanner extends StatelessWidget {
  final String message;
  final bool isRetrying;

  const _ServerBusyBanner({
    required this.message,
    this.isRetrying = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: Colors.amber.shade200.withValues(alpha: 0.8),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sync_problem_rounded,
            color: Colors.amber.shade900,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Server Tidak Tersedia',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF451A03),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber.shade900,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (isRetrying)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.amber.shade900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FormPanel extends StatefulWidget {
  const _FormPanel({
    required this.userController,
    required this.passController,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.isLoading,
    required this.onSubmit,
  });

  final TextEditingController userController;
  final TextEditingController passController;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  State<_FormPanel> createState() => _FormPanelState();
}

class _FormPanelState extends State<_FormPanel> {
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  final _localAuth = LocalAuthentication();
  late final BiometricRepository _biometricRepository;
  String? _deviceId;
  bool _hasBiometricKeys = false;
  bool _canCheckBiometrics = false;
  bool _isLoadingBiometric = false;

  @override
  void initState() {
    super.initState();
    final dio = getIt<Dio>();
    const storage = FlutterSecureStorage();
    _biometricRepository = BiometricRepository(
      BiometricApi(dio),
      BiometricCryptoService(storage),
    );
    _initBiometric();
  }

  Future<void> _initBiometric() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      String deviceId;
      try {
        final deviceInfo = DeviceInfoPlugin();
        try {
          final androidInfo = await deviceInfo.androidInfo;
          deviceId = androidInfo.id;
        } catch (_) {
          try {
            final iosInfo = await deviceInfo.iosInfo;
            deviceId = iosInfo.identifierForVendor ?? 'ios-fallback';
          } catch (_) {
            deviceId = 'device-fallback';
          }
        }
      } catch (_) {
        deviceId = 'device-fallback';
      }

      final hasKeys =
          await _biometricRepository.isBiometricAvailable(deviceId);

      if (mounted) {
        setState(() {
          _deviceId = deviceId;
          _canCheckBiometrics = canCheckBiometrics || isDeviceSupported;
          _hasBiometricKeys = hasKeys;
        });
      }
    } catch (e) {
      debugPrint('[LoginPage] Biometric init error: $e');
    }
  }

  Future<void> _handleBiometricLogin() async {
    if (!_canCheckBiometrics) {
      AppFeedback.showError(
          context, 'Perangkat Anda tidak mendukung autentikasi biometrik.');
      return;
    }

    if (!_hasBiometricKeys || _deviceId == null) {
      if (mounted) {
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white.withValues(alpha: 0.95),
            title: const Text('Biometrik Belum Aktif',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text(
              'Untuk menggunakan login biometrik, silakan:\n\n'
              '1. Login menggunakan username & password\n'
              '2. Masuk ke menu Profile\n'
              '3. Aktifkan Biometric di pengaturan profil\n\n'
              'Setelah itu, login biometrik sudah bisa digunakan.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Mengerti',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoadingBiometric = true;
    });

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Scan fingerprint untuk login',
      );

      if (!authenticated) {
        if (mounted) {
          AppFeedback.showError(
              context, 'Autentikasi biometrik dibatalkan atau gagal.');
        }
        setState(() {
          _isLoadingBiometric = false;
        });
        return;
      }

      final token = await _biometricRepository.loginWithBiometric(_deviceId!);
      await getIt<TokenStorage>().setTokens(accessToken: token);

      try {
        await getIt<CurrentUserStore>().loadFromApi().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('[BiometricLogin] User info load timeout');
            return;
          },
        );
      } catch (e) {
        debugPrint('[BiometricLogin] User info load error: $e');
      }

      if (mounted) {
        final userRole = getIt<CurrentUserStore>().userRole?.toUpperCase();
        if (userRole == 'TEKNISI' || userRole == 'DELIVERY') {
          context.go(AppRoutes.pengiriman);
        } else if (userRole != null && userRole.contains('NOTA')) {
          context.go(AppRoutes.memo);
        } else if (userRole == 'GUDANG' ||
            (userRole != null && userRole.startsWith('MARKETING'))) {
          context.go(AppRoutes.stok);
        } else {
          context.go(AppRoutes.dashboard);
        }
      }
    } catch (e) {
      bool unregistered = false;
      if (e is DioException) {
        final response = e.response;
        if (response?.statusCode == 401) {
          final data = response?.data;
          final message = data is Map ? data['message']?.toString() : '';
          if (message != null && message.contains('Device not registered')) {
            unregistered = true;
          }
        }
      }

      if (unregistered && _deviceId != null) {
        try {
          await _biometricRepository.deleteBiometricKeys(_deviceId!);
          setState(() {
            _hasBiometricKeys = false;
          });
        } catch (_) {}
      }

      if (mounted) {
        AppFeedback.showError(
          context,
          unregistered
              ? 'Perangkat ini belum terdaftar di server. Silakan daftarkan biometrik Anda.'
              : 'Gagal login biometrik: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBiometric = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo Badge & Branding Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.15),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: SvgPicture.asset(
                  'assets/images/icon-anandam.svg',
                  width: 34,
                  height: 34,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Movva',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: Color(0xFF1A1C24),
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'by Anandam.id',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Title & Description
          const Text(
            'Selamat Datang',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1C24),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Masuk ke sistem manajemen stok Anda.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF5A607F),
              height: 1.4,
            ),
          ),

          const SizedBox(height: 32),

          // Username Field
          const Text(
            'Username',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: widget.userController,
            focusNode: _usernameFocusNode,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              hintText: 'Masukkan username',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.9)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: primaryColor, width: 1.8),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            ),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _passwordFocusNode.requestFocus(),
          ),

          const SizedBox(height: 20),

          // Password Field
          const Text(
            'Password',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: widget.passController,
            focusNode: _passwordFocusNode,
            obscureText: widget.obscurePassword,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              hintText: 'Masukkan password',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.9)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: primaryColor, width: 1.8),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              suffixIcon: IconButton(
                icon: Icon(
                  widget.obscurePassword
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: const Color(0xFF64748B),
                  size: 20,
                ),
                onPressed: widget.onTogglePassword,
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => widget.onSubmit(),
          ),

          const SizedBox(height: 32),

          // Action Buttons: Login & Biometric
          Row(
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (widget.isLoading || _isLoadingBiometric)
                        ? null
                        : widget.onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: primaryColor.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: widget.isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'LOGIN',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: (_isLoadingBiometric || widget.isLoading)
                        ? null
                        : _handleBiometricLogin,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      backgroundColor: Colors.white.withValues(alpha: 0.7),
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: _isLoadingBiometric
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: primaryColor,
                            ),
                          )
                        : Icon(Icons.fingerprint_rounded,
                            size: 26, color: primaryColor),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Glassmorphic Decorative Illustration Panel (for Desktop/Tablet wide mode)
class _IllustrationPanel extends StatelessWidget {
  const _IllustrationPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      height: 480,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.7),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Rings
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withValues(alpha: 0.08),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
          ),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withValues(alpha: 0.12),
            ),
          ),

          // Central Glass SVG Logo
          // Change Container shape to RoundedRectangle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 108, 153, 221).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24), // Box instead of Circle
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SvgPicture.asset(
              'assets/images/anandam-logo.svg',
              width: 180, // Allow horizontal space for the full logo
            ),
          )
        ],
      ),
    );
  }
}