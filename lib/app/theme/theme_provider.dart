import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'theme_mode';

/// Theme mode state
enum AppThemeMode {
  system,
  light,
  dark,
}

/// Theme state
class ThemeState {
  final AppThemeMode mode;
  final bool isLoading;

  const ThemeState({
    this.mode = AppThemeMode.system,
    this.isLoading = true,
  });

  ThemeMode get themeMode {
    switch (mode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  bool get isDark => mode == AppThemeMode.dark;
  bool get isLight => mode == AppThemeMode.light;
  bool get isSystem => mode == AppThemeMode.system;

  ThemeState copyWith({
    AppThemeMode? mode,
    bool? isLoading,
  }) {
    return ThemeState(
      mode: mode ?? this.mode,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Theme notifier
class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(const ThemeState()) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeString = prefs.getString(_kThemeModeKey);

      AppThemeMode mode = AppThemeMode.system;
      if (modeString != null) {
        mode = AppThemeMode.values.firstWhere(
          (e) => e.name == modeString,
          orElse: () => AppThemeMode.system,
        );
      }

      state = state.copyWith(mode: mode, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(mode: mode);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemeModeKey, mode.name);
    } catch (e) {
      // Ignore storage errors
    }
  }

  Future<void> toggleDarkMode() async {
    if (state.mode == AppThemeMode.dark) {
      await setThemeMode(AppThemeMode.light);
    } else {
      await setThemeMode(AppThemeMode.dark);
    }
  }

  Future<void> setDarkMode(bool isDark) async {
    await setThemeMode(isDark ? AppThemeMode.dark : AppThemeMode.light);
  }
}

/// Theme provider
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>(
  (ref) => ThemeNotifier(),
);
