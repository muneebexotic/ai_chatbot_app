import 'package:flutter/material.dart';
import '../components/welcome/welcome_header.dart';
import '../components/welcome/welcome_actions.dart';
import '../components/welcome/welcome_social_login.dart';
import '../controllers/welcome_controller.dart';
import '../mixins/welcome_animations_mixin.dart';
import '../constants/welcome_screen_constants.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin, WelcomeAnimationsMixin {
  late WelcomeController _controller;
  bool _isGoogleSignInLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = WelcomeController(context);
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: WelcomeScreenConstants.backgroundGradient,
            stops: WelcomeScreenConstants.gradientStops,
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
                      onLoginPressed: _controller.navigateToLogin,
                      onSignUpPressed: _controller.navigateToSignUp,
                    ),

                    WelcomeSocialLogin(
                      fadeAnimation: fadeAnimation,
                      buttonsSlideAnimation: buttonsSlideAnimation,
                      onGoogleSignIn: () => _controller.handleGoogleSignIn(
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