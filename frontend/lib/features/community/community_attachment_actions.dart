import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_image_headers.dart';
import 'package:onetouch/models/post.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';

const communityAttachmentChannel =
    MethodChannel('onetouch/community_attachment');

Future<String?> chooseCommunityAttachmentAction({
  required String saveLabel,
  required String shareLabel,
}) =>
    communityAttachmentChannel.invokeMethod<String>('choose', {
      'save': saveLabel,
      'share': shareLabel,
    });

Future<void> handleCommunityAttachmentAction(
  PostAttachment attachment,
  String action,
) async {
  final url = attachment.mediaUrl;
  if (url == null) throw const FormatException('Missing attachment URL');

  final uri = Uri.parse(url);
  if (uri.scheme != 'https' && uri.scheme != 'http') {
    throw const FormatException('Unsupported attachment URL');
  }

  final client = http.Client();
  final directory = await Directory.systemTemp.createTemp('community_media_');
  final extension = path.extension(uri.path).toLowerCase();
  final file = File(path.join(
    directory.path,
    'attachment${extension.isEmpty ? (attachment.isVideo ? '.mp4' : '.jpg') : extension}',
  ));
  try {
    final request = http.Request('GET', uri)
      ..headers.addAll(apiImageHeaders(url) ?? const {});
    final response = await client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Attachment download failed: ${response.statusCode}');
    }
    await response.stream.pipe(file.openWrite());
    if (action == 'save') {
      await communityAttachmentChannel.invokeMethod<void>('save', {
        'path': file.path,
        'isVideo': attachment.isVideo,
        'mimeType': attachment.contentType ??
            (attachment.isVideo ? 'video/mp4' : 'image/jpeg'),
      });
    } else if (action == 'share') {
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: attachment.contentType)],
      ));
    }
  } finally {
    client.close();
    // 공유 대상 앱이 파일을 읽을 시간을 남기고 OS 임시 폴더 정리에 맡겨요.
    if (action == 'save') await directory.delete(recursive: true);
  }
}
