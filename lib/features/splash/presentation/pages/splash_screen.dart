import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nspl_odoo/core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/storage/storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotateAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;

  @override
  void initState() {
    super.initState();

    // Logo animations
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoScaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _logoRotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // Text animations
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    // Start animations
    _logoController.forward();

    // Start text animation after logo
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _textController.forward();
      }
    });

    // Navigate to login after 3 seconds
    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        // Check if user is already logged in
        final isLoggedIn = await StorageService.instance.isLoggedIn();
        
        if (isLoggedIn) {
          // User has valid session, go to API users screen
          context.go(AppRouter.apiUsers);
        } else {
          // No session, go to login
          context.go(AppRouter.login);
        }
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo
              Image.asset(
                'assets/logo.png',
                width: 250,
                height: 250,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to icon if image not found
                  return const Icon(
                    Icons.chat_bubble_rounded,
                    size: 80,
                    color: AppColors.purple1,
                  );
                },
              ),
              // AnimatedBuilder(
              //   animation: _logoController,
              //   builder: (context, child) {
              //     return Transform.scale(
              //       scale: _logoScaleAnimation.value,
              //       child: Transform.rotate(
              //         angle: _logoRotateAnimation.value * 0.5,
              //         child: FadeTransition(
              //           opacity: _logoFadeAnimation,
              //           child: Container(
              //             padding: const EdgeInsets.all(30),
              //             decoration: BoxDecoration(
              //               color: AppColors.white,
              //               shape: BoxShape.circle,
              //               boxShadow: [
              //                 BoxShadow(
              //                   color: AppColors.purple1.withValues(alpha: 0.5),
              //                   blurRadius: 40,
              //                   spreadRadius: 15,
              //                 ),
              //                 BoxShadow(
              //                   color: AppColors.purple1.withValues(alpha: 0.4),
              //                   blurRadius: 60,
              //                   spreadRadius: 20,
              //                 ),
              //               ],
              //             ),
              //             child: _buildLogo(),
              //           ),
              //         ),
              //       ),
              //     );
              //   },
              // ),
              const SizedBox(height: 40),

              // Animated Text
              FadeTransition(
                opacity: _textFadeAnimation,
                child: SlideTransition(
                  position: _textSlideAnimation,
                  child: Column(
                    children: [
                      // Norbit Text
                      // Container(
                      //   padding: const EdgeInsets.symmetric(
                      //     horizontal: 32,
                      //     vertical: 12,
                      //   ),
                      //   decoration: BoxDecoration(
                      //     gradient: AppColors.buttonGradient,
                      //     borderRadius: BorderRadius.circular(25),
                      //     boxShadow: [
                      //       BoxShadow(
                      //         color: AppColors.purple1.withValues(alpha: 0.4),
                      //         blurRadius: 20,
                      //         spreadRadius: 5,
                      //       ),
                      //     ],
                      //   ),
                      //   child: const Text(
                      //     'Norbit',
                      //     style: TextStyle(
                      //       fontSize: 52,
                      //       fontWeight: FontWeight.bold,
                      //       color: AppColors.white,
                      //       letterSpacing: 4,
                      //     ),
                      //   ),
                      // ),
                      // const SizedBox(height: 20),

                      // Tagline
                      // Container(
                      //   padding: const EdgeInsets.symmetric(
                      //     horizontal: 20,
                      //     vertical: 8,
                      //   ),
                      //   decoration: BoxDecoration(
                      //     border: Border.all(
                      //       color: AppColors.purple1.withValues(alpha: 0.6),
                      //       width: 2,
                      //     ),
                      //     borderRadius: BorderRadius.circular(20),
                      //   ),
                      //   child: const Text(
                      //     'Connect • Collaborate • Communicate',
                      //     style: TextStyle(
                      //       fontSize: 14,
                      //       color: AppColors.white,
                      //       fontWeight: FontWeight.w500,
                      //       letterSpacing: 1.5,
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 60),

              // Loading Indicator
              FadeTransition(
                opacity: _textFadeAnimation,
                child: Column(
                  children: [
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.white,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    // Try to load image, fallback to icon
    return Image.asset(
      'assets/logo.png',
      width: 80,
      height: 80,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to icon if image not found
        return const Icon(
          Icons.chat_bubble_rounded,
          size: 80,
          color: AppColors.purple1,
        );
      },
    );
  }
}
