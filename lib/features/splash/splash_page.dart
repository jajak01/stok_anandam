import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:stok_anandam/core/auth/current_user_store.dart';
import 'package:stok_anandam/core/routing/app_router.dart';
import 'package:stok_anandam/core/widgets/app_version_label.dart';
import 'package:stok_anandam/injection.dart';
import 'package:stok_anandam/token_storage.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _progressController;
  late AnimationController _backgroundController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _textSlideAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _backgroundAnimation;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat(reverse: true);

    _logoScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(_logoController);

    _logoRotationAnimation = Tween<double>(
      begin: -0.05,
      end: 0.05,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    ));

    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));

    _textSlideAnimation = Tween<double>(
      begin: 25.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOutQuint,
    ));

    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));

    _startAnimations();
  }

  void _startAnimations() async {
    await _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _textController.forward();
    _progressController.forward();
    _backgroundController.repeat(reverse: true);

    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    final tokenStorage = getIt<TokenStorage>();
    final hasToken =
        tokenStorage.token != null && tokenStorage.token!.isNotEmpty;

    bool loadSuccess = false;
    bool serverUnavailable = false;

    if (hasToken) {
      try {
        debugPrint('[Splash] Token found. Loading current user data...');
        await getIt<CurrentUserStore>().loadFromApi().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint(
                '[Splash] CurrentUserStore.loadFromApi() timed out after 3s.');
            serverUnavailable = true;
          },
        );

        if (!mounted) return;
        loadSuccess = getIt<CurrentUserStore>().userRole != null;
        debugPrint(
            '[Splash] User data load ${loadSuccess ? 'success' : 'failed'}. Role: ${getIt<CurrentUserStore>().userRole}');
      } catch (e) {
        debugPrint('[Splash] Error loading user data: $e');
        if (e is DioException) {
          final type = e.type;
          final status = e.response?.statusCode;
          if (type == DioExceptionType.connectionTimeout ||
              type == DioExceptionType.sendTimeout ||
              type == DioExceptionType.receiveTimeout ||
              type == DioExceptionType.connectionError ||
              status == 502 || status == 503 || status == 504) {
            serverUnavailable = true;
          }
        }
        loadSuccess = false;
      }
    } else {
      debugPrint('[Splash] No token found.');
    }

    if (!mounted) return;

    if (hasToken && serverUnavailable) {
      debugPrint('[Splash] Server unavailable. Redirecting to login page.');
      getIt<CurrentUserStore>().clear();
      context.go(AppRoutes.login);
      return;
    }

    if (hasToken) {
      final userRole = getIt<CurrentUserStore>().userRole?.toUpperCase();
      debugPrint('[Splash] Token exists. Role: $userRole');

      if (userRole == 'TEKNISI' || userRole == 'DELIVERY') {
        context.go(AppRoutes.pengiriman);
      } else if (userRole != null && userRole.contains('NOTA')) {
        context.go(AppRoutes.memo);
      } else if (userRole == 'GUDANG' ||
          (userRole != null && userRole.startsWith('MARKETING'))) {
        context.go(AppRoutes.stok);
      } else if (userRole == 'ADMIN' ||
          (userRole != null && userRole.startsWith('SPV_'))) {
        context.go(AppRoutes.dashboard);
      } else {
        if (!loadSuccess) {
          debugPrint('[Splash] Token exists but user data not loaded. Clearing token.');
          await tokenStorage.clear();
          context.go(AppRoutes.login);
        } else {
          context.go(AppRoutes.stok);
        }
      }
    } else {
      debugPrint('[Splash] No token found. Navigating to Login.');
      context.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _progressController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB), // Light crisp background
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _logoController,
          _textController,
          _progressController,
          _backgroundController,
        ]),
        builder: (context, child) {
          final primaryColor = colorScheme.primary;

          return Stack(
            children: [
              // Ambient Light Colored Blobs in Background
              Positioned(
                top: -60 + (_backgroundAnimation.value * 35),
                left: -40,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withValues(alpha: 0.25),
                  ),
                ),
              ),
              Positioned(
                bottom: -80 - (_backgroundAnimation.value * 25),
                right: -40,
                child: Container(
                  width: 340,
                  height: 340,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.lightBlue.withValues(alpha: 0.2),
                  ),
                ),
              ),

              // Gaussian Blur Layer
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),

              // Light Glassmorphic Central Card
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 48, horizontal: 28),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 30,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Glass Badge for Logo
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Transform.scale(
                                  scale: _logoScaleAnimation.value * 1.2,
                                  child: Container(
                                    width: 130,
                                    height: 130,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          primaryColor.withValues(alpha: 0.15),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Transform.scale(
                                  scale: _logoScaleAnimation.value,
                                  child: Transform.rotate(
                                    angle: _logoRotationAnimation.value,
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryColor.withValues(alpha: 0.15),
                                            blurRadius: 20,
                                            spreadRadius: 2,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: SvgPicture.asset(
                                        'assets/images/icon-anandam.svg',
                                        width: 80,
                                        height: 80,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 36),

                            // Typography
                            FadeTransition(
                              opacity: _textFadeAnimation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.3),
                                  end: Offset.zero,
                                ).animate(_textSlideAnimation),
                                child: const Column(
                                  children: [
                                    Text(
                                      'Stok Anandam',
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1A1C24),
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'INVENTORY MANAGEMENT SYSTEM',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF5A607F),
                                        letterSpacing: 1.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 48),

                            // Light Capsule Progress Bar
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                children: [
                                  Container(
                                    height: 6,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Stack(
                                        children: [
                                          FractionallySizedBox(
                                            widthFactor: _progressAnimation.value.clamp(0.0, 1.0),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(20),
                                                gradient: LinearGradient(
                                                  colors: [
                                                    primaryColor,
                                                    primaryColor.withValues(alpha: 0.8),
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: primaryColor.withValues(alpha: 0.4),
                                                    blurRadius: 6,
                                                    spreadRadius: 1,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  FadeTransition(
                                    opacity: _textFadeAnimation,
                                    child: const Text(
                                      'Memuat aplikasi...',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  FadeTransition(
                                    opacity: _textFadeAnimation,
                                    child: const AppVersionLabel(
                                      textStyle: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}