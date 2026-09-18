enum BetOutcome {
  homeWin('home_win'),
  draw('draw'),
  awayWin('away_win');

  const BetOutcome(this.apiValue);
  final String apiValue;

  static BetOutcome parse(String value) =>
      values.firstWhere((outcome) => outcome.apiValue == value);
}

class BettingOption {
  const BettingOption({
    required this.outcome,
    required this.probabilityText,
    required this.decimalOdds,
  });

  final BetOutcome outcome;
  final String probabilityText;
  final double decimalOdds;
  double get probability => double.parse(probabilityText);

  int totalReturn(int stake) {
    // 서버에 저장한 십진 확률 그대로 나눠 소수점 경계에서 1 pts가 달라지지 않게 해요.
    final parts = probabilityText.split('.');
    final fraction = parts.length == 2 ? parts[1] : '';
    final numerator = BigInt.parse('${parts[0]}$fraction');
    return (BigInt.from(stake) *
            BigInt.from(10).pow(fraction.length) ~/
            numerator)
        .toInt();
  }
}

class PointWallet {
  const PointWallet({required this.balance, required this.initialized});
  final int balance;
  final bool initialized;
}

class FixtureBet {
  const FixtureBet({
    required this.betId,
    required this.fixtureId,
    required this.outcome,
    required this.stake,
    required this.probabilityText,
    required this.decimalOdds,
    required this.potentialReturn,
    required this.status,
    required this.revision,
    required this.payout,
  });

  final int betId;
  final int fixtureId;
  final BetOutcome outcome;
  final int stake;
  final String probabilityText;
  final double decimalOdds;
  final int potentialReturn;
  final String status;
  final int revision;
  final int payout;
  bool get isOpen => status == 'open';
}

class BetMutation {
  const BetMutation({required this.wallet, required this.bet});
  final PointWallet wallet;
  final FixtureBet bet;
}

class BettingMarket {
  const BettingMarket({
    required this.fixtureId,
    required this.available,
    required this.canBet,
    required this.canCancel,
    required this.unavailableReason,
    required this.closesAt,
    required this.predictionRunId,
    required this.predictionAsOf,
    required this.options,
    required this.wallet,
    required this.bet,
    required this.participantCount,
    required this.userProbabilities,
  });

  final int fixtureId;
  final bool available;
  final bool canBet;
  final bool canCancel;
  final String? unavailableReason;
  final DateTime? closesAt;
  final String? predictionRunId;
  final DateTime? predictionAsOf;
  final List<BettingOption> options;
  final PointWallet wallet;
  final FixtureBet? bet;
  final int participantCount;
  final List<double>? userProbabilities;

  BettingMarket withMutation(BetMutation result) => BettingMarket(
        fixtureId: fixtureId,
        available: available,
        canBet: canBet,
        canCancel: canBet && result.bet.isOpen,
        unavailableReason: unavailableReason,
        closesAt: closesAt,
        predictionRunId: predictionRunId,
        predictionAsOf: predictionAsOf,
        options: options,
        wallet: result.wallet,
        bet: result.bet,
        participantCount: participantCount,
        userProbabilities: userProbabilities,
      );
}
