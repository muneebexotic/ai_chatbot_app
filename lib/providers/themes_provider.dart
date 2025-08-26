import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDark = true;
  static const String _themeKey = 'theme_mode';

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider() {
    _loadTheme();
  }

  void toggleTheme() {
    _isDark = !_isDark;
    _saveTheme();
    notifyListeners();
  }

  void setTheme(bool isDark) {
    if (_isDark != isDark) {
      _isDark = isDark;
      _saveTheme();
      notifyListeners();
    }
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDark = prefs.getBool(_themeKey) ?? true; // Default to dark
      notifyListeners();
    } catch (e) {
      // If SharedPreferences fails, keep default value
      debugPrint('Failed to load theme preference: $e');
    }
  }

  Future<void> _saveTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDark);
    } catch (e) {
      debugPrint('Failed to save theme preference: $e');
    }
  }
}