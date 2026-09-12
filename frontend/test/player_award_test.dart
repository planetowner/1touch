import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/models/player.dart';

void main() {
  test('defines the supported individual award types', () {
    expect(PlayerAwardType.values, hasLength(10));
    expect(
      PlayerAwardType.values.map((type) => type.label),
      [
        'Top Scorer',
        'Top Assists',
        'Goalkeeper of the Year',
        'Defender of the Year',
        'Midfielder of the Year',
        'Forward of the Year',
        'Player of the Year',
        'European Golden Shoe',
        'Golden Boy',
        "Ballon d'Or",
      ],
    );
    expect(
      PlayerAwardType.values.where((type) => type.requiresCompetition),
      PlayerAwardType.values.take(7),
    );
  });

  test('includes the competition in a competition award name', () {
    const award = PlayerAward(
      type: PlayerAwardType.topScorer,
      competitionName: 'UEFA Champions League',
      seasons: ['25/26'],
    );

    expect(award.name, 'UEFA Champions League Top Scorer');
  });

  test('uses only the award label for a global award', () {
    const award = PlayerAward(
      type: PlayerAwardType.ballonDor,
      seasons: ['25/26'],
    );

    expect(award.name, "Ballon d'Or");
  });
}
