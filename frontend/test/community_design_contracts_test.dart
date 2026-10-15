import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/comm_pages/profile_activity_screen.dart';
import 'package:onetouch/data/posts/api/api_post_draft_repository.dart';
import 'package:onetouch/data/injuries/api/api_team_injury_repository.dart';
import 'package:onetouch/data/transfers/api/api_transfer_repository.dart';
import 'package:onetouch/features/media/selected_team_media_preloader.dart';
import 'package:onetouch/data/posts/mock/mock_post_repository.dart';
import 'package:onetouch/data/posts/post_draft_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/data/post_comments/api/api_post_comment_repository.dart';
import 'package:onetouch/data/profile/api/api_community_profile_repository.dart';
import 'package:onetouch/features/community/community_feed_widgets.dart';
import 'package:onetouch/features/community/community_attachment_viewer.dart';
import 'package:onetouch/features/community/post_detail_content.dart';
import 'package:onetouch/features/community/post_composer_widgets.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/post_comment.dart';
import 'package:onetouch/models/post_draft.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/screens/CommunityScreen_utils/add_post.dart';
import 'package:onetouch/screens/community_screen.dart';
import 'support/app_catalog.dart';
import 'support/stub_community_repository.dart';
import 'support/stub_profile_activity_repository.dart';

ApiClient api(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
        client: MockClient(handler),
        baseUri: Uri.parse('https://example.com/v1/'),
        requestHeaders: () => {'Authorization': 'Bearer test-session'});

