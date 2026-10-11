import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';

// 팀·선수·커뮤니티의 분류 탭은 글자와 색만 바꾸고 간격은 함께 유지해요.
const appSectionTabBarHeight = 36.0;

PreferredSize appSectionTabBar(
  BuildContext context, {
  required TabController controller,
  required List<String> labels,
  ValueChanged<int>? onTap,
  Color? foreground,
  Color? unselectedForeground,
}) {
  final color = foreground ?? Theme.of(context).colorScheme.onSurface;
  final labelStyle = Localizations.localeOf(context).languageCode == 'en'
      ? Heading5.style.copyWith(height: 1.1, letterSpacing: 0)
      : Heading5.style;
  // TabBar의 기본 preferredSize는 최소 48이라 시안 높이를 직접 전달해요.
  return PreferredSize(
    preferredSize: const Size.fromHeight(appSectionTabBarHeight),
    child: SizedBox(
      height: appSectionTabBarHeight,
      child: TabBar(
        controller: controller,
        onTap: onTap,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: color,
        unselectedLabelColor:
            unselectedForeground ?? AppColors.of(context).mutedForeground,
        indicatorColor: color,
        labelStyle: labelStyle,
        unselectedLabelStyle: labelStyle,
        indicatorWeight: 1,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        // 탭 안쪽 8과 바깥쪽 6을 합쳐 글자 사이 28을 유지해요.
        // 첫 글자는 화면 여백 24 + 탭 안쪽 여백 8에서 시작해요.
        padding: const EdgeInsets.only(left: 18),
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: color, width: 1),
        ),
        tabs: [
          for (final label in labels)
            Tab(
              height: appSectionTabBarHeight - 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(label),
              ),
            ),
        ],
      ),
    ),
  );
}
