import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cross_file/cross_file.dart';
import 'package:onetouch/comm_pages/Profile_settings/InfoEdit.dart';
import 'package:onetouch/data/profile/profile_avatar_repository.dart';
import 'package:onetouch/models/current_user_profile.dart';
import 'package:onetouch/features/media/avatar_image_cache.dart';

void main() {
  const actionChannel = MethodChannel('onetouch/action_sheet');
  late _AvatarCacheManager cache;
  final menuCalls = <MethodCall>[];
  String? menuChoice;
  setUp(() {
    cache = _AvatarCacheManager();
    AvatarImageCache.manager = cache;
    menuCalls.clear();
    menuChoice = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(actionChannel, (call) async {
      menuCalls.add(call);
      return menuChoice;
    });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(actionChannel, null);
    await AvatarImageCache.clear();
  });

  testWidgets('uses the compact profile editor layout', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: _EditProfileHost(
          repository: _RecordingAvatarRepository(),
          profile: _profile(),
          pickAvatar: () async => null,
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    final avatarRect = tester.getRect(find.byType(CircleAvatar));
    final cameraRect = tester.getRect(
      find.byKey(const ValueKey('profile-avatar-action')),
    );
    final usernameField = tester.widget<TextField>(
      find.byKey(const ValueKey('profile-username-field')),
    );
    final fieldFinders = [
      find.byKey(const ValueKey('profile-display-name-field')),
      find.byKey(const ValueKey('profile-username-field')),
      find.byKey(const ValueKey('profile-email-field')),
    ];

    expect(cameraRect.size, const Size.square(48));
    expect(cameraRect.right, avatarRect.right + 4.5);
    expect(cameraRect.bottom, avatarRect.bottom + 4);
    expect(usernameField.textAlign, TextAlign.right);
    expect(usernameField.decoration?.filled, isFalse);
    expect(find.byKey(const ValueKey('profile-password-field')), findsNothing);
    expect(
      fieldFinders.map(tester.getTopRight).map((point) => point.dx).toSet(),
      hasLength(1),
    );
    expect(find.text('UPDATE INFO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile editor rejects invalid IDs and nicknames before saving',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: _EditProfileHost(
        repository: _RecordingAvatarRepository(),
        profile: _profile(),
        pickAvatar: () async => null,
      ),
    ));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    final username = find.byKey(const ValueKey('profile-username-field'));
    final nickname = find.byKey(const ValueKey('profile-display-name-field'));
    final update = find.byKey(const ValueKey('profile-update-button'));
    await tester.enterText(username, 'june..kim');
    await tester.ensureVisible(update);
    await tester.tap(update);
    await tester.pump();
    expect(find.text("Periods can't be first, last, or consecutive."),
        findsOneWidget);

    await tester.enterText(username, 'june.kim');
    await tester.enterText(nickname, 'June_Kim');
    await tester.ensureVisible(update);
    await tester.tap(update);
    await tester.pump();
    expect(
        find.text('Use only Korean syllables, English letters, and numbers.'),
        findsOneWidget);
    expect(find.text('RESULT true'), findsNothing);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final hasPhoto in [false, true]) {
      testWidgets('$platform opens native actions; existing photo: $hasPhoto',
          (tester) async {
        final repository = _RecordingAvatarRepository();
        var pickerCalls = 0;
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(platform: platform, brightness: Brightness.dark),
          home: _EditProfileHost(
            repository: repository,
            profile: _profile(
                avatarUri: hasPhoto
                    ? Uri.parse('https://api.example/users/1/avatar')
                    : null),
            pickAvatar: () async {
              pickerCalls++;
              return null;
            },
          ),
        ));
        await tester.tap(find.text('OPEN'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('profile-avatar-action')));
        await tester.pumpAndSettle();

        expect(menuCalls.single.method, 'show');
        final args = menuCalls.single.arguments as Map;
        expect(args['dark'], true);
        expect(args['cancel'], 'Cancel');
        expect(args['actions'], [
          {
            'id': 'choosePhoto',
            'title': platform == TargetPlatform.iOS
                ? 'Choose from Photos'
                : 'Choose from Gallery',
            'destructive': false,
          },
          if (hasPhoto)
            {'id': 'removePhoto', 'title': 'Remove Photo', 'destructive': true},
        ]);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(CupertinoActionSheet), findsNothing);
        // 네이티브 메뉴의 취소는 사진 선택이나 서버 변경으로 이어지지 않아요.
        expect(pickerCalls, 0);
        expect(repository.uploadedBytes, isNull);
        expect(repository.deleteCalls, 0);
        expect(find.byType(EditProfileScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('chooses and uploads a profile photo', (tester) async {
    final repository = _RecordingAvatarRepository();
    menuChoice = 'choosePhoto';

    await tester.pumpWidget(
      MaterialApp(
        home: _EditProfileHost(
          repository: repository,
          profile: _profile(),
          pickAvatar: () async => XFile.fromData(
            Uint8List.fromList([1, 2, 3]),
            name: 'avatar.png',
            mimeType: 'image/png',
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-avatar-action')));
    await tester.pumpAndSettle();

    expect(repository.uploadedBytes, [1, 2, 3]);
    expect(repository.uploadedFilename, 'profile-avatar');
    expect(cache.removedKeys, hasLength(1));
    expect(find.text('RESULT true'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removes an existing profile photo', (tester) async {
    final repository = _RecordingAvatarRepository();
    menuChoice = 'removePhoto';

    await tester.pumpWidget(
      MaterialApp(
        home: _EditProfileHost(
          repository: repository,
          profile: _profile(
            avatarUri: Uri.parse('https://api.example/users/1/avatar'),
          ),
          pickAvatar: () async => null,
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-avatar-action')));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(cache.removedKeys, hasLength(1));
    expect(find.text('RESULT true'), findsOneWidget);
  });

  testWidgets('a cancelled photo choice does not upload', (tester) async {
    final repository = _RecordingAvatarRepository();
    menuChoice = 'choosePhoto';

    await tester.pumpWidget(
      MaterialApp(
        home: _EditProfileHost(
          repository: repository,
          profile: _profile(),
          pickAvatar: () async => null,
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-avatar-action')));
    await tester.pumpAndSettle();

    expect(repository.uploadedBytes, isNull);
    expect(find.byType(EditProfileScreen), findsOneWidget);
  });
}

class _AvatarCacheManager extends Fake implements BaseCacheManager {
  final removedKeys = <String>[];

  @override
  Stream<FileResponse> getFileStream(String url,
          {String? key,
          Map<String, String>? headers,
          bool withProgress = false}) =>
      Stream.error(StateError('No cached test avatar'));

  @override
  Future<void> removeFile(String key) async => removedKeys.add(key);

  @override
  Future<void> emptyCache() async {}
}

class _EditProfileHost extends StatefulWidget {
  const _EditProfileHost({
    required this.repository,
    required this.profile,
    required this.pickAvatar,
  });

  final ProfileAvatarRepository repository;
  final CurrentUserProfile profile;
  final AvatarImagePicker pickAvatar;

  @override
  State<_EditProfileHost> createState() => _EditProfileHostState();
}

class _EditProfileHostState extends State<_EditProfileHost> {
  bool? result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: result == null
            ? TextButton(
                onPressed: () async {
                  final value = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(
                        profile: widget.profile,
                        avatarRepository: widget.repository,
                        pickAvatar: widget.pickAvatar,
                        avatarRequestHeaders: const {},
                      ),
                    ),
                  );
                  if (!mounted) return;
                  setState(() => result = value);
                },
                child: const Text('OPEN'),
              )
            : Text('RESULT $result'),
      ),
    );
  }
}

class _RecordingAvatarRepository implements ProfileAvatarRepository {
  List<int>? uploadedBytes;
  String? uploadedFilename;
  int deleteCalls = 0;

  @override
  Future<Uri> upload({
    required Uint8List bytes,
    required String filename,
  }) async {
    uploadedBytes = bytes.toList(growable: false);
    uploadedFilename = filename;
    return Uri.parse('https://api.example/users/1/avatar');
  }

  @override
  Future<void> delete() async {
    deleteCalls += 1;
  }
}

CurrentUserProfile _profile({Uri? avatarUri}) => CurrentUserProfile(
      userId: 1,
      username: 'planetowner',
      displayName: 'PlanetOwner',
      email: 'owner@example.com',
      avatarUri: avatarUri,
      favoriteTeamId: 83,
      createdAt: DateTime.utc(2026),
    );
