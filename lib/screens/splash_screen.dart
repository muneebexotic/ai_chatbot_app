import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../components/ui/app_logo.dart';
import '../components/ui/app_text.dart';
import '../utils/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  bool _hasNavigated = false; // Prevent double navigation

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startSplashSequence();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeInOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
      ),
    );
  }

  void _startSplashSequence() {
    _animationController.forward();
    
    // CRITICAL FIX: Wait for auth initialization AND minimum splash time
    _waitForAuthAndNavigate();
  }

  Future<void> _waitForAuthAndNavigate() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Start minimum splash timer
    final splashTimer = Timer(const Duration(milliseconds: 2500), () {
      // This ensures minimum splash time regardless of auth speed
    });

    try {
      // CRITICAL: Wait for both conditions:
      // 1. Minimum splash time (for UX)
      // 2. Auth provider to be fully initialized

      await Future.wait([
        // Wait for minimum splash time
        Future.delayed(const Duration(milliseconds: 2500)),
        
        // Wait for auth initialization if user exists
        _waitForAuthInitialization(authProvider),
      ]);

      // Navigate after both conditions are met
      if (mounted && !_hasNavigated) {
        _navigate();
      }
    } catch (e) {
      print('❌ Error during splash initialization: $e');
      
      // Fallback: navigate anyway after timeout
      if (mounted && !_hasNavigated) {
        await Future.delayed(const Duration(milliseconds: 1000));
        _navigate();
      }
    }
  }

  Future<void> _waitForAuthInitialization(AuthProvider authProvider) async {
    // If no Firebase user, no need to wait
    if (authProvider.user == null) {
      print('✅ No user, skipping auth initialization wait');
      return;
    }

    print('🔄 Waiting for auth initialization...');
    
    // Wait for current user data to be loaded
    const maxWaitTime = Duration(seconds: 10); // Safety timeout
    const checkInterval = Duration(milliseconds: 100);
    
    final stopwatch = Stopwatch()..start();
    
    while (stopwatch.elapsed < maxWaitTime) {
      // Check if auth provider has finished loading user data
      if (authProvider.currentUser != null) {
        print('✅ Auth initialization completed in ${stopwatch.elapsedMilliseconds}ms');
        return;
      }
      
      // Wait before next check
      await Future.delayed(checkInterval);
    }
    
    // Timeout reached
    print('⚠️ Auth initialization timeout after ${stopwatch.elapsedMilliseconds}ms');
  }

  void _navigate() {
    if (_hasNavigated) return;
    _hasNavigated = true;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // CRITICAL FIX: Check both Firebase user AND currentUser data
    final hasFirebaseUser = authProvider.user != null;
    final hasUserData = authProvider.currentUser != null;
    final isFullyLoggedIn = hasFirebaseUser && hasUserData;

    print('🧭 Navigation decision:');
    print('   Firebase user: $hasFirebaseUser');
    print('   User data: $hasUserData');
    print('   Fully logged in: $isFullyLoggedIn');
    print('   Premium status: ${authProvider.currentUser?.hasActiveSubscription}');

    if (isFullyLoggedIn) {
      print('✅ Navigating to chat screen');
      Navigator.pushReplacementNamed(context, '/chat');
    } else {
      print('✅ Navigating to welcome screen');
      Navigator.pushReplacementNamed(context, '/welcome');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Animated Logo
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: const AppLogo(
                          size: AppLogoSize.large,
                          showGlow: true,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Animated App Name
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, 0.5),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _animationController,
                                curve: const Interval(
                                  0.4,
                                  1.0,
                                  curve: Curves.easeOut,
                                ),
                              ),
                            ),
                        child: const AppText.displayLarge(
                          'ChadGPT',
                          color: Colors.white,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Subtitle with delayed animation
                    FadeTransition(
                      opacity: Tween<double>(begin: 0.0, end: 0.7).animate(
                        CurvedAnimation(
                          parent: _animationController,
                          curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
                        ),
                      ),
                      child: const AppText.bodyMedium(
                        'AI-Powered Conversations',
                        color: AppColors.textSecondary,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    // Add loading indicator for better UX
                    const SizedBox(height: 48),
                    
                    FadeTransition(
                      opacity: Tween<double>(begin: 0.0, end: 0.5).animate(
                        CurvedAnimation(
                          parent: _animationController,
                          curve: const Interval(0.8, 1.0, curve: Curves.easeIn),
                        ),
                      ),
                      child: const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}