import 'package:onetouch/features/community/community_ui.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/l10n/app_localizations.dart';

Future<bool> confirmCommunityDelete(
  BuildContext context, {
  required bool isPost,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          titlePadding: const EdgeInsets.all(24),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          title: Text(tr(
            dialogContext,
            isPost ? 'Delete post?' : 'Delete comment?',
          )),
          content: Text(tr(dialogContext, 'This cannot be undone.')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(tr(dialogContext, 'Cancel')),
            ),
            TextButton(
              key: const ValueKey('community-confirm-delete'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(tr(dialogContext, 'Delete')),
            ),
          ],
        ),
      ) ??
      false;
}

enum _CommunityAuthorAction { edit, delete, report, copy }

class CommunityAuthorMenu extends StatelessWidget {
  const CommunityAuthorMenu({
    super.key,
    required this.boundaryContext,
    this.onEdit,
    this.onDelete,
    this.onReport,
    this.onCopy,
  });

  // 화면 전체가 아니라 이 본문 영역의 오른쪽 끝을 기준으로 정렬해요.
  final BuildContext boundaryContext;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final VoidCallback? onCopy;

  Future<void> _openMenu(BuildContext context) async {
    final actions = [
      for (final (value, label, icon, callback) in [
        (_CommunityAuthorAction.edit, 'Edit', 'edit', onEdit),
        (_CommunityAuthorAction.delete, 'Delete', 'delete', onDelete),
        (_CommunityAuthorAction.report, 'Report', 'report', onReport),
        (_CommunityAuthorAction.copy, 'Copy Text', 'copy', onCopy),
      ])
        if (callback != null) (value, tr(context, label), icon, callback),
    ];
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final button = context.findRenderObject()! as RenderBox;
    final boundary = boundaryContext.findRenderObject()! as RenderBox;
    final trigger =
        button.localToGlobal(Offset.zero, ancestor: overlay) & button.size;
    final bounds =
        boundary.localToGlobal(Offset.zero, ancestor: overlay) & boundary.size;
    final textStyle = CommunityText.secondary(context);
    const itemPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    const iconSize = 18.0;
    const iconGap = 4.0;
    var width = 119.0;
    for (final (_, label, _, _) in actions) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final itemWidth =
          (painter.width + itemPadding.horizontal + iconSize + iconGap)
              .ceilToDouble();
      if (itemWidth > width) width = itemWidth;
      painter.dispose();
    }
    final menuWidth = width.clamp(119.0, 280.0).clamp(0.0, bounds.width);
    // 왼쪽 정렬을 유지하고, 실제 메뉴가 본문 오른쪽을 넘을 때만 뒤집어요.
    final left = trigger.left + menuWidth <= bounds.right
        ? trigger.left
        : trigger.right - menuWidth;
    final selected = await showMenu<_CommunityAuthorAction>(
      context: context,
      // 메뉴 너비까지 포함한 사각형을 넘겨 Flutter의 화면 중앙 기준 정렬을 피해요.
      position: RelativeRect.fromRect(
        Rect.fromLTWH(left, trigger.bottom, menuWidth, 0),
        Offset.zero & overlay.size,
      ),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      color: Theme.of(context).brightness == Brightness.dark
          ? AppPalette.lightGrey
          : AppPalette.white,
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      constraints: BoxConstraints.tightFor(width: menuWidth),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        for (final (action, label, icon, _) in actions)
          PopupMenuItem<_CommunityAuthorAction>(
            value: action,
            height: 30,
            padding: itemPadding,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              CommunityIcon(icon, size: iconSize),
              const SizedBox(width: iconGap),
              Flexible(child: Text(label, style: textStyle)),
            ]),
          ),
      ],
    );
    if (!context.mounted || selected == null) return;
    actions.firstWhere((action) => action.$1 == selected).$4();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = onEdit != null ||
        onDelete != null ||
        onReport != null ||
        onCopy != null;
    return Tooltip(
      message: tr(context, 'More options'),
      child: Semantics(
        button: true,
        enabled: enabled,
        child: InkWell(
          onTap: enabled ? () => _openMenu(context) : null,
          child: const SizedBox.square(
              dimension: 24, child: CommunityIcon('more')),
        ),
      ),
    );
  }
}
