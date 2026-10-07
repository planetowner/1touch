import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/comm_pages/Profile_settings/InfoEdit.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/profile/account_deletion_service.dart';
import 'package:onetouch/l10n/app_localizations.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final locale in [const Locale('en'), const Locale('ko')]) {
      for (final isDark in [false, true]) {
        testWidgets('delete confirmation fits at $size, $locale, dark=$isDark',
            (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await _pumpScreen(tester, _DeletionService(), () async {},
              locale: locale, isDark: isDark);

          await _openConfirmation(tester, locale: locale);
          final card = tester.getRect(
              find.byKey(const ValueKey('profile-delete-confirmation-card')));
          expect(
              card.width, closeTo(size.width < 393 ? size.width - 48 : 345, 1));
          expect(card.center.dx, closeTo(size.width / 2, 1));
          expect(card.center.dy, closeTo(size.height / 2, 1));
          final title = tester.getRect(find.text(locale.languageCode == 'ko'
              ? '벌써 그라운드를 떠나시나요?'
              : 'Leaving the pitch already?'));
          final body = tester.getRect(find.text(locale.languageCode == 'ko'
              ? '계정을 삭제하면 데이터, 예측 기록, 포인트가 모두 영구적으로 사라져요.'
              : 'Deleting your account will permanently remove your data, predictions, and points.'));
          expect(title.left, greaterThanOrEqualTo(card.left + 24));
          expect(title.right, lessThanOrEqualTo(card.right - 24));
          expect(body.left, greaterThanOrEqualTo(card.left + 24));
          expect(body.right, lessThanOrEqualTo(card.right - 24));
          expect(body.bottom, lessThan(card.bottom - 24));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('cancel keeps account and session flow untouched',
      (tester) async {
    final service = _DeletionService();
    var completed = false;
    await _pumpScreen(tester, service, () async => completed = true);

    await _openConfirmation(tester);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();

    expect(service.calls, 0);
    expect(completed, isFalse);
    expect(
        find.byKey(const ValueKey('profile-delete-account')), findsOneWidget);
  });

  testWidgets('successful deletion finishes the session flow', (tester) async {
    final service = _DeletionService();
    var completed = false;
    await _pumpScreen(tester, service, () async => completed = true);

    await _openConfirmation(tester);
    await tester
        .tap(find.byKey(const ValueKey('profile-confirm-delete-account')));
    await tester.pumpAndSettle();

    expect(service.calls, 1);
    expect(completed, isTrue);
  });

  testWidgets('delete failure keeps account screen open and shows an error',
      (tester) async {
    final service = _DeletionService(fail: true);
    var completed = false;
    await _pumpScreen(tester, service, () async => completed = true);

    await _openConfirmation(tester);
    await tester
        .tap(find.byKey(const ValueKey('profile-confirm-delete-account')));
    await tester.pumpAndSettle();

    expect(service.calls, 1);
    expect(completed, isFalse);
    expect(
        find.byKey(const ValueKey('profile-delete-account')), findsOneWidget);
    expect(find.text('Unable to delete account. Please try again.'),
        findsOneWidget);
  });
}

Future<void> _pumpScreen(WidgetTester tester, AccountDeletionService service,
    Future<void> Function() onAccountDeleted,
    {Locale locale = const Locale('en'), bool isDark = false}) async {
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationDelegates,
    theme: lightThemeForLocale(locale),
    darkTheme: darkThemeForLocale(locale),
    themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
    home: EditProfileScreen(
      accountDeletionService: service,
      onAccountDeleted: onAccountDeleted,
    ),
  ));
}

Future<void> _openConfirmation(WidgetTester tester,
    {Locale locale = const Locale('en')}) async {
  final deleteButton = find.byKey(const ValueKey('profile-delete-account'));
  await tester.ensureVisible(deleteButton);
  await tester.tap(deleteButton);
  await tester.pumpAndSettle();
  expect(
      find.text(locale.languageCode == 'ko'
          ? '벌써 그라운드를 떠나시나요?'
          : 'Leaving the pitch already?'),
      findsOneWidget);
  expect(
      find.text(locale.languageCode == 'ko'
          ? '계정을 삭제하면 데이터, 예측 기록, 포인트가 모두 영구적으로 사라져요.'
          : 'Deleting your account will permanently remove your data, predictions, and points.'),
      findsOneWidget);
}

class _DeletionService implements AccountDeletionService {
  _DeletionService({this.fail = false});

  final bool fail;
  int calls = 0;

  @override
  Future<void> deleteAccount(Set<String> socialAccounts) async {
    calls++;
    if (fail) throw StateError('server unavailable');
  }
}
