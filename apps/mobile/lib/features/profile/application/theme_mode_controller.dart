import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class ThemeModeController extends ChangeNotifier {
  ThemeModeController({SharedPreferencesAsync? preferences})
    : _preferencesOverride = preferences;

  static const _preferenceKey = 'clarity.themeMode';

  final SharedPreferencesAsync? _preferencesOverride;
  ThemeMode _themeMode = ThemeMode.system;

  SharedPreferencesAsync get _preferences =>
      _preferencesOverride ?? SharedPreferencesAsync();

  ThemeMode get themeMode => _themeMode;

  String get label => switch (_themeMode) {
    ThemeMode.system => 'System',
    ThemeMode.dark => 'Dark',
    ThemeMode.light => 'Light',
  };

  Future<void> load() async {
    final value = await _preferences.getString(_preferenceKey);
    _themeMode = _modeFromValue(value);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _preferences.setString(_preferenceKey, mode.name);
  }

  ThemeMode _modeFromValue(String? value) {
    return switch (value) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }
}
