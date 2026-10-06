import 'package:onetouch/data/teams/team_page_eligibility.dart';

// 대회 기록과 캘린더는 리그 → 유럽대항전 → 자국 컵 → 잉글랜드 리그컵 순서를 공유해요.
int compareCompetitionDisplayOrder(int firstId, int secondId) {
  final priority =
      _competitionPriority(firstId).compareTo(_competitionPriority(secondId));
  return priority != 0 ? priority : firstId.compareTo(secondId);
}

int _competitionPriority(int competitionId) {
  if (TeamPageEligibility.domesticBigFiveCompetitionIds
      .contains(competitionId)) {
    return 0;
  }
  return switch (competitionId) {
    2 || 5 || 2286 => 1,
    27 => 3,
    _ => 2,
  };
}
