import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

SystemUiOverlayStyle appSystemUiStyle(Brightness iconBrightness) =>
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: iconBrightness == Brightness.light
          ? Brightness.dark
          : Brightness.light,
      systemStatusBarContrastEnforced: false,
    );

/// 배경과 안전 영역은 화면이 맡고, 시스템 아이콘만 공통으로 설정해요.
class AppSystemUi extends StatelessWidget {
  const AppSystemUi({
    super.key,
    required this.child,
    this.iconBrightness,
  });

  final Widget child;
  final Brightness? iconBrightness;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overlay = appSystemUiStyle(iconBrightness ??
        (theme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      // 사진처럼 테마와 다른 배경에서는 앱 바도 같은 아이콘 밝기를 써요.
      child: iconBrightness == null
          ? child
          : Theme(
              data: theme.copyWith(
                appBarTheme:
                    theme.appBarTheme.copyWith(systemOverlayStyle: overlay),
              ),
              child: child,
            ),
    );
  }
}
