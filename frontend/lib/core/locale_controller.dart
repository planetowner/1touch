import 'package:flutter/widgets.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleController extends ValueNotifier<Locale> {
  AppLocaleController() : super(const Locale('en'));

  static const _storageKey = 'app.locale';

  Future<void> initialize({List<Locale>? deviceLocales}) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedLanguage = preferences.getString(_storageKey);
      value =
          (savedLanguage == null ? null : appLocaleOverride(savedLanguage)) ??
              appLocaleOverride() ??
              resolveAppLocale(
                deviceLocales ??
                    WidgetsBinding.instance.platformDispatcher.locales,
                appSupportedLocales,
              );
    } on Object catch (error) {
      debugPrint('Unable to load locale preference: $error');
      value = resolveAppLocale(
        deviceLocales ?? WidgetsBinding.instance.platformDispatcher.locales,
        appSupportedLocales,
      );
    }
  }

  Future<void> setLocale(Locale locale) async {
    final supportedLocale = appSupportedLocales.firstWhere(
      (candidate) => candidate.languageCode == locale.languageCode,
      orElse: () => value,
    );
    if (supportedLocale.languageCode != locale.languageCode) return;
    value = supportedLocale;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_storageKey, supportedLocale.languageCode);
    } on Object catch (error) {
      debugPrint('Unable to save locale preference: $error');
    }
  }
}

final appLocaleController = AppLocaleController();
