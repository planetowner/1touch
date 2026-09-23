import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/post_attachments/api/api_post_attachment_repository.dart';

void main() {
  test('uploads an authenticated multipart attachment', () async {
    final bytes = Uint8List.fromList(utf8.encode('post-image-bytes'));
    final repository = ApiPostAttachmentRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/v1/attachments/upload');
            expect(request.headers['Accept'], 'application/json');
            expect(request.headers['Authorization'], 'Bearer session-token');
            expect(
              request.headers['Content-Type'],
              startsWith('multipart/form-data'),
            );

            final body = utf8.decode(request.bodyBytes, allowMalformed: true);
            expect(body, contains('name="file"'));
            expect(body, contains('filename="match.png"'));
            expect(body, contains('post-image-bytes'));
            return http.Response(
              jsonEncode({
                'attachment_id': 41,
                'content_type': 'image/png',
                'byte_size': bytes.length,
              }),
              201,
            );
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () =>
              const {'Authorization': 'Bearer session-token'}),
    );

    final uploaded = await repository.upload(
      bytes: bytes,
      filename: 'match.png',
    );

    expect(uploaded.attachmentId, 41);
    expect(uploaded.contentType, 'image/png');
    expect(uploaded.byteSize, bytes.length);
  });

  test('deletes an unpublished attachment', () async {
    final repository = ApiPostAttachmentRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.method, 'DELETE');
            expect(request.url.path, '/v1/attachments/41');
            expect(request.headers['Authorization'], 'Bearer session-token');
            return http.Response(jsonEncode({'ok': true}), 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1/'),
          requestHeaders: () =>
              const {'Authorization': 'Bearer session-token'}),
    );

    await repository.delete(41);
  });

  test('validates upload and deletion inputs before requesting', () async {
    var requests = 0;
    final repository = ApiPostAttachmentRepository(
      api: ApiClient(
          client: MockClient((_) async {
            requests++;
            return http.Response('{}', 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.upload(bytes: Uint8List(0), filename: 'empty.png'),
      throwsArgumentError,
    );
    await expectLater(
      repository.upload(bytes: Uint8List.fromList([1]), filename: ' '),
      throwsArgumentError,
    );
    await expectLater(repository.delete(0), throwsRangeError);
    expect(requests, 0);
  });

  test('rejects failed and malformed upload responses', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final responses = [
      http.Response('Unauthorized', 401),
      http.Response(jsonEncode([]), 201),
      http.Response(
        jsonEncode({
          'attachment_id': 41,
          'content_type': 'application/pdf',
          'byte_size': bytes.length,
        }),
        201,
      ),
      http.Response(
        jsonEncode({
          'attachment_id': 41,
          'content_type': 'image/png',
          'byte_size': 999,
        }),
        201,
      ),
    ];
    var index = 0;
    final repository = ApiPostAttachmentRepository(
      api: ApiClient(
          client: MockClient((_) async => responses[index++]),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.upload(bytes: bytes, filename: 'match.png'),
      throwsA(isA<http.ClientException>()),
    );
    for (var i = 1; i < responses.length; i++) {
      await expectLater(
        repository.upload(bytes: bytes, filename: 'match.png'),
        throwsFormatException,
      );
    }
  });

  test('rejects failed and malformed deletion responses', () async {
    final responses = [
      http.Response('Forbidden', 403),
      http.Response(jsonEncode({'ok': false}), 200),
    ];
    var index = 0;
    final repository = ApiPostAttachmentRepository(
      api: ApiClient(
          client: MockClient((_) async => responses[index++]),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.delete(41),
      throwsA(isA<http.ClientException>()),
    );
    await expectLater(repository.delete(41), throwsFormatException);
  });
}
