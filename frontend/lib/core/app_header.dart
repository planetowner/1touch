import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/style.dart';

// 홈·선수·커뮤니티는 같은 브랜드 상단을 쓰고, 오른쪽 동작만 바꿔요.
class AppBrandSliverHeader extends StatelessWidget {
  const AppBrandSliverHeader({
    super.key,
    required this.pageBackground,
    required this.actions,
    this.opacityFactor = 1,
    this.logoKey,
  });

  final Color pageBackground;
  final double opacityFactor;
  final Widget actions;
  final Key? logoKey;

  @override
  Widget build(BuildContext context) => SliverAppBar(
        backgroundColor:
            scrollingAppBarBackground(context, pageBackground, opacityFactor),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        floating: true,
        snap: true,
        // 커뮤니티만 프레임 높이를 따로 쓰면 홈·선수와 세로 위치가 달라져요.
        toolbarHeight: 48,
        centerTitle: false,
        titleSpacing: 0,
        flexibleSpace: ColoredBox(color: pageBackground),
        // 48px 상단 바 밖으로 퍼지는 버튼 그림자를 자르지 않아요.
        clipBehavior: Clip.none,
        title: Padding(
          padding: const EdgeInsets.only(left: 24),
          child: SvgPicture.asset(
            'assets/app_logo.svg',
            key: logoKey,
            height: 23,
            width: 120,
            colorFilter: ColorFilter.mode(
                Theme.of(context).colorScheme.onSurface, BlendMode.srcIn),
          ),
        ),
        actions: [actions],
      );
}

class AppHeaderActions extends StatelessWidget {
  const AppHeaderActions({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 24),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            children[i],
          ],
        ]),
      );
}

class AppHeaderIconButton extends StatelessWidget {
  const AppHeaderIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
  });

  final VoidCallback onPressed;
  final Widget icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        iconSize: 32,
        color: Theme.of(context).colorScheme.onSurface,
        icon: icon,
      );
}
