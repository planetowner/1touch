part of 'team_screen_features.dart';

class TransferTile extends StatelessWidget {
  final TransferEntry transfer;

  const TransferTile({
    super.key,
    required this.transfer,
  });

  @override
  Widget build(BuildContext context) {
    final playerImage = transfer.playerImage;
    final transferValue = _transferValue(context, transfer);
    final playerName = _playerName(context, transfer);
    final isLoan = (transfer.displayType ?? '').contains(tr(context, 'Loan'));
    final appColors = AppColors.of(context);

    final content = Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 16, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Player photo
          CircleAvatar(
            radius: 36,
            backgroundColor: appColors.subtleBackground,
            child: ClipOval(
              child: playerImage == null || playerImage.isEmpty
                  ? Image.asset(
                      'assets/messi.png',
                      width: 68,
                      height: 68,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      playerImage,
                      width: 68,
                      height: 68,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/messi.png',
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
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
                        child: Text(
                          transferValue,
                          key:
                              ValueKey('transfer-value-${transfer.transferId}'),
                          style: Body1_b.style,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
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

                // Contract range + LOAN chip if applicable
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _contractDate(context, transfer),
                    if (isLoan) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD82457).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tr(context, 'LOAN'),
                          style: Eyebrow.style
                              .copyWith(color: const Color(0xFFD82457)),
                        ),
                      ),
                    ],
                  ],
                ),
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

  static String _transferValue(BuildContext context, TransferEntry transfer) {
    if (transfer.typeId == 219 && transfer.amount != null) {
      // Temporary frontend-only rule: verified Sportmonks fixtures and public
      // fees indicate confirmed transfer amounts are EUR. Remove this assumption
      // when the backend starts returning authoritative currency metadata.
      return '€${_compactAmount(transfer.amount!)}';
    }

    final original =
        transfer.typeId == 219 ? 'Unknown' : transfer.displayType ?? '-';
    // 영문은 기존 표기를 유지하고, 요청된 세 언어의 문구만 바꿔요.
    if (Localizations.localeOf(context).languageCode == 'en') return original;

    // 같은 이적 유형도 영입·방출 방향에 따라 문구가 달라요.
    final message = switch ((transfer.typeId, transfer.direction)) {
      (220, TransferDirection.incoming) => 'Free Transfer',
      (220, TransferDirection.outgoing) => 'Contract expired',
      (9688, TransferDirection.incoming) => 'Return from loan',
      (218, TransferDirection.outgoing) => 'Loan transfer',
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

  static String _compactAmount(int amount) {
    if (amount >= 1000000000) {
      return '${_scaledAmount(amount, 1000000000)}bn';
    }
    if (amount >= 1000000) {
      return '${_scaledAmount(amount, 1000000)}m';
    }
    if (amount >= 1000) {
      return '${_scaledAmount(amount, 1000)}k';
    }
    return '$amount';
  }

  static String _scaledAmount(int amount, int divisor) {
    final scaled = amount / divisor;
    return scaled == scaled.roundToDouble()
        ? scaled.toInt().toString()
        : scaled.toStringAsFixed(1);
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
