import 'package:onetouch/models/team_probability.dart';

String probabilityEventTitle(String event) => switch (event) {
      'league_winner' => 'Chances to Win\nLeague Trophy',
      'ucl_winner' => 'Chances to Win\nUCL Trophy',
      'uel_winner' => 'Chances to Win\nUEL Trophy',
      'uecl_winner' => 'Chances to Win\nUECL Trophy',
      'top_4' => 'Chances to Finish\nTop 4',
      'top_6' => 'Chances to Finish\nTop 6',
      'direct_relegation' => 'Chances of\nRelegation',
      'relegation_playoff' => 'Chances to\nRelegation Playoff',
      _ => event
          .split('_')
          .where((part) => part.isNotEmpty)
          .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
          .join(' '),
    };

({String prefix, String number}) probabilityDisplay(TeamProbabilityCard card) {
  // 시뮬레이션의 0·1은 확정값이 아니에요. 서버가 증명한 결과만 0%·100%로 표시해요.
  if (card.resolution == ProbabilityResolution.impossible) {
    return (prefix: '', number: '0');
  }
  if (card.resolution == ProbabilityResolution.certain) {
    return (prefix: '', number: '100');
  }
  final tenths = (card.probability * 1000).round();
  if (tenths == 0) return (prefix: '<', number: '0.1');
  if (tenths == 1000) return (prefix: '>', number: '99.9');
  return (prefix: '', number: (tenths / 10).toStringAsFixed(1));
}
