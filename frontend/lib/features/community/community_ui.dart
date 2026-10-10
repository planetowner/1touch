import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/features/community/community_identity.dart';
import 'package:onetouch/features/community/community_post_image.dart';
import 'package:onetouch/l10n/date_labels.dart';

Color communityPageBackground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0A0A0A)
        : mainPageBackground(context);

Color communityDividerColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppPalette.lightGrey
        : AppColors.of(context).divider;

// 커뮤니티의 영문 행간만 디자인에 맞춰요. 다른 화면과 각 언어의 글꼴 규칙은 유지해요.
abstract final class CommunityText {
  static TextStyle _style(
          BuildContext context, TextStyle base, double height) =>
      Localizations.localeOf(context).languageCode == 'en'
          ? base.copyWith(height: height)
          : base;
  static TextStyle title(BuildContext context) =>
      _style(context, Heading5.style, 1.1);
  static TextStyle body(BuildContext context) =>
      _style(context, Body1.style, 1.3);
  static TextStyle bold(BuildContext context) =>
      _style(context, Body1_b.style, 1.3);
  static TextStyle secondary(BuildContext context) =>
      _style(context, Body2.style, 1.3);
}

class CommunityIcon extends StatelessWidget {
  const CommunityIcon(this.name,
      {super.key, this.size = 24, this.color, this.originalColors = false});
  final String name;
  final double size;
  final Color? color;
  final bool originalColors;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/community/$name.svg',
        width: size,
        height: size,
        colorFilter: originalColors
            ? null
            : ColorFilter.mode(color ?? Theme.of(context).colorScheme.onSurface,
                BlendMode.srcIn),
      );
}

class CommunityAuthorHeader extends StatelessWidget {
  const CommunityAuthorHeader(
      {super.key,
      required this.userId,
      required this.username,
      required this.displayName,
      required this.avatarUrl,
      required this.authorDeleted,
      required this.createdAt,
      this.editedAt,
      this.avatarKey,
      this.trailing});
  final int? userId;
  final String? username, displayName, avatarUrl, editedAt;
  final String createdAt;
  final bool authorDeleted;
  final Key? avatarKey;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: userId == null || authorDeleted
              ? null
              : () => context.push('/profile/activity?userId=$userId'),
          child: Row(children: [
            CircleAvatar(
              key: avatarKey,
              radius: 12,
              backgroundColor: AppPalette.lightGrey,
              backgroundImage:
                  avatarUrl == null ? null : communityImageProvider(avatarUrl!),
              onBackgroundImageError: avatarUrl == null ? null : (_, __) {},
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      communityAuthorLabel(
                          locale: Localizations.localeOf(context),
                          username: username,
                          displayName: displayName,
                          authorDeleted: authorDeleted),
                      style: CommunityText.body(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                      communityPostTimeLabel(
                          createdAt: createdAt,
                          editedAt: editedAt,
                          locale: Localizations.localeOf(context)),
                      style: CommunityText.secondary(context).copyWith(
                          color: AppColors.of(context).mutedForeground)),
                ])),
          ]),
        )),
        if (trailing != null) trailing!,
      ]);
}

// 상세 답글과 프로필의 댓글 미리보기는 같은 들여쓰기를 사용해요.
class CommunityReplyIndent extends StatelessWidget {
  const CommunityReplyIndent(
      {super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.only(left: enabled ? 22 : 0),
        decoration: enabled
            ? BoxDecoration(
                border: Border(
                    left: BorderSide(
                        color: communityDividerColor(context), width: 2)))
            : null,
        child: child,
      );
}
