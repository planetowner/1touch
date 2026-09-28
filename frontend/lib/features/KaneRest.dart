import 'package:onetouch/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/core/team_comparison_colors.dart';
import 'package:onetouch/features/player/player_following_controller.dart';

class PlayerMatchStatRow {
  final String label;
  final String value;

  const PlayerMatchStatRow({required this.label, required this.value});
}

class PlayerMatchStatSection {
  final String category;
  final List<PlayerMatchStatRow> rows;

  const PlayerMatchStatSection({required this.category, required this.rows});
}

class PlayerMatchStatData {
  final int? playerId;
  final int? teamId;
  final int teamPrimaryColor;
  final String name;
  final int? jerseyNumber;
  final List<String> positions;
  final String club;
  final String? nationality;
  final String? flagEmoji;
  final String? playerImageUrl;
  final String? playerImageAsset;
  final List<PlayerMatchStatSection> sections;

  const PlayerMatchStatData({
    this.playerId,
    this.teamId,
    required this.teamPrimaryColor,
    required this.name,
    required this.jerseyNumber,
    required this.positions,
    required this.club,
    required this.nationality,
    this.flagEmoji,
    this.playerImageUrl,
    this.playerImageAsset,
    required this.sections,
  });
}

void showPlayerMatchStatSheet(
    BuildContext context, PlayerMatchStatData player) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (_) => PlayerMatchStatSheet(player: player),
  );
}

class PlayerMatchStatSheet extends StatelessWidget {
  final PlayerMatchStatData player;
  final PlayerFollowingController? followingController;

  const PlayerMatchStatSheet({
    super.key,
    required this.player,
    this.followingController,
  });

