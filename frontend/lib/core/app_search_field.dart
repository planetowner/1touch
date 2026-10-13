import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';

abstract final class AppSearchFieldTokens {
  static const double radius = 8;
}

class AppEditSearchField extends StatelessWidget {
  const AppEditSearchField({
    super.key,
    this.containerKey,
    required this.controller,
    required this.hintText,
    required this.searching,
    this.verticalPadding = 14,
    this.outerHorizontalPadding = 0,
    this.clearIconSize = 24,
  });

  final TextEditingController controller;
  final Key? containerKey;
  final String hintText;
  final bool searching;
  final double verticalPadding;
  final double outerHorizontalPadding;
  final double clearIconSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: containerKey,
      padding: EdgeInsets.symmetric(horizontal: outerHorizontalPadding),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? AppPalette.lightGrey : AppPalette.lightGreyBox,
        borderRadius: BorderRadius.circular(AppSearchFieldTokens.radius),
      ),
      child: TextField(
        controller: controller,
        style: Body1.style.copyWith(color: colors.onSurface),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16 - outerHorizontalPadding,
            vertical: verticalPadding,
          ),
          hintText: hintText,
          hintStyle: Body1.style.copyWith(color: appColors.mutedForeground),
          border: InputBorder.none,
          suffixIcon: searching
              ? IconButton(
                  onPressed: controller.clear,
                  icon: Icon(Icons.close,
                      size: clearIconSize, color: colors.onSurface),
                )
              : Icon(Icons.search, size: 24, color: colors.onSurface),
        ),
      ),
    );
  }
}
