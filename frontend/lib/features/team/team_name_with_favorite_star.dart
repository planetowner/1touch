import 'package:flutter/material.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class TeamNameWithFavoriteStar extends StatelessWidget {
  const TeamNameWithFavoriteStar({
    super.key,
    required this.teamId,
    required this.name,
    required this.isFavorite,
    required this.style,
  });

  final int teamId;
  final String name;
  final bool isFavorite;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Flexible(
            child: Text(
              teamNameLabel(context, teamId, name),
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isFavorite)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                Icons.star,
                key: ValueKey('favorite-team-star-$teamId'),
                color: Theme.of(context).colorScheme.onSurface,
                size: 20,
              ),
            ),
        ],
      );
}
