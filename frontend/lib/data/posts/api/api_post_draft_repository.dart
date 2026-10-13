import 'dart:convert';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/api_json.dart' as api_json;
import 'package:onetouch/data/posts/api/api_post_mapper.dart';
import 'package:onetouch/data/posts/api/api_post_response.dart';
import 'package:onetouch/data/posts/post_draft_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/post_draft.dart';

class ApiPostDraftRepository implements PostDraftRepository {
  ApiPostDraftRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;
  @override
  Future<List<PostDraft>> loadDrafts({int limit = 50, int offset = 0}) async {
    final response = await _api.get(_api.baseUri
        .resolve('post-drafts')
        .replace(queryParameters: {'limit': '$limit', 'offset': '$offset'}));
    final json = _api.decodeJson<Map<String, dynamic>>(response);
    return (json['items'] as List)
        .map((item) => _parse(item as Map<String, dynamic>))
        .toList();
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
    return _parse(_api.decodeJson<Map<String, dynamic>>(response,
        expectedStatus: postId == null ? 201 : 200));
  }

  @override
  Future<int> publishDraft(int postId) async {
    final response =
        await _api.post(_api.baseUri.resolve('post-drafts/$postId/publish'));
    return api_json.requiredInt(
        _api.decodeJson<Map<String, dynamic>>(response), 'post_id');
  }

  @override
  Future<void> deleteDraft(int postId) async {
    final response =
        await _api.delete(_api.baseUri.resolve('post-drafts/$postId'));
    final json = _api.decodeJson<Map<String, dynamic>>(response);
    if (json['ok'] != true) {
      throw const FormatException('Expected draft deletion to return ok=true.');
    }
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
