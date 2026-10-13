import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/features/community/community_identity.dart';
import 'package:onetouch/features/media/avatar_image_cache.dart';
import 'package:onetouch/l10n/date_labels.dart';

const communityPostHorizontalPadding = 24.0;

Color communityPageBackground(BuildContext context) =>
    mainPageBackground(context);

Color communityDividerColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppPalette.lightGrey
        : AppColors.of(context).divider;

abstract final class CommunityText {
  static final _hangul = RegExp(r'[\u1100-\u11ff\u3130-\u318f\uac00-\ud7af]');

  static bool _isKorean(BuildContext context, String? text) => text == null
      ? Localizations.localeOf(context).languageCode == 'ko'
      : _hangul.hasMatch(text);

  // 사용자 글과 URL의 행간은 앱 설정이 아니라 실제 글자에 맞춰요.
  // Archivo가 한글을 포함하지 않아, 앱 언어와 관계없이 Pretendard를 함께 써요.
  static TextStyle forContent(TextStyle base, String text) =>
      _style(base, _hangul.hasMatch(text));

  static TextStyle _style(TextStyle base, bool korean) => base.copyWith(
        fontFamily: 'Archivo',
        fontFamilyFallback: const ['Pretendard'],
        height: korean ? 1.6 : 1.3,
        letterSpacing: 0,
        leadingDistribution: TextLeadingDistribution.even,
      );

  static TextStyle _bodyStyle(
          BuildContext context, TextStyle base, String? text) =>
      _style(base, _isKorean(context, text));

  static TextStyle title(BuildContext context, {String? text}) =>
      _isKorean(context, text)
          ? KoreanHeading5.style
          : Heading5.latinStyle.copyWith(height: 1.1, letterSpacing: 0);
  static TextStyle body(BuildContext context, {String? text}) =>
      _bodyStyle(context, KoreanBody1.style, text);
  static TextStyle bold(BuildContext context, {String? text}) =>
      _bodyStyle(context, KoreanBody1Bold.style, text);
  static TextStyle secondary(BuildContext context, {String? text}) =>
      _bodyStyle(context, KoreanBody2.style, text);
  static TextStyle secondaryBold(BuildContext context, {String? text}) =>
      _bodyStyle(context, KoreanBody2Bold.style, text);

  // 작성자 정보는 언어와 관계없이 Figma의 19/18px 줄 높이를 써요.
  // 130%를 그대로 쓰면 Flutter에서 이름 줄이 20px로 반올림돼요.
  static TextStyle _authorStyle(TextStyle base, double lineHeight) =>
      _style(base, false).copyWith(height: lineHeight / base.fontSize!);
  static TextStyle get authorName => _authorStyle(KoreanBody1.style, 19);
  static TextStyle get authorTime => _authorStyle(KoreanBody2.style, 18);
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
  Widget build(BuildContext context) {
    final author = communityAuthorLabel(
        locale: Localizations.localeOf(context),
        username: username,
        displayName: displayName,
        authorDeleted: authorDeleted);
    final time = communityPostTimeLabel(
        createdAt: createdAt,
        editedAt: editedAt,
        locale: Localizations.localeOf(context));
    return Row(children: [
      Expanded(
          child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: userId == null || authorDeleted
            ? null
            : () => context.push('/profile/activity?userId=$userId'),
        child: Row(children: [
          CircleAvatar(
            key: avatarKey,
            radius: 16,
            backgroundColor: AppPalette.lightGrey,
            backgroundImage: avatarUrl == null
                ? null
                : AvatarImageCache.provider(avatarUrl!),
            onBackgroundImageError: avatarUrl == null ? null : (_, __) {},
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(author,
                    style: CommunityText.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(time,
                    style: CommunityText.authorTime.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .5)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ])),
        ]),
      )),
      if (trailing != null) trailing!,
    ]);
  }
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