void main() {
  setUpAppCatalog(favoriteTeamId: 6);
  test('draft save retains ownership context and publish uses the saved ID',
      () async {
    final requests = <http.Request>[];
    final repository = ApiPostDraftRepository(api: api((request) async {
      requests.add(request);
      expect(request.headers['Authorization'], 'Bearer test-session');
      if (request.method == 'DELETE') {
        return http.Response('{"ok":true}', 200);
      }
      if (request.url.path.endsWith('/publish')) {
        return http.Response('{"post_id":41}', 200);
      }
      return http.Response(
          jsonEncode(request.method == 'GET'
              ? {
                  'items': [_draftJson]
                }
              : _draftJson),
          request.method == 'POST' ? 201 : 200);
    }));
    final drafts = await repository.loadDrafts();
    expect(drafts.single.attachments.single.mediaUrl,
        'https://example.com/v1/attachments/2/content');
    final input = CreatePostInput(
        teamId: 6,
        language: 'ko',
        category: PostCategory.analysis,
        title: '',
        body: '',
        attachmentIds: [2]);
    await repository.saveDraft(input);
    await repository.saveDraft(input, postId: 41);
    expect(await repository.publishDraft(41), 41);
    await repository.deleteDraft(41);
    expect(jsonDecode(requests[1].body), {
      'team_id': 6,
      'language': 'ko',
      'category': 'analysis',
      'title': '',
      'body': '',
      'attachment_ids': [2]
    });
    expect(jsonDecode(requests[2].body), {
      'category': 'analysis',
      'title': '',
      'body': '',
      'attachment_ids': [2]
    });
    expect(requests[2].url.path, '/v1/post-drafts/41');
    expect(requests[3].url.path, '/v1/post-drafts/41/publish');
    expect(requests[4].method, 'DELETE');
    expect(requests[4].url.path, '/v1/post-drafts/41');
  });

  test('draft query checks every page and filters by team and language',
      () async {
    final offsets = <int>[];
    final repository = ApiPostDraftRepository(api: api((request) async {
      final offset = int.parse(request.url.queryParameters['offset']!);
      offsets.add(offset);
      return http.Response(
          jsonEncode({
            'items': offset == 0
                ? List.generate(50, (index) => {..._draftJson, 'team_id': 9})
                : [
                    {..._draftJson, 'language': 'ja'},
                    _draftJson
                  ]
          }),
          200);
    }));
    final drafts = await repository.loadDraftsFor(teamId: 6, language: 'en');
    expect(drafts.single.postId, 41);
    expect(offsets, [0, 50]);
  });

  test('comment like, unlike and report use authenticated comment endpoints',
      () async {
    final calls = <String>[];
    var invalidations = 0;
    final repository = ApiPostCommentRepository(api: api((request) async {
      calls.add('${request.method} ${request.url.path}');
      expect(request.headers['Authorization'], 'Bearer test-session');
      if (request.method == 'POST') {
        expect(jsonDecode(request.body), {'reason': 'Spam'});
      }
      return http.Response('{"ok":true}', 200);
    }), onMutation: () async {
      invalidations++;
    });
    await repository.setCommentLiked(commentId: 12, liked: true);
    await repository.setCommentLiked(commentId: 12, liked: false);
    await repository.reportComment(commentId: 12, reason: 'Spam');
    expect(calls, [
      'PUT /v1/comments/12/like',
      'DELETE /v1/comments/12/like',
      'POST /v1/comments/12/report'
    ]);
    expect(invalidations, 2);
  });

  testWidgets(
      'a saved draft resumes with attachments and publishes without creating another post',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final drafts = _Drafts();
    await tester.pumpWidget(MaterialApp(
        theme: darktheme,
        home: AddPost(
            initialDrafts: [drafts.draft],
            teamId: 6,
            postRepository: MockPostRepository(),
            draftRepository: drafts)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('community-resume-draft')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved title'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(
                find.byKey(const ValueKey('community-post-title-input')))
            .controller!
            .text,
        'Saved title');
    expect(find.byKey(const ValueKey('community-existing-attachment-remove-0')),
        findsOneWidget);
    await tester
        .ensureVisible(find.byKey(const ValueKey('community-post-submit')));
    await tester.tap(find.byKey(const ValueKey('community-post-submit')));
    await tester.pumpAndSettle();
    expect(drafts.savedId, 41);
    expect(drafts.saved?.attachmentIds, [2]);
    expect(drafts.publishedId, 41);
  });

  for (final hasDrafts in [false, true]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets(
          'composer has its final layout on the first frame '
          '(hasDrafts: $hasDrafts, textScale: $textScale)', (tester) async {
        tester.view.physicalSize = const Size(320, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final drafts = _Drafts(language: 'ko');
        await tester.pumpWidget(MaterialApp(
            theme: darktheme,
            locale: const Locale('ko'),
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationDelegates,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!),
            home: AddPost(
                initialDrafts: hasDrafts ? [drafts.draft] : [],
                teamId: 6,
                draftRepository: drafts)));
        final button = find.byKey(const ValueKey('community-resume-draft'));
        final title = find.byKey(const ValueKey('community-post-title-input'));
        final body = find.byKey(const ValueKey('community-post-body-input'));
        final titlePosition = tester.getTopLeft(title);
        final bodyPosition = tester.getTopLeft(body);
        expect(button, hasDrafts ? findsOneWidget : findsNothing);
        expect(
            tester.getTopLeft(find.byType(PostComposerFields)).dy,
            tester.getBottomLeft(find.byType(AppBar)).dy +
                24 +
                (hasDrafts ? tester.getSize(button).height : 0));
        await tester.pumpAndSettle();

        expect(button, hasDrafts ? findsOneWidget : findsNothing);
        expect(drafts.loadCalls, 0);
        expect(tester.getTopLeft(title), titlePosition);
        expect(tester.getTopLeft(body), bodyPosition);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('draft loading errors retry before opening the composer',
      (tester) async {
    final drafts = _Drafts(loadFailures: 2);
    await tester.pumpWidget(_communityApp(drafts));
    await tester.pumpAndSettle();
    expect(drafts.loadCalls, 1);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    const message = 'Unable to load drafts. Tap to retry.';
    expect(
        find.descendant(
            of: find.byType(SnackBar), matching: find.text(message)),
        findsOneWidget);
    expect(find.byType(AddPost), findsNothing);
    expect(drafts.loadCalls, 2);

    await tester.tap(find.text(message));
    await tester.pumpAndSettle();
    expect(drafts.loadCalls, 3);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(AddPost), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('community-resume-draft')));
    await tester.pumpAndSettle();
    expect(find.text('Saved title'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final hasDrafts in [false, true]) {
    for (final loadBeforeTap in [false, true]) {
      testWidgets(
          'community opens with known drafts '
          '(hasDrafts: $hasDrafts, loadBeforeTap: $loadBeforeTap)',
          (tester) async {
        final pendingLoad = Completer<List<PostDraft>>();
        final drafts = _Drafts(pendingLoad: pendingLoad.future);
        await tester.pumpWidget(_communityApp(drafts));
        await tester.pumpAndSettle();
        expect(drafts.loadCalls, 1);
        expect(find.byType(AddPost), findsNothing);
        if (loadBeforeTap) {
          pendingLoad.complete(hasDrafts ? [drafts.draft] : []);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();
        if (!loadBeforeTap) {
          expect(find.byType(AddPost), findsNothing);
          expect(
              tester
                  .widget<FloatingActionButton>(
                      find.byType(FloatingActionButton))
                  .onPressed,
              isNull);
          pendingLoad.complete(hasDrafts ? [drafts.draft] : []);
          await tester.pump();
        }
        await tester.pump();
        expect(find.byType(AddPost), findsOneWidget);
        expect(find.byKey(const ValueKey('community-resume-draft')),
            hasDrafts ? findsOneWidget : findsNothing);
        expect(find.byType(PostComposerFields), findsOneWidget);
        expect(drafts.loadCalls, 1);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final initiallyHasDraft in [false, true]) {
    testWidgets(
        'background cache refresh keeps the open composer layout (hasDraft: $initiallyHasDraft)',
        (tester) async {
      final drafts = _Drafts(hasInitialDraft: initiallyHasDraft);
      await tester.pumpWidget(_communityApp(drafts));
      await tester.pumpAndSettle();
      final pending = Completer<List<PostDraft>>();
      drafts.pendingLoad = pending.future;
      final refresh = drafts.cached.refreshDrafts();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      final fields = find.byType(PostComposerFields);
      final position = tester.getTopLeft(fields);
      final button = find.byKey(const ValueKey('community-resume-draft'));
      expect(button, initiallyHasDraft ? findsOneWidget : findsNothing);
      pending.complete(initiallyHasDraft ? [] : [drafts.draft]);
      await tester.pump();
      await refresh;
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(fields), position);
      expect(button, initiallyHasDraft ? findsOneWidget : findsNothing);
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump();
      expect(button, initiallyHasDraft ? findsNothing : findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reopening after saving shows the draft on the first frame',
      (tester) async {
    final drafts = _Drafts(hasInitialDraft: false);
    await tester.pumpWidget(_communityApp(drafts));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community-resume-draft')), findsNothing);
    await tester.enterText(
        find.byKey(const ValueKey('community-post-title-input')), 'New draft');
    await tester
        .ensureVisible(find.byKey(const ValueKey('community-draft-save')));
    await tester.tap(find.byKey(const ValueKey('community-draft-save')));
    await tester.pumpAndSettle();
    expect(drafts.loadCalls, 2);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump();
    expect(
        find.byKey(const ValueKey('community-resume-draft')), findsOneWidget);
    expect(drafts.loadCalls, 2);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('community-resume-draft')));
    await tester.pumpAndSettle();
    expect(find.text('New draft'), findsOneWidget);
  });

  for (final publish in [false, true]) {
    testWidgets(
        'reopening after ${publish ? 'publishing' : 'deleting'} has no draft gap',
        (tester) async {
      final drafts = _Drafts();
      await tester.pumpWidget(_communityApp(drafts));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('community-resume-draft')));
      await tester.pumpAndSettle();
      if (publish) {
        await tester.tap(find.text('Saved title'));
        await tester.pumpAndSettle();
        await tester
            .ensureVisible(find.byKey(const ValueKey('community-post-submit')));
        await tester.tap(find.byKey(const ValueKey('community-post-submit')));
      } else {
        await tester
            .tap(find.byKey(const ValueKey('community-draft-delete-41')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('community-drafts-close')));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(IconButton).first);
      }
      await tester.pumpAndSettle();
      expect(find.byType(AddPost), findsNothing);
      expect(drafts.loadCalls, 2);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('community-resume-draft')), findsNothing);
      expect(tester.getTopLeft(find.byType(PostComposerFields)).dy,
          tester.getBottomLeft(find.byType(AppBar)).dy + 24);
      expect(tester.takeException(), isNull);
    });
  }

  for (final changeTeam in [false, true]) {
    testWidgets(
        'changing ${changeTeam ? 'team' : 'language'} filters the same cached draft preload',
        (tester) async {
      final pendingLoad = Completer<List<PostDraft>>();
      final drafts = _Drafts(pendingLoad: pendingLoad.future);
      await tester.pumpWidget(_communityApp(drafts));
      await tester.pumpAndSettle();
      expect(drafts.loadCalls, 1);
      if (changeTeam) {
        currentUserPreferences.applyServerSelection(
            const UserTeamPreferences(favoriteTeamId: 9, followedTeamIds: []));
      }
      await tester.pumpWidget(_communityApp(drafts,
          teamId: changeTeam ? 9 : 6, language: changeTeam ? 'en' : 'ko'));
      await tester.pumpAndSettle();
      expect(drafts.loadCalls, 1);
      pendingLoad.complete([drafts.draft]);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(AddPost), findsOneWidget);
      expect(
          find.byKey(const ValueKey('community-resume-draft')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final systemBack in [false, true]) {
    testWidgets(
        'leaving a nonempty composer with ${systemBack ? 'system back' : 'back button'} saves before popping',
        (tester) async {
      final drafts = _Drafts();
      bool? result;
      await tester.pumpWidget(MaterialApp(
          theme: darktheme,
          home: Scaffold(body: Builder(builder: (context) {
            return TextButton(
                onPressed: () async {
                  result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AddPost(
                              initialDrafts: [drafts.draft],
                              teamId: 6,
                              postRepository: MockPostRepository(),
                              draftRepository: drafts)));
                },
                child: const Text('Open composer'));
          }))));
      await tester.tap(find.text('Open composer'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('community-post-title-input')), 'My draft');
      await tester.pump();
      if (systemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byType(IconButton).first);
      }
      await tester.pumpAndSettle();
      expect(drafts.saved?.title, 'My draft');
      expect(result, false);
      expect(find.text('Open composer'), findsOneWidget);
    });
  }

  testWidgets('draft list remains available while composing and after resume',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final drafts = _Drafts();
    await tester.pumpWidget(MaterialApp(
        theme: darktheme,
        home: AddPost(
            initialDrafts: [drafts.draft],
            teamId: 6,
            postRepository: MockPostRepository(),
            draftRepository: drafts)));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('community-post-title-input')),
        'New unfinished post');
    expect(
        find.byKey(const ValueKey('community-resume-draft')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('community-resume-draft')));
    await tester.pumpAndSettle();
    expect(drafts.saved?.title, 'New unfinished post');
    expect(find.text('New unfinished post'), findsWidgets);
    await tester.tap(find.text('Saved title'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('community-resume-draft')), findsOneWidget);
  });

  for (final size in [const Size(320, 568), const Size(393, 852)]) {
    testWidgets('draft deletion shows the notice at ${size.width}px',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final drafts = _Drafts();
      await tester.pumpWidget(MaterialApp(
          theme: darktheme,
          home: AddPost(
              initialDrafts: [drafts.draft],
              teamId: 6,
              postRepository: MockPostRepository(),
              draftRepository: drafts)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('community-resume-draft')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('community-draft-delete-41')));
      await tester.pump();
      expect(drafts.deletedId, 41);
      expect(find.text('Deleted draft.'), findsOneWidget);
      expect(find.text('Drafts'), findsOneWidget);
      expect(find.text('Saved title'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('community-drafts-close')));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('community-resume-draft')), findsNothing);
      expect(tester.getTopLeft(find.byType(PostComposerFields)).dy,
          tester.getBottomLeft(find.byType(AppBar)).dy + 24);
    });
  }

  testWidgets('multiple media thumbnail and count badge open the post',
      (tester) async {
    var opens = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body:
                CommunityPostList(posts: [_post], onPostTap: (_) => opens++))));
    await tester.pumpAndSettle();
    expect(find.text('+2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('community-post-1-media-open')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityAttachmentViewer), findsNothing);
    expect(opens, 1);
    await tester.tap(find.text('+2'));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityAttachmentViewer), findsNothing);
    expect(opens, 2);
  });

  testWidgets(
      'deleted comments retain author and time while active comments expose like and report',
      (tester) async {
    var liked = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CustomScrollView(slivers: [
      PostDetailContent(
          post: _post.copyWith(
              state: PostState.deleted, title: '', body: '', attachments: []),
          liked: false,
          likeCount: 2,
          commentCount: 1,
          onLike: null,
          communityRepository: const StubCommunityRepository(),
          comments: [
            _comment(PostCommentState.deleted, 1),
            _comment(PostCommentState.active, 2)
          ],
          commentsLoading: false,
          commentsError: null,
          onRetryComments: () {},
          onReply: null,
          onReport: null,
          currentUserId: 1,
          onLikeComment: (_) => liked++,
          onReportComment: (_, __) async {}),
    ]))));
    await tester.pumpAndSettle();
    expect(find.text('This post was deleted.'), findsOneWidget);
    await tester
        .ensureVisible(find.byKey(const ValueKey('community-comment-1')));
    expect(find.text('This comment was deleted.'), findsOneWidget);
    expect(find.text('Member'), findsWidgets);
    expect(
        find.byKey(const ValueKey('community-comment-like-1')), findsNothing);
    final like = find.byKey(const ValueKey('community-comment-like-2'));
    await tester.ensureVisible(like);
    await tester.tap(like);
    expect(liked, 1);
    await tester.tap(find.byKey(const ValueKey('community-comment-menu-2')));
    await tester.pumpAndSettle();
    expect(find.text('Copy Text'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
  });

  for (final theme in [whitetheme, darktheme]) {
    for (final size in [const Size(320, 568), const Size(393, 852)]) {
      testWidgets(
          'another member follow button uses ${theme.brightness} '
          'colors at ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final calls = <String>[];
        final publicProfiles =
            ApiCommunityProfileRepository(api: api((request) async {
          calls.add(request.method);
          return http.Response(
              request.method == 'GET'
                  ? '{"user_id":8,"username":"member","display_name":"Member","avatar_url":null,"is_self":false,"following":false}'
                  : '{"ok":true}',
              200);
        }));
        await tester.pumpWidget(MaterialApp(
            theme: theme,
            home: ProfileActivityScreen(
                userId: 8,
                repository: const StubProfileActivityRepository(),
                publicProfileRepository: publicProfiles)));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('profile-activity-camera')),
            findsNothing);
        expect(find.text('FOLLOW'), findsOneWidget);
        final button = find.byKey(const ValueKey('profile-activity-follow'));
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('FOLLOWING'), findsOneWidget);
        final filledButton = tester.widget<FilledButton>(button);
        final light = theme.brightness == Brightness.light;
        expect(filledButton.style!.backgroundColor!.resolve({}),
            light ? AppPalette.lightGrey : AppPalette.lightModeDarkGrey);
        expect(filledButton.style!.foregroundColor!.resolve({}),
            light ? AppPalette.white : AppPalette.black);
        expect(tester.takeException(), isNull);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(calls, ['GET', 'PUT', 'DELETE']);
      });
    }
  }
}

