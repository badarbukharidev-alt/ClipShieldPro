import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.9, curve: Curves.easeInOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.8, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
    _initializeAppAndPermissions();
  }

  Future<void> _initializeAppAndPermissions() async {
    // Graceful permission request on first launch
    try {
      if (Platform.isAndroid) {
        // Android 13+ requires granular media permissions
        await [
          Permission.videos,
          Permission.audio,
          Permission.photos,
          Permission.storage,
        ].request();
      }
    } catch (_) {}

    // Wait for splash animation minimum duration
    await Future.delayed(const Duration(milliseconds: 2200));

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Background ambient radial glow
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.9,
                    colors: [
                      AppColors.accentTangerine
                          .withOpacity(0.15 * _glowAnimation.value),
                      AppColors.bg,
                    ],
                  ),
                ),
              );
            },
          ),

          // Central branding
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Shield Emblem with glowing border
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.card,
                          border: Border.all(
                            color: AppColors.accentTangerine,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentTangerine.withOpacity(
                                  0.35 * _glowAnimation.value),
                              blurRadius: 36 * _glowAnimation.value,
                              spreadRadius: 6 * _glowAnimation.value,
                            ),
                          ],
                        ),
                        child: Center(
                          child: ClipOval(
                            child: Image.asset(
                              'assets/icon/app_icon.png',
                              width: 68,
                              height: 68,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // App Name
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "CLIP",
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.5,
                              color: AppColors.ink,
                            ),
                          ),
                          const Text(
                            "SHIELD",
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.5,
                              color: AppColors.accentTangerine,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(left: 6, bottom: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentTangerine,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              "PRO",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      const Text(
                        "AI Video Repurposer & Protection Engine",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.mut,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Sleek pulsing progress indicator
                      const SizedBox(
                        width: 42,
                        height: 42,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.accentTangerine,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Bottom version tag
          const Positioned(
            bottom: 32,
            child: Text(
              "v1.0.0 Pro Edition • 100% On-Device DSP",
              style: TextStyle(
                fontSize: 11,
                color: AppColors.mut,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
