import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays web addresses in post text as tappable links.
class CommunityLinkedText extends StatefulWidget {
  const CommunityLinkedText({
    super.key,
    required this.text,
    required this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<CommunityLinkedText> createState() => _CommunityLinkedTextState();
}

class _CommunityLinkedTextState extends State<CommunityLinkedText> {
  static final _webAddress = RegExp(
    r'(?:https?://|www\.)[^\s<>]+',
    caseSensitive: false,
  );
  static final _trailingPunctuation = RegExp(r'[.,!?;:)\]}]+$');

  final _links = <(int, int, Uri)>[];
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void initState() {
    super.initState();
    _parseLinks();
  }

  @override
  void didUpdateWidget(covariant CommunityLinkedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      for (final recognizer in _recognizers) {
        recognizer.dispose();
      }
      _parseLinks();
    }
  }

  void _parseLinks() {
    _links.clear();
    _recognizers.clear();
    for (final match in _webAddress.allMatches(widget.text)) {
      final address = match.group(0)!.replaceFirst(_trailingPunctuation, '');
      final target = address.toLowerCase().startsWith('www.')
          ? 'https://$address'
          : address;
      final uri = Uri.tryParse(target);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        continue;
      }
      _links.add((match.start, match.start + address.length, uri));
      _recognizers.add(
        TapGestureRecognizer()
          ..onTap = () => unawaited(
                launchUrl(uri, mode: LaunchMode.externalApplication),
              ),
      );
    }
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (var i = 0; i < _links.length; i++) {
      final (start, end, _) = _links[i];
      if (start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, start)));
      }
      spans.add(
        TextSpan(
          text: widget.text.substring(start, end),
          style: const TextStyle(decoration: TextDecoration.underline),
          recognizer: _recognizers[i],
        ),
      );
      cursor = end;
    }
    if (cursor < widget.text.length || spans.isEmpty) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
