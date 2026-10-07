part of 'team_screen_features.dart';

class _TeamPlayerAvatar extends StatelessWidget {
  const _TeamPlayerAvatar(this.url, {required this.radius, required this.size});

  final String? url;
  final double radius;
  final double size;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.of(context).subtleBackground,
        child: ClipOval(
          // 홈에서 준비한 사진을 선수 상세와 같은 크기로 디코딩해 재사용해요.
          child: PlayerRemoteImage.portrait(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      );
}

class TransferTile extends StatelessWidget {
  final TransferEntry transfer;

  const TransferTile({
    super.key,
    required this.transfer,
  });

  @override
  Widget build(BuildContext context) {
    final playerImage = transfer.playerImage;
    final playerName = _playerName(context, transfer);

    final content = Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 16, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _TeamPlayerAvatar(playerImage, radius: 36, size: 68),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name, Fee
                LayoutBuilder(
                  builder: (context, constraints) => Row(
                    children: [
                      Expanded(
                        child: Text(
                          playerName,
                          key: ValueKey(
                              'transfer-player-name-${transfer.transferId}'),
                          style: Body1_b.style,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          // Transfer types such as "Free Transfer", "Unknown",
                          // and "On Loan" need more room than compact fees.
                          // Keep enough of the row available for the player name,
                          // while showing the complete type whenever it fits.
                          maxWidth: constraints.maxWidth * 0.75,
                        ),
                        child: transfer.typeId == 219 && transfer.amount != null
                            ? TransferFee(
                                amountInEuros: transfer.amount!,
                                textKey: ValueKey(
                                    'transfer-value-${transfer.transferId}'),
                              )
                            : transferValueText(
                                _transferType(context, transfer),
                                key: ValueKey(
                                    'transfer-value-${transfer.transferId}'),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // FROM / TO badge + team name
                Row(
                  children: [
                    Badge(
                      label: transfer.direction == TransferDirection.incoming
                          ? tr(context, 'FROM')
                          : tr(context, 'TO'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        teamNameLabel(
                            context,
                            transfer.otherTeamId,
                            transfer.otherTeamName ??
                                tr(context, 'Unknown Team')),
                        style: Body1.style,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                _contractDate(context, transfer),
              ],
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: tr(context, 'Open {name}', {
        'name': playerName,
      }),
      child: InkWell(
        key: ValueKey('transfer-${transfer.transferId}'),
        onTap: () => openPlayerPage(context, transfer.playerId.toString()),
        child: content,
      ),
    );
  }

  static String _playerName(BuildContext context, TransferEntry transfer) {
    final localized = playerNameLabel(
      context,
      transfer.playerId,
      transfer.playerName ?? tr(context, 'Unknown Player'),
    );

    // Transfers do not provide a jersey number. Some localized name catalog
    // entries may still contain a legacy jersey-number prefix, so keep that
    // transport artifact out of this screen without changing shared labels.
    return localized.replaceFirst(
      RegExp(r'^\s*#?\d{1,3}(?:번)?(?:\s*[·•.()\-]\s*|\s+)'),
      '',
    );
  }

  static String _transferType(BuildContext context, TransferEntry transfer) {
    final original =
        transfer.typeId == 219 ? 'Unknown' : transfer.displayType ?? '-';
    // 영문은 기존 표기를 유지하고, 요청된 세 언어의 문구만 바꿔요.
    if (Localizations.localeOf(context).languageCode == 'en') return original;

    // 임대는 영입·방출에 같은 문구를 쓰고, 자유 계약·임대 복귀만 방향을 구분해요.
    final message = switch ((transfer.typeId, transfer.direction)) {
      (220, TransferDirection.incoming) => 'Free Transfer',
      (220, TransferDirection.outgoing) => 'Contract expired',
      (9688, TransferDirection.incoming) => 'Return from loan',
      (218, _) => 'Loan transfer',
      (219, _) => 'No information',
      _ => null,
    };
    return message == null ? original : tr(context, message);
  }

  static Widget _contractDate(BuildContext context, TransferEntry transfer) {
    final start = transfer.contractStartDate;
    final end = transfer.contractEndDate;
    final formatter = DateFormat('MMM yyyy');
    final label = start == null && end == null
        ? '-'
        : '${start == null ? '-' : formatter.format(start)} – '
            '${end == null ? '-' : formatter.format(end)}';
    final text = Text(tr(context, label), style: Body1.style);

    if (start != null && end != null) return text;
    return Tooltip(
      message:
          tr(context, 'Complete contract dates are currently unavailable.'),
      child: text,
    );
  }
}

class Badge extends StatelessWidget {
  final String label;
  const Badge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: appColors.subtleBackground,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(tr(context, label), style: Eyebrow.style),
    );
  }
}