  static const _sheetBg = AppPalette.darkGrey;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.78, 0.95],
      builder: (_, scrollController) {
        return TapRegion(
          key: const ValueKey('player-match-stat-tap-region'),
          onTapOutside: (_) => Navigator.of(context).pop(),
          child: ClipRRect(
            key: const ValueKey('player-match-stat-sheet'),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Column(
              children: [
                _Header(
                  player: player,
                  followingController: followingController,
                ),
                Expanded(
                  child: ColoredBox(
                    color: isDark ? _sheetBg : AppPalette.white,
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                      children: [
                        for (int i = 0; i < player.sections.length; i++) ...[
                          _StatSection(section: player.sections[i]),
                          if (i < player.sections.length - 1)
                            const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final PlayerMatchStatData player;
  final PlayerFollowingController? followingController;

  const _Header({required this.player, this.followingController});

  @override
  Widget build(BuildContext context) {
    final primary = _ensureWhiteTextContrast(Color(player.teamPrimaryColor));
    return Container(
      key: const ValueKey('player-match-stat-header'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary,
            Color.alphaBlend(
              Colors.black.withValues(alpha: 0.28),
              primary,
            ),
            Color.alphaBlend(
              Colors.black.withValues(alpha: 0.62),
              primary,
            ),
          ],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //   Top row: name + action icons
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: GestureDetector(
                      key: const ValueKey('player-match-stat-profile-link'),
                      onTap: player.playerId == null
                          ? null
                          : () {
                              final router = GoRouter.of(context);
                              Navigator.of(context).pop();
                              router.go('/players/${player.playerId}');
                            },
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              playerNameLabel(
                                  context, player.playerId, player.name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  Heading2.style.copyWith(color: Colors.white),
                            ),
                          ),
                          if (player.playerId != null) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _PlayerMatchFollowButton(
                    playerId: player.playerId,
                    controller: followingController,
                  ),
                  _HeaderIconBtn(
                    icon: Icons.safety_divider, // compare players
                    onTap: () {
                      // TODO: open comparison sheet
                    },
                  ),
                  _HeaderIconBtn(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              //   Jersey number + info + photo
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Left: number & meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.jerseyNumber?.toString() ?? '—',
                          style: const TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          player.positions.join(' • '),
                          style: Body1.style.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          teamNameLabel(context, player.teamId, player.club),
                          style: Body1.style.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 2),
                        if (player.nationality != null)
                          Text(
                            '${player.nationality}${player.flagEmoji != null ? ' ${player.flagEmoji}' : ''}',
                            style: Body1.style.copyWith(color: Colors.white70),
                          ),
                      ],
                    ),
                  ),

                  // Right: player headshot
                  if (player.playerImageAsset != null ||
                      player.playerImageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ShaderMask(
                        key: const ValueKey(
                            'player-match-stat-image-bottom-fade'),
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0, 0.78, 1],
                        ).createShader(bounds),
                        child: player.playerImageAsset != null
                            ? Image.asset(
                                player.playerImageAsset!,
                                height: 140,
                                fit: BoxFit.contain,
                              )
                            : Image.network(
                                player.playerImageUrl!,
                                height: 140,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const SizedBox(
                                  width: 90,
                                  height: 140,
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerMatchFollowButton extends StatefulWidget {
  const _PlayerMatchFollowButton({
    required this.playerId,
    this.controller,
  });

  final int? playerId;
  final PlayerFollowingController? controller;

  @override
  State<_PlayerMatchFollowButton> createState() =>
      _PlayerMatchFollowButtonState();
}

class _PlayerMatchFollowButtonState extends State<_PlayerMatchFollowButton> {
  PlayerFollowingController get _controller =>
      widget.controller ?? playerFollowingController;

  @override
  void initState() {
    super.initState();
    if (widget.playerId != null && !_controller.loaded) {
      _controller.load();
    }
  }

  @override
  void didUpdateWidget(covariant _PlayerMatchFollowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.playerId != widget.playerId ||
            oldWidget.controller != widget.controller) &&
        widget.playerId != null &&
        !_controller.loaded) {
      _controller.load();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final playerId = widget.playerId;
          final followed = playerId != null && _controller.contains(playerId);
          return GestureDetector(
            key: const ValueKey('player-match-stat-follow-button'),
            onTap: playerId == null || _controller.loading
                ? null
                : () async {
                    try {
                      await _controller.toggle(playerId);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              tr(context, 'Could not save favorites'),
                            ),
                          ),
                        );
                      }
                    }
                  },
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                followed ? Icons.star_rounded : Icons.star_border_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          );
        },
      );
}

Color _ensureWhiteTextContrast(Color color) {
  if (ColorUtils.getContrastRatio(color, Colors.white) >= 4.5) return color;

  for (var opacity = 0.05; opacity <= 0.8; opacity += 0.05) {
    final candidate = Color.alphaBlend(
      Colors.black.withValues(alpha: opacity),
      color,
    );
    if (ColorUtils.getContrastRatio(candidate, Colors.white) >= 4.5) {
      return candidate;
    }
  }
  return Colors.black;
}

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _StatSection extends StatelessWidget {
  final PlayerMatchStatSection section;

  const _StatSection({required this.section});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appColors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, section.category),
          style: Eyebrow.style.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          key: const ValueKey('match-player-stat-card'),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.lightGrey : AppPalette.lightGreyBox,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              for (int i = 0; i < section.rows.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Text(appStatLabel(context, section.rows[i].label),
                          style: Body1.style),
                      const Spacer(),
                      Text(section.rows[i].value, style: Body1_b.style),
                    ],
                  ),
                ),
                if (i < section.rows.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                    color: isDark ? AppPalette.lightGrey : appColors.divider,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

final mockRashfordStats = PlayerMatchStatData(
  teamPrimaryColor: 0xFFA50044,
  name: 'M. Rashford',
  jerseyNumber: 14,
  positions: ['ST', 'LW', 'LM'],
  club: 'FC Barcelona',
  nationality: 'England',
  flagEmoji: '🏴󠁧󠁢󠁥󠁮󠁧󠁿',
  playerImageAsset: 'assets/playerAvatar.png',
  sections: const [
    PlayerMatchStatSection(
      category: 'FINISH',
      rows: [
        PlayerMatchStatRow(label: 'Goals', value: '1'),
        PlayerMatchStatRow(label: 'xG', value: '0.7'),
      ],
    ),
    PlayerMatchStatSection(
      category: 'PLAY-MAKING',
      rows: [
        PlayerMatchStatRow(label: 'Key Passes', value: '4'),
        PlayerMatchStatRow(label: 'Passes into Pen. Area', value: '5'),
      ],
    ),
    PlayerMatchStatSection(
      category: 'DEFENSE',
      rows: [
        PlayerMatchStatRow(label: 'Distance Covered', value: '10.1 km'),
        PlayerMatchStatRow(label: 'Recoveries', value: '7'),
      ],
    ),
    PlayerMatchStatSection(
      category: 'DRIBBLE',
      rows: [
        PlayerMatchStatRow(label: 'Attempts', value: '6'),
        PlayerMatchStatRow(label: 'Succ. Rate (Take-Ons)', value: '89%'),
      ],
    ),
    PlayerMatchStatSection(
      category: 'LINK-UP',
      rows: [
        PlayerMatchStatRow(label: 'Touches', value: '9'),
        PlayerMatchStatRow(label: 'Passes (Succ. / Attempts)', value: '13'),
      ],
    ),
  ],
);
