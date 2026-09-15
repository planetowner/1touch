part of 'team_screen_features.dart';

class TransferTile extends StatelessWidget {
  final TransferEntry transfer;
  final String dateLabel;

  const TransferTile({
    super.key,
    required this.transfer,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final playerImage = transfer.playerImage;
    final transferValue = _transferValue(transfer);
    final isLoan = (transfer.displayType ?? '').contains('Loan');
    final appColors = AppColors.of(context);

    return Container(
      key: ValueKey('transfer-${transfer.transferId}'),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        transfer.playerName ?? 'Unknown Player',
                        style: Heading5.style,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        transferValue,
                        style: Heading5.style,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // FROM / TO badge + team name
                Row(
                  children: [
                    Badge(
                      label: transfer.direction == TransferDirection.incoming
                          ? 'FROM'
                          : 'TO',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        transfer.otherTeamName ?? 'Unknown Team',
                        style: Body1.style,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // DATE badge + formatted date, LOAN chip if applicable
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Badge(label: 'DATE'),
                    Text(dateLabel, style: Body1.style),
                    if (isLoan) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD82457).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'LOAN',
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
  }

  static String _transferValue(TransferEntry transfer) {
    if (transfer.typeId != 219) {
      return transfer.displayType ?? '-';
    }
    if (transfer.amount == null) return 'Unknown';

    // Temporary frontend-only rule: verified Sportmonks fixtures and public
    // fees indicate confirmed transfer amounts are EUR. Remove this assumption
    // when the backend starts returning authoritative currency metadata.
    return '€${_compactAmount(transfer.amount!)}';
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
      child: Text(label, style: Eyebrow.style),
    );
  }
}
