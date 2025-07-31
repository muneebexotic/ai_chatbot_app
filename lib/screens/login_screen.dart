import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../components/ui/app_text.dart';
import '../components/ui/app_button.dart';
import '../components/ui/app_input.dart';
import '../components/ui/social_button.dart';
import '../components/ui/app_back_button.dart';
import '../utils/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
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

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isLoading = true);

    try {
      await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (authProvider.isLoggedIn && mounted) {
        Navigator.pushReplacementNamed(context, '/chat');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
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

  Future<void> _loginWithGoogle() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isLoading = true);

    try {
      await authProvider.signInWithGoogle();
      if (authProvider.isLoggedIn && mounted) {
        Navigator.pushReplacementNamed(context, '/chat');
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Set scaffold background to match your gradient
      backgroundColor: const Color(0xFF0A0A0A),
      // Remove default padding that might cause the space
      resizeToAvoidBottomInset: true,
      body: Container(
        // Make container fill the entire screen
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          // Set bottom to false to extend to the navigation bar
          bottom: false,
          child: Column(
            children: [
              Expanded(
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
                              child: AppBackButton(
                                onPressed: () => Navigator.pushReplacementNamed(
                                  context,
                                  '/welcome',
                                ),
                              ),
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
                                      'Login Your',
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
                                          0.3,
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
                                          0.4,
                                          1.0,
                                          curve: Curves.easeOut,
                                        ),
                                      ),
                                    ),
                                child: AppInput.password(
                                  controller: _passwordController,
                                  label: 'Password',
                                  hintText: 'Enter your password',
                                  obscureText: _obscurePassword,
                                  onToggleVisibility: () {
                                    setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    );
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Forgot Password
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: AppButton.text(
                                  text: 'Forgot password?',
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    '/forgot-password',
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Login Button
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
                                child: AppButton.primary(
                                  text: 'Login',
                                  onPressed: _login,
                                  isFullWidth: true,
                                  isLoading: _isLoading,
                                  size: AppButtonSize.large,
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Sign Up Link
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const AppText.bodyMedium(
                                      "Don't have an account? ",
                                      color: AppColors.textSecondary,
                                    ),
                                    AppButton.text(
                                      text: 'Sign Up',
                                      onPressed: () =>
                                          Navigator.pushNamed(context, '/signup'),
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
                                  onPressed: _loginWithGoogle,
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
              // Add some padding at the bottom to account for navigation bar
              Container(
                height: MediaQuery.of(context).padding.bottom,
                color: const Color(0xFF0A0A0A),
              ),
            ],
          ),
        ),
      ),
    );
  }
}