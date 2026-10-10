import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';

// 팀·선수·커뮤니티의 분류 탭은 글자와 색만 바꾸고 간격은 함께 유지해요.
TabBar appSectionTabBar(
  BuildContext context, {
  required TabController controller,
  required List<String> labels,
  ValueChanged<int>? onTap,
  Color? foreground,
  Color? unselectedForeground,
}) {
  final color = foreground ?? Theme.of(context).colorScheme.onSurface;
  return TabBar(
    controller: controller,
    onTap: onTap,
    isScrollable: true,
    tabAlignment: TabAlignment.start,
    labelColor: color,
    unselectedLabelColor:
        unselectedForeground ?? AppColors.of(context).mutedForeground,
    indicatorColor: color,
    labelStyle: Heading5.style,
    unselectedLabelStyle: Heading5.style,
    indicatorSize: TabBarIndicatorSize.label,
    dividerColor: Colors.transparent,
    // 원본의 좌우 패딩 8 + 탭 사이 12를 글자 사이 28로 환산해요.
    // 첫 글자는 화면 여백 24 + 탭 안쪽 여백 8에서 시작해요.
    padding: const EdgeInsets.only(left: 18),
    labelPadding: const EdgeInsets.symmetric(horizontal: 14),
    indicator: UnderlineTabIndicator(
      borderSide: BorderSide(color: color, width: 2),
    ),
    tabs: [for (final label in labels) Tab(text: label)],
  );
}
