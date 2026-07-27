import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../components/welcome/welcome_header.dart';
import '../components/welcome/welcome_actions.dart';
import '../components/welcome/welcome_social_login.dart';
import '../controllers/welcome_controller.dart';
import '../mixins/welcome_animations_mixin.dart';
import '../constants/welcome_screen_constants.dart';
import '../app/providers.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin, WelcomeAnimationsMixin {
  late WelcomeController _controller;
  bool _isGoogleSignInLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = WelcomeController(ref.read(authNotifierProvider));
    initializeWelcomeAnimations();
    startWelcomeAnimations();
  }

  @override
  void dispose() {
    disposeWelcomeAnimations();
    super.dispose();
  }

  void _onLoadingChanged() {
    if (mounted) {
      setState(() {
        _isGoogleSignInLoading = _controller.isLoading;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surface,
              colorScheme.surface,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: WelcomeScreenConstants.horizontalPadding,
              vertical: WelcomeScreenConstants.verticalPadding,
            ),
            child: AnimatedBuilder(
              animation: animationController,
              builder: (context, child) {
                return Column(
                  children: [
                    const Spacer(flex: WelcomeScreenConstants.topSpacerFlex),

                    WelcomeHeader(
                      fadeAnimation: fadeAnimation,
                      slideAnimation: slideAnimation,
                      titleSlideAnimation: titleSlideAnimation,
                      subtitleFadeAnimation: subtitleFadeAnimation,
                    ),

                    const Spacer(flex: WelcomeScreenConstants.bottomSpacerFlex),

                    WelcomeActions(
                      fadeAnimation: fadeAnimation,
                      buttonsSlideAnimation: buttonsSlideAnimation,
                      onLoginPressed: () => _controller.navigateToLogin(context),
                      onSignUpPressed: () => _controller.navigateToSignUp(context),
                    ),

                    WelcomeSocialLogin(
                      fadeAnimation: fadeAnimation,
                      buttonsSlideAnimation: buttonsSlideAnimation,
                      onGoogleSignIn: () => _controller.handleGoogleSignIn(
                        context,
                        onLoadingChanged: _onLoadingChanged,
                      ),
                      isLoading: _isGoogleSignInLoading,  
                    ),

                    const Spacer(flex: WelcomeScreenConstants.finalSpacerFlex),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}