import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class OneTouchBottomNavigationBar extends StatelessWidget {
  const OneTouchBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _topPadding = 12.0;
  static const _bottomPadding = 32.0;
  static const _iconSize = 32.0;
  static const _labelGap = 8.0;
  static const _items = [
    (label: 'Home', asset: 'home', minWidth: 40.0),
    (label: 'Team', asset: 'team', minWidth: 40.0),
    (label: 'Players', asset: 'players', minWidth: 47.0),
    (label: 'Community', asset: 'community', minWidth: 40.0),
  ];

  static TextStyle _labelStyle(BuildContext context) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    return Body2.style.copyWith(
      fontFamily: isKorean ? 'Pretendard' : 'Archivo',
      height: isKorean ? 1.6 : 1.3,
      letterSpacing: 0,
    );
  }

  static double _contentHeight(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: tr(context, 'Home'), style: _labelStyle(context)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final labelHeight = painter.height;
    painter.dispose();
    return _topPadding + _iconSize + _labelGap + labelHeight;
  }

  // 한·영 행간과 기기 안전 여백을 반영한 높이를 바와 베팅 결과 팝업이 함께 써요.
  static double heightOf(BuildContext context) =>
      _contentHeight(context) +
      math.max(_bottomPadding, MediaQuery.paddingOf(context).bottom);

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.white
        : const Color(0xFF0A0A0A);

    return ColoredBox(
      color: AppColors.of(context).cardBackground,
      child: SafeArea(
        top: false,
        // 시안의 32px과 기기 안전 여백을 더하지 않고 더 큰 쪽을 확보해요.
        minimum: const EdgeInsets.only(bottom: _bottomPadding),
        child: SizedBox(
          key: const ValueKey('main-bottom-navigation-content'),
          height: _contentHeight(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, _topPadding, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < _items.length; index++)
                  _buildItem(context, index, foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index, Color foreground) {
    final item = _items[index];
    final label = tr(context, item.label);
    final isSelected = currentIndex == index;
    // 선택 여부는 채움·외곽선으로 구분하고, 색과 불투명도는 같게 유지해요.
    final asset = '${item.asset}${isSelected ? '_active' : ''}';

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label tab',
      child: InkWell(
        key: ValueKey('main-bottom-navigation-$index'),
        onTap: () => onTap(index),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: item.minWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 32px 안쪽 도형 크기도 시안과 같도록 원본 SVG를 그대로 써요.
              SvgPicture.asset(
                'assets/navigation/$asset.svg',
                width: _iconSize,
                height: _iconSize,
                colorMapper: const _NavigationMaskColorMapper(),
                colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
              ),
              const SizedBox(height: _labelGap),
              Text(
                label,
                maxLines: 1,
                style: _labelStyle(context).copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationMaskColorMapper extends ColorMapper {
  const _NavigationMaskColorMapper();

  @override
  Color substitute(
      String? id, String elementName, String attributeName, Color color) {
    // 렌더러는 알파 마스크의 회색도 투명도로 계산해요. 원본의 불투명한
    // Bounding box를 흰색으로 읽어 도형이 85%로 옅어지는 현상을 막아요.
    if (id == 'Bounding box' &&
        elementName == 'rect' &&
        attributeName == 'fill') {
      return AppPalette.white;
    }
    return color;
  }
}
