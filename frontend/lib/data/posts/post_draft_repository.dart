import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/models/post_draft.dart';

abstract interface class PostDraftRepository {
  Future<List<PostDraft>> loadDrafts({int limit = 50, int offset = 0});
  Future<PostDraft> saveDraft(CreatePostInput input, {int? postId});
  Future<void> deleteDraft(int postId);
  Future<int> publishDraft(int postId);
}
