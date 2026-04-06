import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

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
  final String name;         // Full name, e.g. "M. Rashford"
  final int jerseyNumber;
  final List<String> positions; // e.g. ['ST', 'LW', 'LM']
  final String club;
  final String nationality;
  final String? flagEmoji;
  final String? playerImageUrl; // network URL for player headshot
  final List<PlayerMatchStatSection> sections;

  const PlayerMatchStatData({
    required this.name,
    required this.jerseyNumber,
    required this.positions,
    required this.club,
    required this.nationality,
    this.flagEmoji,
    this.playerImageUrl,
    required this.sections,
  });
}


void showPlayerMatchStatSheet(BuildContext context, PlayerMatchStatData player) {
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

  const PlayerMatchStatSheet({super.key, required this.player});

  static const _accentColor = Color(0xFFD82457);
  static const _headerDark  = Color(0xFF260011); // deep maroon end of gradient
  static const _sheetBg     = Color(0xFF1C1C1E);
  static const _cardBg      = Color(0xFF2C2C2E);
  static const _dividerColor = Color(0xFF3A3A3C);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.78, 0.95],
      builder: (_, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              _Header(player: player),
              Expanded(
                child: ColoredBox(
                  color: _sheetBg,
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
        );
      },
    );
  }
}


class _Header extends StatelessWidget {
  final PlayerMatchStatData player;

  const _Header({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFD82457), // accent red (left / top)
            Color(0xFF5A001F), // mid maroon
            Color(0xFF260011), // deep dark (right / bottom)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: name + action icons ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      // TODO: navigate to full player profile
                    },
                    child: Row(
                      children: [
                        Text(
                          player.name,
                          style: Heading2.style.copyWith(color: Colors.white),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _HeaderIconBtn(
                    icon: Icons.star_border_rounded,
                    onTap: () {
                      // TODO: favourite player
                    },
                  ),
                  _HeaderIconBtn(
                    icon: Icons.compare, // compare players
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

              // ── Jersey number + info + photo ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Left: number & meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${player.jerseyNumber}',
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
                          player.club,
                          style: Body1.style.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${player.nationality}${player.flagEmoji != null ? ' ${player.flagEmoji}' : ''}',
                          style: Body1.style.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                  // Right: player headshot
                  if (player.playerImageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          player.playerImageUrl!,
                          height: 130,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox(
                            width: 90,
                            height: 130,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(section.category, style: Eyebrow.style),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
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
                      Text(section.rows[i].label, style: Body1.style),
                      const Spacer(),
                      Text(section.rows[i].value, style: Body1_b.style),
                    ],
                  ),
                ),
                if (i < section.rows.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Color(0xFF3A3A3C),
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
  name: 'M. Rashford',
  jerseyNumber: 14,
  positions: ['ST', 'LW', 'LM'],
  club: 'FC Barcelona',
  nationality: 'England',
  flagEmoji: '🏴󠁧󠁢󠁥󠁮󠁧󠁿',
  playerImageUrl: null, // replace with real URL
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