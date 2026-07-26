import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';
  ThemeMode _themeMode = ThemeMode.light;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  ThemeMode get themeMode => _themeMode;

  String get themeModeString {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeKey);
      if (savedTheme != null) {
        if (savedTheme == 'Light') {
          _themeMode = ThemeMode.light;
        } else if (savedTheme == 'Dark') {
          _themeMode = ThemeMode.dark;
        } else if (savedTheme == 'System') {
          _themeMode = ThemeMode.system;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading theme preference: $e');
    }
  }

  Future<void> setThemeMode(String mode) async {
    if (mode == 'Light') {
      _themeMode = ThemeMode.light;
    } else if (mode == 'Dark') {
      _themeMode = ThemeMode.dark;
    } else if (mode == 'System') {
      _themeMode = ThemeMode.system;
    } else {
      return;
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }
}
