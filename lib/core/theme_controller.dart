import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController extends ValueNotifier<ThemeMode> {
  AppThemeController() : super(ThemeMode.dark);

  static const _storageKey = 'app.theme_mode';

  Future<void> initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      value = preferences.getString(_storageKey) == ThemeMode.light.name
          ? ThemeMode.light
          : ThemeMode.dark;
    } on Object catch (error) {
      debugPrint('Unable to load theme preference: $error');
      value = ThemeMode.dark;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode != ThemeMode.light && mode != ThemeMode.dark) return;
    value = mode;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_storageKey, mode.name);
    } on Object catch (error) {
      debugPrint('Unable to save theme preference: $error');
    }
  }

  Future<void> toggle() {
    return setMode(value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

final appThemeController = AppThemeController();

class AppThemeSwitch extends StatelessWidget {
  const AppThemeSwitch({super.key, this.foregroundColor});

  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Switch(
      value: isDark,
      activeThumbColor: foregroundColor,
      inactiveThumbColor: foregroundColor,
      activeTrackColor: foregroundColor?.withValues(alpha: 0.35),
      inactiveTrackColor: foregroundColor?.withValues(alpha: 0.2),
      onChanged: (value) => appThemeController.setMode(
        value ? ThemeMode.dark : ThemeMode.light,
      ),
    );
  }
}

class AppThemeIconButton extends StatelessWidget {
  const AppThemeIconButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? 'Use light theme' : 'Use dark theme',
      onPressed: appThemeController.toggle,
      icon: Icon(
        isDark ? Icons.light_mode : Icons.dark_mode,
        color: color,
      ),
    );
  }
}
