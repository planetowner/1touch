import 'dart:convert';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/local/repository_cache.dart';
import 'package:onetouch/core/api_json.dart' as api_json;
import 'package:onetouch/data/posts/api/api_post_mapper.dart';
import 'package:onetouch/data/posts/api/api_post_response.dart';
import 'package:onetouch/data/posts/post_draft_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/post_draft.dart';

class ApiPostDraftRepository implements CachedPostDraftRepository {
  ApiPostDraftRepository({required ApiClient api, LocalCacheStore? cacheStore})
      : _api = api,
        _cacheStore = cacheStore;
  final ApiClient _api;
  final LocalCacheStore? _cacheStore;
  late final _drafts =
      RepositoryCache<({int limit, int offset}), List<PostDraft>>(
    fetch: (page) => _fetchDrafts(page.limit, page.offset),
    decode: (json, _) => List.unmodifiable((json['items'] as List)
        .map((item) => _parse(item as Map<String, dynamic>))),
    keyOf: (page) => LocalCacheKeys.postDrafts(page.limit, page.offset),
    tier: CacheTier.shortLived,
    store: _cacheStore,
    scope: LocalCacheScopes.postDrafts,
  );
  @override
  Future<List<PostDraft>> loadDrafts({int limit = 50, int offset = 0}) =>
      _drafts.load((limit: limit, offset: offset));

  @override
  Future<List<PostDraft>?> restoreCachedDrafts(
          {int limit = 50, int offset = 0}) =>
      _drafts.restore((limit: limit, offset: offset));

  @override
  Future<List<PostDraft>> refreshDrafts({int limit = 50, int offset = 0}) =>
      _drafts.refresh((limit: limit, offset: offset));

  @override
  Future<void> invalidateDraftCaches() => _drafts.invalidate();

  Future<Map<String, dynamic>> _fetchDrafts(int limit, int offset) async {
    final response = await _api.get(_api.baseUri
        .resolve('post-drafts')
        .replace(queryParameters: {'limit': '$limit', 'offset': '$offset'}));
    return _api.decodeJson<Map<String, dynamic>>(response);
  }

  @override
  Future<PostDraft> saveDraft(CreatePostInput input, {int? postId}) async {
    final payload = {
      'category': input.category.name,
      'title': input.title,
      'body': input.body,
      'attachment_ids': input.attachmentIds,
      if (postId == null) ...{
        'team_id': input.teamId,
        'language': input.language
      }
    };
    const headers = {'Content-Type': 'application/json'};
    final response = postId == null
        ? await _api.post(_api.baseUri.resolve('post-drafts'),
            headers: headers, body: jsonEncode(payload))
        : await _api.put(_api.baseUri.resolve('post-drafts/$postId'),
            headers: headers, body: jsonEncode(payload));
    final draft = _parse(_api.decodeJson<Map<String, dynamic>>(response,
        expectedStatus: postId == null ? 201 : 200));
    await invalidateDraftCaches();
    return draft;
  }

  @override
  Future<int> publishDraft(int postId) async {
    final response =
        await _api.post(_api.baseUri.resolve('post-drafts/$postId/publish'));
    final publishedId = api_json.requiredInt(
        _api.decodeJson<Map<String, dynamic>>(response), 'post_id');
    await invalidateDraftCaches();
    return publishedId;
  }

  @override
  Future<void> deleteDraft(int postId) async {
    final response =
        await _api.delete(_api.baseUri.resolve('post-drafts/$postId'));
    final json = _api.decodeJson<Map<String, dynamic>>(response);
    if (json['ok'] != true) {
      throw const FormatException('Expected draft deletion to return ok=true.');
    }
    await invalidateDraftCaches();
  }

  PostDraft _parse(Map<String, dynamic> json) => PostDraft(
        postId: api_json.requiredInt(json, 'post_id'),
        teamId: api_json.requiredInt(json, 'team_id'),
        language: api_json.requiredString(json, 'language'),
        title: api_json.requiredString(json, 'title'),
        body: api_json.requiredString(json, 'body'),
        category:
            PostCategory.tryParse(api_json.requiredString(json, 'category')) ??
                (throw const FormatException('Unknown draft category')),
        expiresAt: DateTime.parse(api_json.requiredString(json, 'expires_at')),
        attachments: (json['attachments'] as List)
            .map((a) => postAttachmentFromApiResponse(
                ApiPostAttachmentResponse.fromJson(a as Map<String, dynamic>),
                apiBaseUri: _api.baseUri))
            .toList(),
      );
}
