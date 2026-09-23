import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/profile/api/api_profile_avatar_repository.dart';

void main() {
  test('uploads the avatar as an authenticated multipart file', () async {
    final repository = ApiProfileAvatarRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.method, 'PUT');
            expect(request.url.path, '/v1/users/me/avatar');
            expect(request.headers['Accept'], 'application/json');
            expect(request.headers['Authorization'], 'Bearer session-token');
            expect(request.headers['Content-Type'],
                startsWith('multipart/form-data'));

            final body = utf8.decode(request.bodyBytes, allowMalformed: true);
            expect(body, contains('name="file"'));
            expect(body, contains('filename="avatar.png"'));
            expect(body, contains('profile-image-bytes'));
            return http.Response(
              jsonEncode({'avatar_url': '/v1/users/1/avatar'}),
              200,
            );
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {
                'Authorization': 'Bearer session-token',
              }),
    );

    final avatarUri = await repository.upload(
      bytes: Uint8List.fromList(utf8.encode('profile-image-bytes')),
      filename: 'avatar.png',
    );

    expect(
      avatarUri,
      Uri.parse('https://api.1touch.football/v1/users/1/avatar'),
    );
  });

  test('rejects empty files before making a request', () async {
    var requested = false;
    final repository = ApiProfileAvatarRepository(
      api: ApiClient(
          client: MockClient((_) async {
            requested = true;
            return http.Response('{}', 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1/'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.upload(bytes: Uint8List(0), filename: 'avatar.png'),
      throwsArgumentError,
    );
    expect(requested, isFalse);
  });

  test('rejects unsuccessful and malformed responses', () async {
    final responses = [
      http.Response('Unauthorized', 401),
      http.Response(jsonEncode([]), 200),
      http.Response(jsonEncode({'avatar_url': null}), 200),
      http.Response(jsonEncode({'avatar_url': 'file:///avatar.png'}), 200),
    ];
    var requestCount = 0;
    final repository = ApiProfileAvatarRepository(
      api: ApiClient(
          client: MockClient((_) async => responses[requestCount++]),
          baseUri: Uri.parse('https://api.1touch.football/v1/'),
          requestHeaders: () => const {}),
    );
    final bytes = Uint8List.fromList([1]);

    await expectLater(
      repository.upload(bytes: bytes, filename: 'avatar.png'),
      throwsA(isA<http.ClientException>()),
    );
    await expectLater(
      repository.upload(bytes: bytes, filename: 'avatar.png'),
      throwsFormatException,
    );
    await expectLater(
      repository.upload(bytes: bytes, filename: 'avatar.png'),
      throwsFormatException,
    );
    await expectLater(
      repository.upload(bytes: bytes, filename: 'avatar.png'),
      throwsFormatException,
    );
  });

  test('deletes the authenticated user avatar', () async {
    final repository = ApiProfileAvatarRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.method, 'DELETE');
            expect(request.url.path, '/v1/users/me/avatar');
            expect(request.headers['Accept'], 'application/json');
            expect(request.headers['Authorization'], 'Bearer session-token');
            return http.Response(jsonEncode({'ok': true}), 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1/'),
          requestHeaders: () => const {
                'Authorization': 'Bearer session-token',
              }),
    );

    await repository.delete();
  });

  test('rejects failed and malformed avatar deletions', () async {
    final responses = [
      http.Response('Unauthorized', 401),
      http.Response(jsonEncode({'ok': false}), 200),
    ];
    var requestCount = 0;
    final repository = ApiProfileAvatarRepository(
      api: ApiClient(
          client: MockClient((_) async => responses[requestCount++]),
          baseUri: Uri.parse('https://api.1touch.football/v1/'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.delete(),
      throwsA(isA<http.ClientException>()),
    );
    await expectLater(repository.delete(), throwsFormatException);
  });
}