final _draftJson = {
  'post_id': 41,
  'team_id': 6,
  'language': 'en',
  'category': 'general',
  'title': 'Saved title',
  'body': 'Saved body',
  'expires_at':
      DateTime.now().toUtc().add(const Duration(days: 2)).toIso8601String(),
  'attachments': [
    {
      'attachment_id': 2,
      'position': 0,
      'link_url': null,
      'media_url': '/v1/attachments/2/content',
      'preview_url': null,
      'content_type': 'image/png',
      'byte_size': 24
    }
  ]
};
final _post = Post(
    postId: 1,
    teamId: 6,
    language: 'en',
    userId: 8,
    category: PostCategory.general,
    title: 'Post title',
    body: 'Body text',
    createdAt: '2026-10-01T00:00:00Z',
    displayName: 'Member',
    attachments: [
      for (var id = 1; id <= 3; id++)
        PostAttachment(
            attachmentId: id,
            position: id - 1,
            mediaUrl: 'https://example.com/$id.png',
            contentType: 'image/png')
    ]);
PostComment _comment(PostCommentState state, int id) => PostComment(
    commentId: id,
    postId: 1,
    userId: 8,
    replyToId: null,
    body: state == PostCommentState.deleted ? '' : 'Comment body',
    createdAt: '2026-10-01T00:00:00Z',
    editedAt: null,
    state: state,
    username: 'member',
    displayName: 'Member',
    avatarUrl: null,
    authorDeleted: false,
    likeCount: 2,
    liked: false);

