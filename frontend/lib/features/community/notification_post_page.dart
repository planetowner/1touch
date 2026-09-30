import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/data/posts/post_repository_provider.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/screens/CommunityScreen_utils/PostScreen.dart';

class NotificationPostPage extends StatefulWidget {
  const NotificationPostPage({
    super.key,
    required this.postId,
    this.repository,
  });

  final int postId;
  final PostDetailRepository? repository;

  @override
  State<NotificationPostPage> createState() => _NotificationPostPageState();
}

class _NotificationPostPageState extends State<NotificationPostPage> {
  Post? _post;
  Object? _error;

  PostDetailRepository get _repository =>
      widget.repository ?? postDetailRepository;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final post = await _repository.loadPost(widget.postId);
      if (mounted) setState(() => _post = post);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    if (post != null) return PostDetailScreen(post: post);
    return Scaffold(
      backgroundColor: mainPageBackground(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
      ),
      body: Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr(context, 'Unable to load post.'),
                    style: Body1.style,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _load,
                    child: Text(tr(context, 'Try again')),
                  ),
                ],
              ),
      ),
    );
  }
}
