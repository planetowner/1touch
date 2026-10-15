import 'package:clock/clock.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/models/post_draft.dart';

abstract interface class PostDraftRepository {
  Future<List<PostDraft>> loadDrafts({int limit = 50, int offset = 0});
  Future<PostDraft> saveDraft(CreatePostInput input, {int? postId});
  Future<void> deleteDraft(int postId);
  Future<int> publishDraft(int postId);
}

abstract interface class CachedPostDraftRepository
    implements PostDraftRepository {
  Future<List<PostDraft>?> restoreCachedDrafts(
      {int limit = 50, int offset = 0});
  Future<List<PostDraft>> refreshDrafts({int limit = 50, int offset = 0});
  Future<void> invalidateDraftCaches();
}

extension PostDraftQueries on PostDraftRepository {
  Future<List<PostDraft>> loadDraftsFor({
    required int teamId,
    required String language,
    bool forceRefresh = false,
  }) async {
    final drafts = await loadAllDrafts(forceRefresh: forceRefresh);
    final now = clock.now().toUtc();
    // 기기에 보관한 초안도 서버와 같은 만료 시각까지만 보여줘요.
    return drafts
        .where((draft) =>
            draft.teamId == teamId &&
            draft.language == language &&
            draft.expiresAt.isAfter(now))
        .toList();
  }

  Future<List<PostDraft>> loadAllDrafts({bool forceRefresh = false}) async {
    final drafts = <PostDraft>[];
    var offset = 0;
    while (true) {
      final page = await (forceRefresh && this is CachedPostDraftRepository
          ? (this as CachedPostDraftRepository)
              .refreshDrafts(limit: 50, offset: offset)
          : loadDrafts(limit: 50, offset: offset));
      drafts.addAll(page);
      if (page.length < 50) return drafts;
      offset += page.length;
    }
  }
}
