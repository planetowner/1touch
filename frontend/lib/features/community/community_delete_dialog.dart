import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
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

enum _CommunityAuthorAction { edit, delete }

class CommunityAuthorMenu extends StatelessWidget {
  const CommunityAuthorMenu({
    super.key,
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => PopupMenuButton<_CommunityAuthorAction>(
        tooltip: tr(context, 'More options'),
        enabled: onEdit != null || onDelete != null,
        color: AppColors.of(context).cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox.square(
          dimension: 40,
          child: Center(
            child: Icon(
              Icons.more_horiz,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        onSelected: (action) {
          switch (action) {
            case _CommunityAuthorAction.edit:
              onEdit?.call();
              break;
            case _CommunityAuthorAction.delete:
              onDelete?.call();
              break;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<_CommunityAuthorAction>(
            value: _CommunityAuthorAction.edit,
            child: Text(tr(context, 'Edit'), style: Body2.style),
          ),
          PopupMenuItem<_CommunityAuthorAction>(
            value: _CommunityAuthorAction.delete,
            child: Text(tr(context, 'Delete'), style: Body2.style),
          ),
        ],
      );
}
