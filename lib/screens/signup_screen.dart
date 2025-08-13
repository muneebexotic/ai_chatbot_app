import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../components/ui/app_text.dart';
import '../components/ui/app_button.dart';
import '../components/ui/app_input.dart';
import '../components/ui/social_button.dart';
import '../components/ui/app_back_button.dart';
import '../utils/app_theme.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _animationController.forward();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
          ),
        );
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isLoading = true);

    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final isNewUser = await authProvider.signUp(email, password, fullName);

      // Wait for both auth state AND user data to be ready
      await _waitForUserDataReady(authProvider);

      if (authProvider.isLoggedIn &&
          authProvider.currentUser != null &&
          mounted) {
        if (isNewUser) {
          Navigator.pushReplacementNamed(context, '/photo-upload');
        } else {
          Navigator.pushReplacementNamed(context, '/chat');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign Up failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _signUpWithGoogle() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isLoading = true);

    try {
      await authProvider.signInWithGoogle();

      // Wait for both auth state AND user data to be ready
      await _waitForUserDataReady(authProvider);

      if (authProvider.isLoggedIn &&
          authProvider.currentUser != null &&
          mounted) {
        Navigator.pushReplacementNamed(context, '/chat');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Google Sign-In succeeded, but user data is not ready.',
            ),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // Enhanced helper method - waits for BOTH auth state AND user data
  Future<void> _waitForUserDataReady(AuthProvider authProvider) async {
    const maxWaitTime = Duration(seconds: 5); // Increased timeout for user data
    const checkInterval = Duration(milliseconds: 150);

    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < maxWaitTime) {
      if (authProvider.isLoggedIn && authProvider.currentUser != null) {
        // Extra small delay to ensure everything is settled
        await Future.delayed(const Duration(milliseconds: 50));
        return;
      }
      await Future.delayed(checkInterval);
    }

    print(
      '⚠️ Timeout waiting for user data. Auth: ${authProvider.isLoggedIn}, User: ${authProvider.currentUser != null}',
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back Button
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: const AppBackButton(),
                      ),

                      const SizedBox(height: 40),

                      // Title
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText.displayLarge(
                                'Create Your',
                                color: Colors.white,
                              ),
                              AppText.displayLarge(
                                'Account',
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Full Name Input
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position:
                              Tween<Offset>(
                                begin: const Offset(0, 0.1),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: _animationController,
                                  curve: const Interval(
                                    0.3,
                                    1.0,
                                    curve: Curves.easeOut,
                                  ),
                                ),
                              ),
                          child: AppInput.text(
                            controller: _fullNameController,
                            label: 'Full Name',
                            hintText: 'Enter your full name',
                            prefixIcon: Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your full name';
                              }
                              if (value.length < 2) {
                                return 'Name must be at least 2 characters';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Email Input
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position:
                              Tween<Offset>(
                                begin: const Offset(0, 0.1),
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
                          child: AppInput.email(
                            controller: _emailController,
                            label: 'Email Address',
                            hintText: 'Enter your email',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Password Input
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position:
                              Tween<Offset>(
                                begin: const Offset(0, 0.1),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: _animationController,
                                  curve: const Interval(
                                    0.5,
                                    1.0,
                                    curve: Curves.easeOut,
                                  ),
                                ),
                              ),
                          child: AppInput.password(
                            controller: _passwordController,
                            label: 'Password',
                            hintText: 'Create a strong password',
                            obscureText: _obscurePassword,
                            onToggleVisibility: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              if (!RegExp(
                                r'^(?=.*[a-zA-Z])(?=.*\d)',
                              ).hasMatch(value)) {
                                return 'Password must contain letters and numbers';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Sign Up Button
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position:
                              Tween<Offset>(
                                begin: const Offset(0, 0.1),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: _animationController,
                                  curve: const Interval(
                                    0.6,
                                    1.0,
                                    curve: Curves.easeOut,
                                  ),
                                ),
                              ),
                          child: AppButton.primary(
                            text: 'Create Account',
                            onPressed: _signUp,
                            isFullWidth: true,
                            isLoading: _isLoading,
                            size: AppButtonSize.large,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Login Link
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const AppText.bodyMedium(
                                "Already have an account? ",
                                color: AppColors.textSecondary,
                              ),
                              AppButton.text(
                                text: 'Login',
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Divider
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color: AppColors.textTertiary.withOpacity(0.3),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: AppText.bodyMedium(
                                'or continue with',
                                color: AppColors.textTertiary,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: AppColors.textTertiary.withOpacity(0.3),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Google Sign-In
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Center(
                          child: SocialButton.google(
                            onPressed: _signUpWithGoogle,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
