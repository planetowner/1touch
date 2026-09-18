import 'package:onetouch/data/community/community_repository.dart';
import 'package:onetouch/models/community_rules.dart';

class StubCommunityRepository implements CommunityRepository {
  const StubCommunityRepository({this.followerCount = 0});

  final int followerCount;

  @override
  Future<int> loadFollowerCount({required int teamId}) async => followerCount;

  @override
  Future<CommunityRules> loadRules({
    required int teamId,
    required CommunityLanguage language,
  }) async =>
      CommunityRules(
        language: language,
        title: 'Community Ground Rules',
        items: const [
          CommunityRule(
            title: 'Talk football, not trash.',
            body: 'Disagree? Cool. Disrespect? Not here.',
          ),
          CommunityRule(
            title: 'No player hate.',
            body: 'Critique the play, not the person.',
          ),
          CommunityRule(
            title: 'Respect every team.',
            body: 'Rivalries are fun — as long as they stay respectful.',
          ),
          CommunityRule(
            title: 'Keep it clean.',
            body: 'No spam, slurs, or shady links.',
          ),
          CommunityRule(
            title: 'Bring the vibes.',
            body: 'Celebrate the game and enjoy the banter.',
          ),
        ],
        confirmLabel: 'I UNDERSTAND!',
      );
}
