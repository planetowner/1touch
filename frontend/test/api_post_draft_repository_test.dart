import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/posts/api/api_post_draft_repository.dart';
import 'package:onetouch/data/posts/post_draft_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/models/post.dart';

void main() {
  for (final hasDraft in [false, true]) {
    test('preload and entry share memory and disk (hasDraft: $hasDraft)',
        () async {
      final store = MemoryLocalCacheStore();
      var requests = 0;
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      final api = _api((_) {
        requests++;
        started.complete();
        return pending.future;
      });
      final writer = ApiPostDraftRepository(api: api, cacheStore: store);
      final preload = writer.loadAllDrafts();
      final entry = writer.loadDraftsFor(teamId: 6, language: 'ko');
      await started.future;
      expect(requests, 1);
      pending.complete(_response(hasDraft ? [_draft()] : []));
      await preload;
      expect(await entry, hasLength(hasDraft ? 1 : 0));
      expect(await writer.loadDraftsFor(teamId: 9, language: 'ko'), isEmpty);
      expect(await writer.loadDraftsFor(teamId: 6, language: 'en'), isEmpty);
      final reader = ApiPostDraftRepository(api: api, cacheStore: store);
      expect(await reader.restoreCachedDrafts(), hasLength(hasDraft ? 1 : 0));
      expect(await reader.loadDraftsFor(teamId: 6, language: 'ko'),
          hasLength(hasDraft ? 1 : 0));
      expect(requests, 1);
    });
  }

  test('cached drafts expire at their server expiry time', () async {
    final expiry = DateTime.utc(2026, 10, 17);
    final repository = ApiPostDraftRepository(
        api: _api((_) async => _response([_draft(expiresAt: expiry)])));
    await withClock(Clock.fixed(expiry.subtract(const Duration(seconds: 1))),
        () async {
      expect(await repository.loadDraftsFor(teamId: 6, language: 'ko'),
          hasLength(1));
    });
    await withClock(Clock.fixed(expiry), () async {
      expect(
          await repository.loadDraftsFor(teamId: 6, language: 'ko'), isEmpty);
    });
  });

  test('stale drafts stay available while one shared refresh is pending',
      () async {
    final now = DateTime.now().toUtc();
    var requests = 0;
    final pending = Completer<http.Response>();
    final refreshStarted = Completer<void>();
    final repository = ApiPostDraftRepository(api: _api((_) async {
      requests++;
      if (requests == 2) refreshStarted.complete();
      return requests == 1 ? _response([_draft()]) : pending.future;
    }));
    await withClock(Clock.fixed(now), repository.loadAllDrafts);
    await withClock(Clock.fixed(now.add(const Duration(minutes: 2))), () async {
      expect(await repository.loadDraftsFor(teamId: 6, language: 'ko'),
          hasLength(1));
      expect(await repository.loadAllDrafts(), hasLength(1));
      await refreshStarted.future;
      expect(requests, 2);
      final refreshed = repository.refreshDrafts();
      pending.complete(_response([]));
      await refreshed;
      expect(await repository.loadAllDrafts(), isEmpty);
      expect(requests, 2);
    });
  });

  for (final mutation in ['save', 'delete', 'publish']) {
    test('$mutation invalidates every draft page and preserves public caches',
        () async {
      final store = MemoryLocalCacheStore();
      await store.write('public-feed', {'items': []},
          scope: LocalCacheScopes.communityPosts);
      await store.write('profile', {'user_id': 7},
          scope: LocalCacheScopes.authenticatedUser);
      var changed = false;
      final offsets = <int>[];
      final repository = ApiPostDraftRepository(
          api: _api((request) async {
            if (request.method == 'GET') {
              final offset = int.parse(request.url.queryParameters['offset']!);
              offsets.add(offset);
              return _response(changed
                  ? []
                  : List.generate(offset == 0 ? 50 : 1,
                      (index) => _draft(id: offset + index + 1)));
            }
            changed = true;
            if (mutation == 'save') {
              return http.Response(jsonEncode(_draft()), 201);
            }
            return http.Response(
                mutation == 'delete' ? '{"ok":true}' : '{"post_id":41}', 200);
          }),
          cacheStore: store);
      expect(await repository.loadAllDrafts(), hasLength(51));
      switch (mutation) {
        case 'save':
          await repository.saveDraft(CreatePostInput(
              teamId: 6,
              language: 'ko',
              category: PostCategory.general,
              title: 'Draft',
              body: 'Body'));
        case 'delete':
          await repository.deleteDraft(41);
        case 'publish':
          await repository.publishDraft(41);
      }
      expect(await repository.restoreCachedDrafts(), isNull);
      expect(await repository.restoreCachedDrafts(offset: 50), isNull);
      expect(
          await store.read('public-feed',
              scope: LocalCacheScopes.communityPosts),
          isNotNull);
      expect(
          await store.read('profile',
              scope: LocalCacheScopes.authenticatedUser),
          isNotNull);
      expect(await repository.loadAllDrafts(), isEmpty);
      expect(offsets, [0, 50, 0]);
    });
  }

  test('forced refresh bypasses fresh memory for every page', () async {
    var requests = 0;
    final repository = ApiPostDraftRepository(api: _api((request) async {
      requests++;
      final offset = int.parse(request.url.queryParameters['offset']!);
      return _response(List.generate(
          offset == 0 ? 50 : 1, (index) => _draft(id: offset + index)));
    }));
    await repository.loadAllDrafts();
    await repository.loadAllDrafts();
    expect(requests, 2);
    await repository.loadDraftsFor(
        teamId: 6, language: 'ko', forceRefresh: true);
    expect(requests, 4);
  });
}

ApiClient _api(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
        client: MockClient(handler),
        baseUri: Uri.parse('https://example.test/v1/'),
        requestHeaders: () => const {'Authorization': 'Bearer session'});

http.Response _response(List<Map<String, dynamic>> drafts) =>
    http.Response(jsonEncode({'items': drafts}), 200);

Map<String, dynamic> _draft({int id = 41, DateTime? expiresAt}) => {
      'post_id': id,
      'team_id': 6,
      'language': 'ko',
      'category': 'general',
      'title': 'Draft',
      'body': 'Body',
      'attachments': [],
      'expires_at':
          (expiresAt ?? DateTime.now().toUtc().add(const Duration(days: 2)))
              .toIso8601String(),
    };
