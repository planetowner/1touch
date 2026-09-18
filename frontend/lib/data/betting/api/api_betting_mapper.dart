import 'package:onetouch/models/betting.dart';

PointWallet walletFromJson(Map<String, dynamic> json) => PointWallet(
      balance: json['balance'] as int,
      initialized: json['initialized'] as bool,
    );

FixtureBet betFromJson(Map<String, dynamic> json) => FixtureBet(
      betId: json['bet_id'] as int,
      fixtureId: json['fixture_id'] as int,
      outcome: BetOutcome.parse(json['outcome'] as String),
      stake: json['stake'] as int,
      probabilityText: json['probability'] as String,
      decimalOdds: double.parse(json['decimal_odds'] as String),
      potentialReturn: json['potential_return'] as int,
      status: json['status'] as String,
      revision: json['revision'] as int,
      payout: json['payout'] as int,
    );

BetMutation mutationFromJson(Map<String, dynamic> json) => BetMutation(
      wallet: walletFromJson(json['wallet'] as Map<String, dynamic>),
      bet: betFromJson(json['bet'] as Map<String, dynamic>),
    );

BettingMarket marketFromJson(Map<String, dynamic> json) {
  final participation = json['participation'] as Map<String, dynamic>;
  final probabilities = participation['probabilities'] as Map<String, dynamic>?;
  final options = (json['options'] as List<dynamic>).map((value) {
    final option = value as Map<String, dynamic>;
    return BettingOption(
      outcome: BetOutcome.parse(option['outcome'] as String),
      probabilityText: option['probability'] as String,
      decimalOdds: double.parse(option['decimal_odds'] as String),
    );
  }).toList(growable: false);
  if (options.isNotEmpty &&
      (options.length != 3 ||
          options.asMap().entries.any(
                (entry) =>
                    entry.value.outcome != BetOutcome.values[entry.key] ||
                    !entry.value.probability.isFinite ||
                    entry.value.probability <= 0 ||
                    entry.value.probability > 1,
              ))) {
    throw const FormatException('Invalid betting probabilities');
  }
  return BettingMarket(
    fixtureId: json['fixture_id'] as int,
    available: json['available'] as bool,
    canBet: json['can_bet'] as bool,
    canCancel: json['can_cancel'] as bool,
    unavailableReason: json['unavailable_reason'] as String?,
    closesAt: _date(json['closes_at']),
    predictionRunId: json['prediction_run_id'] as String?,
    predictionAsOf: _date(json['prediction_as_of']),
    options: options,
    wallet: walletFromJson(json['wallet'] as Map<String, dynamic>),
    bet: json['bet'] == null
        ? null
        : betFromJson(json['bet'] as Map<String, dynamic>),
    participantCount: participation['total'] as int,
    userProbabilities: probabilities == null
        ? null
        : BetOutcome.values
            .map(
              (outcome) => (probabilities[outcome.apiValue] as num).toDouble(),
            )
            .toList(growable: false),
  );
}

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.parse(value as String);
