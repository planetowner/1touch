import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/app_error_config.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/features/app_error_view.dart';
import 'package:onetouch/l10n/app_localizations.dart';

void main() {
  test('uses the configured Korean error copy without changing it', () {
    const locale = Locale('ko');
    expect(appErrorConfigs, hasLength(8));
    expect(
      appErrorConfigs.map(
        (code, config) => MapEntry(code, {
          'title': translateMessage(locale, config.title),
          'message': translateMessage(locale, config.message),
          'action': config.action == null
              ? null
              : translateMessage(locale, config.action!),
        }),
      ),
      {
        404: {
          'title': '오프사이드!',
          'message': '찾고 있는 페이지를 찾을 수 없어요.',
          'action': '홈으로',
        },
        401: {
          'title': '다시 입장해주세요',
          'message': '로그인 세션이 만료됐어요.',
          'action': '다시 로그인',
        },
        403: {
          'title': '레드카드!',
          'message': '이 페이지에 접근할 권한이 없어요.',
          'action': '돌아가기',
        },
        429: {
          'title': '잠시 벤치에서 쉬어가요',
          'message': '요청이 너무 많아요. 잠시 후 다시 시도해주세요.',
          'action': null,
        },
        500: {
          'title': 'VAR 확인 중',
          'message': '서버에 문제가 생겼어요. 잠시 후 다시 시도해주세요.',
          'action': '다시 시도',
        },
        502: {
          'title': '패스 연결에 실패했어요',
          'message': '서버 간 연결에 문제가 생겼어요. 잠시 후 다시 시도해주세요.',
          'action': null,
        },
        503: {
          'title': '잠시 경기 중단',
          'message': '현재 서비스를 이용할 수 없어요. 잠시 후 다시 시도해주세요.',
          'action': null,
        },
        504: {
          'title': '추가시간을 넘겼어요',
          'message': '서버 응답이 지연되고 있어요. 다시 시도해주세요.',
          'action': null,
        },
      },
    );
  });

  testWidgets('shows and runs a configured action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        theme: app_style.whitetheme,
        home: Scaffold(
          body: AppErrorView(
            statusCode: 404,
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('오프사이드!'), findsOneWidget);
    expect(find.text('찾고 있는 페이지를 찾을 수 없어요.'), findsOneWidget);
    await tester.tap(find.text('홈으로'));
    expect(tapped, isTrue);
  });

  testWidgets('does not create an action for a null configuration',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        theme: app_style.darktheme,
        home: Scaffold(
          body: AppErrorView(statusCode: 429, onAction: () {}),
        ),
      ),
    );

    expect(find.text('잠시 벤치에서 쉬어가요'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
}
