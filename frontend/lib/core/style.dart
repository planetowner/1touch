import 'package:flutter/material.dart';

abstract final class AppPalette {
  static const black = Color(0xFF090A0A);
  static const white = Color(0xFFFFFFFF);
  static const darkGrey = Color(0xFF282929);
  static const lightGrey = Color(0xFF3D3D3D);
  static const lightGreyBox = Color(0xFFF5F5F5);
  static const lightModeDarkGrey = Color(0xFFEBEBEB);
}

Color mainPageBackground(BuildContext context) {
  return Theme.of(context).brightness == Brightness.light
      ? AppPalette.lightModeDarkGrey
      : AppColors.of(context).pageBackground;
}

double responsiveBrandGradientHeight(BuildContext context) {
  return (MediaQuery.sizeOf(context).height * 0.70)
      .clamp(550.0, 650.0)
      .toDouble();
}

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.pageBackground,
    required this.cardBackground,
    required this.subtleBackground,
    required this.mutedForeground,
    required this.divider,
    required this.onBrand,
  });

  final Color pageBackground;
  final Color cardBackground;
  final Color subtleBackground;
  final Color mutedForeground;
  final Color divider;
  final Color onBrand;

  static AppColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppColors>() ??
        (theme.brightness == Brightness.dark ? _darkColors : _lightColors);
  }

  @override
  AppColors copyWith({
    Color? pageBackground,
    Color? cardBackground,
    Color? subtleBackground,
    Color? mutedForeground,
    Color? divider,
    Color? onBrand,
  }) {
    return AppColors(
      pageBackground: pageBackground ?? this.pageBackground,
      cardBackground: cardBackground ?? this.cardBackground,
      subtleBackground: subtleBackground ?? this.subtleBackground,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      divider: divider ?? this.divider,
      onBrand: onBrand ?? this.onBrand,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      subtleBackground:
          Color.lerp(subtleBackground, other.subtleBackground, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
    );
  }
}

const _darkColors = AppColors(
  pageBackground: AppPalette.black,
  cardBackground: AppPalette.darkGrey,
  subtleBackground: AppPalette.lightGrey,
  mutedForeground: Color(0x99FFFFFF),
  divider: Color(0x1FFFFFFF),
  onBrand: AppPalette.white,
);

const _lightColors = AppColors(
  pageBackground: AppPalette.white,
  cardBackground: AppPalette.white,
  subtleBackground: AppPalette.lightGreyBox,
  mutedForeground: Color(0x99090A0A),
  divider: Color(0x1F090A0A),
  onBrand: AppPalette.black,
);

ThemeData _buildTheme(Brightness brightness, AppColors colors) {
  final isDark = brightness == Brightness.dark;
  final foreground = isDark ? AppPalette.white : AppPalette.black;
  final inverseForeground = isDark ? AppPalette.black : AppPalette.white;
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: foreground,
    onPrimary: inverseForeground,
    secondary: foreground,
    onSecondary: inverseForeground,
    error: const Color(0xFFBA1A1A),
    onError: AppPalette.white,
    surface: colors.cardBackground,
    onSurface: foreground,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    fontFamily: 'Archivo',
  );

  return base.copyWith(
    scaffoldBackgroundColor: colors.pageBackground,
    canvasColor: colors.pageBackground,
    cardColor: colors.cardBackground,
    dividerColor: colors.divider,
    iconTheme: IconThemeData(color: foreground),
    textTheme: base.textTheme.apply(
      bodyColor: foreground,
      displayColor: foreground,
      fontFamily: 'Archivo',
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.pageBackground,
      foregroundColor: foreground,
      elevation: 0,
      iconTheme: IconThemeData(color: foreground),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colors.cardBackground,
      elevation: 2,
      selectedItemColor: foreground,
      unselectedItemColor: colors.mutedForeground,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.subtleBackground,
      hintStyle: TextStyle(color: colors.mutedForeground),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? foreground
            : colors.mutedForeground;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? foreground.withValues(alpha: 0.3)
            : colors.divider;
      }),
    ),
    extensions: [colors],
  );
}

final ThemeData darktheme = _buildTheme(Brightness.dark, _darkColors);
final ThemeData whitetheme = _buildTheme(Brightness.light, _lightColors);