Widget _communityApp(_Drafts drafts,
        {int teamId = 6, String language = 'en'}) =>
    MaterialApp(
        theme: darktheme,
        locale: Locale(language),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: SelectedTeamMediaPreloader(
            teamId: teamId,
            postRepository: drafts.posts,
            draftRepository: drafts.cached,
            injuryRepository: drafts.injuries,
            transferRepository: drafts.transfers,
            child: Community(
                teamId: teamId,
                postRepository: drafts.posts,
                communityRepository: const StubCommunityRepository(),
                draftRepository: drafts.cached)));

class _Drafts implements PostDraftRepository {
  _Drafts(
      {this.loadFailures = 0,
      this.pendingLoad,
      this.hasInitialDraft = true,
      this.language = 'en'});
  final posts = MockPostRepository(posts: const []);
  late final client = api((request) async {
    final segments = request.url.pathSegments;
    if (!segments.contains('post-drafts')) return http.Response('', 503);
    Object response;
    var status = 200;
    if (request.method == 'GET') {
      try {
        response = {'items': (await loadDrafts()).map(_draftPayload).toList()};
      } on Object {
        return http.Response('', 503);
      }
    } else if (segments.last == 'publish') {
      response = {
        'post_id': await publishDraft(int.parse(segments[segments.length - 2]))
      };
    } else if (request.method == 'DELETE') {
      await deleteDraft(int.parse(segments.last));
      response = {'ok': true};
    } else {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final postId = request.method == 'PUT' ? int.parse(segments.last) : null;
      final result = await saveDraft(
          CreatePostInput(
            teamId: body['team_id'] as int? ?? draft.teamId,
            language: body['language'] as String? ?? draft.language,
            category: PostCategory.values.byName(body['category'] as String),
            title: body['title'] as String,
            body: body['body'] as String,
            attachmentIds: (body['attachment_ids'] as List).cast<int>(),
          ),
          postId: postId);
      response = _draftPayload(result);
      if (postId == null) status = 201;
    }
    return http.Response(jsonEncode(response), status);
  });
  late final cached = ApiPostDraftRepository(api: client);
  late final injuries = ApiTeamInjuryRepository(api: client);
  late final transfers = ApiTransferRepository(api: client);

