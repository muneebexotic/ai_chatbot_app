// State management for splash screen

import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../services/splash_service.dart';

/// Controller that manages splash screen state and navigation
class SplashController extends ChangeNotifier {
  SplashController({
    required AuthProvider authProvider,
    required VoidCallback onNavigationComplete,
  }) : _authProvider = authProvider,
       _onNavigationComplete = onNavigationComplete;

  final AuthProvider _authProvider;
  final VoidCallback _onNavigationComplete;

  bool _isInitializing = true;
  bool _hasNavigated = false;
  String? _error;
  Timer? _initializationTimer;

  // Getters
  bool get isInitializing => _isInitializing;
  bool get hasNavigated => _hasNavigated;
  bool get hasError => _error != null;
  String? get error => _error;

  /// Initialize the splash screen and handle navigation
  Future<void> initialize(BuildContext context) async {
    if (_hasNavigated) return;

    try {
      _setInitializing(true);
      _clearError();

      // Start initialization with timeout safety
      _startInitializationTimer(context);

      // Initialize app and get navigation route
      final route = await SplashService.initializeApp(_authProvider);
      
      // Navigate to determined route
      await _navigateToRoute(context, route);
    } catch (e) {
      _handleError(e.toString());
    }
  }

  /// Start a safety timer to prevent infinite initialization
  void _startInitializationTimer(BuildContext context) {
    _initializationTimer?.cancel();
    _initializationTimer = Timer(const Duration(seconds: 15), () {
      if (!_hasNavigated && context.mounted) {
        _handleError('Initialization timeout - navigating to welcome');
        _navigateToRoute(context, '/welcome');
      }
    });
  }

  /// Navigate to the specified route
  Future<void> _navigateToRoute(BuildContext context, String route) async {
    if (_hasNavigated || !context.mounted) return;

    _hasNavigated = true;
    _initializationTimer?.cancel();
    
    // Small delay to ensure animations complete
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, route);
      _onNavigationComplete();
    }
    
    _setInitializing(false);
  }

  void _setInitializing(bool value) {
    if (_isInitializing != value) {
      _isInitializing = value;
      notifyListeners();
    }
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void _handleError(String error) {
    _error = error;
    _setInitializing(false);
    notifyListeners();
  }

  @override
  void dispose() {
    _initializationTimer?.cancel();
    super.dispose();
  }
}