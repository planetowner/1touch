import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onetouch/comm_pages/Profile_settings/InfoEdit.dart';
import 'package:onetouch/data/profile/profile_avatar_repository.dart';
import 'package:onetouch/models/current_user_profile.dart';

void main() {
  testWidgets('uses a Cupertino action sheet on iOS', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: _EditProfileHost(
          repository: _RecordingAvatarRepository(),
          profile: _profile(),
          pickAvatar: () async => null,
        ),
      ),
    );

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-avatar-action')));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-avatar-cancel')), findsOneWidget);
  });

  testWidgets('uses a Material bottom sheet on Android', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: _EditProfileHost(
          repository: _RecordingAvatarRepository(),
          profile: _profile(),
          pickAvatar: () async => null,
        ),
      ),
    );

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-avatar-action')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(CupertinoActionSheet), findsNothing);
  });

  testWidgets('chooses and uploads a profile photo', (tester) async {
    final repository = _RecordingAvatarRepository();

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
    await tester.tap(
      find.byKey(const ValueKey('profile-avatar-choose-photo')),
    );
    await tester.pumpAndSettle();

    expect(repository.uploadedBytes, [1, 2, 3]);
    expect(repository.uploadedFilename, 'profile-avatar');
    expect(find.text('RESULT true'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removes an existing profile photo', (tester) async {
    final repository = _RecordingAvatarRepository();

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
    await tester.tap(
      find.byKey(const ValueKey('profile-avatar-remove-photo')),
    );
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(find.text('RESULT true'), findsOneWidget);
  });

  testWidgets('a cancelled photo choice does not upload', (tester) async {
    final repository = _RecordingAvatarRepository();

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
    await tester.tap(
      find.byKey(const ValueKey('profile-avatar-choose-photo')),
    );
    await tester.pumpAndSettle();

    expect(repository.uploadedBytes, isNull);
    expect(find.byType(EditProfileScreen), findsOneWidget);
  });
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
      firstName: 'Planet',
      lastName: 'Owner',
      email: 'owner@example.com',
      avatarUri: avatarUri,
      favoriteTeamId: 83,
      createdAt: DateTime.utc(2026),
    );