  Future<List<PostDraft>>? pendingLoad;
  final bool hasInitialDraft;
  final String language;
  int loadFailures;
  int loadCalls = 0;
  CreatePostInput? saved;
  int? savedId, publishedId, deletedId;
  final Map<int, PostDraft> _savedDrafts = {};
  late final draft = PostDraft(
      postId: 41,
      teamId: 6,
      language: language,
      category: PostCategory.general,
      title: 'Saved title',
      body: 'Saved body',
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 2)),
      attachments: const [
        PostAttachment(
            attachmentId: 2,
            position: 0,
            mediaUrl: 'https://example.com/image.png',
            contentType: 'image/png',
            byteSize: 24)
      ]);
  @override
  Future<List<PostDraft>> loadDrafts({int limit = 50, int offset = 0}) async {
    loadCalls++;
    final pending = pendingLoad;
    if (pending != null) {
      pendingLoad = null;
      return pending;
    }
    if (loadFailures > 0) {
      loadFailures--;
      throw StateError('Draft load failed');
    }
    return [
      if (hasInitialDraft && deletedId != 41 && publishedId != 41)
        _savedDrafts[41] ?? draft,
      if (_savedDrafts[42] != null) _savedDrafts[42]!
    ];
  }

  @override
  Future<PostDraft> saveDraft(CreatePostInput input, {int? postId}) async {
    saved = input;
    savedId = postId;
    final id = postId ?? 42;
    final result = PostDraft(
        postId: id,
        teamId: input.teamId,
        language: input.language,
        category: input.category,
        title: input.title,
        body: input.body,
        attachments: id == 41 ? draft.attachments : const [],
        expiresAt: draft.expiresAt);
    _savedDrafts[id] = result;
    return result;
  }

  @override
  Future<int> publishDraft(int postId) async {
    publishedId = postId;
    _savedDrafts.remove(postId);
    return postId;
  }

  @override
  Future<void> deleteDraft(int postId) async {
    deletedId = postId;
    _savedDrafts.remove(postId);
  }
}

Map<String, dynamic> _draftPayload(PostDraft draft) => {
      'post_id': draft.postId,
      'team_id': draft.teamId,
      'language': draft.language,
      'category': draft.category.name,
      'title': draft.title,
      'body': draft.body,
      'expires_at': draft.expiresAt.toIso8601String(),
      'attachments': [
        for (final attachment in draft.attachments)
          {
            'attachment_id': attachment.attachmentId,
            'position': attachment.position,
            'link_url': attachment.linkUrl,
            'media_url': attachment.mediaUrl,
            'preview_url': attachment.previewUrl,
            'content_type': attachment.contentType,
            'byte_size': attachment.byteSize,
          }
      ],
    };
