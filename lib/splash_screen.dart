import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/ad_helper.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final AppOpenAdManager _appOpenAdManager = AppOpenAdManager();

  @override
  void initState() {
    super.initState();
    _appOpenAdManager.loadAd();

    // Transparent status bar for edge-to-edge luxury feel
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.8, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
    _checkNextScreen();
  }

  Future<void> _checkNextScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final bool seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

    // Minimum splash animation delay so user sees branding
    await Future.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;

    final nextScreen = seenOnboarding ? const HomeScreen() : const OnboardingScreen();

    // If ad is already loaded, show it immediately
    if (_appOpenAdManager.isAdAvailable) {
      debugPrint('[SplashScreen] Ad is already available! Showing now...');
      _appOpenAdManager.showAdIfAvailable(
        onComplete: () {
          if (!mounted) return;
          _navigate(nextScreen);
        },
      );
      return;
    }

    // If ad is not ready yet, wait up to 4.5 seconds for AdMob server to return the test ad
    bool hasNavigated = false;
    final timer = Timer(const Duration(milliseconds: 4500), () {
      if (!hasNavigated && mounted) {
        debugPrint('[SplashScreen] Timeout reached (4.5s), navigating without ad.');
        hasNavigated = true;
        _navigate(nextScreen);
      }
    });

    _appOpenAdManager.loadAd(
      onLoaded: (success) {
        debugPrint('[SplashScreen] Ad callback received! success: $success, mounted: $mounted, hasNavigated: $hasNavigated');
        if (!hasNavigated && mounted) {
          hasNavigated = true;
          timer.cancel();
          if (success) {
            debugPrint('[SplashScreen] Showing App Open Ad on device!');
            _appOpenAdManager.showAdIfAvailable(
              onComplete: () {
                if (!mounted) return;
                _navigate(nextScreen);
              },
            );
          } else {
            _navigate(nextScreen);
          }
        }
      },
    );
  }

  void _navigate(Widget nextScreen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, anim, secondaryAnim) => nextScreen,
        transitionsBuilder: (context, anim, secondaryAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE5252A), // Vibrant Crimson Red
              Color(0xFFB5101A), // Rich Deep Red
              Color(0xFF7A040B), // Luxury Wine Red
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Ambient background glow circles
            Positioned(
              top: -size.width * 0.25,
              right: -size.width * 0.2,
              child: Container(
                width: size.width * 0.8,
                height: size.width * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -size.width * 0.3,
              left: -size.width * 0.25,
              child: Container(
                width: size.width * 0.9,
                height: size.width * 0.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.15),
                ),
              ),
            ),

            // Main Content: Logo + Title + Tagline
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App Logo with scale and soft elevation glow
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 28,
                                  offset: const Offset(0, 14),
                                ),
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  blurRadius: 18,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: Image.asset(
                                'assets/images/app_logo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // App Name
                        SlideTransition(
                          position: _slideAnimation,
                          child: Column(
                            children: [
                              const Text(
                                'PDF Reader',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: Colors.white,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    height: 1,
                                    width: 16,
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      'PDF VIEWER & TOOLS',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 2.5,
                                        color: Color(0xFFFFD5D7),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    height: 1,
                                    width: 16,
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom loading indicator & signature
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Fast • Secure • Offline',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
