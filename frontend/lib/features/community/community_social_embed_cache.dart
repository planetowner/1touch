import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:onetouch/core/web_links.dart';
import 'package:onetouch/features/community/community_social_embed_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

final communitySocialEmbedCache = CommunitySocialEmbedCache();

typedef _EmbedKey = ({Uri uri, String language, bool isDark, double width});

class CommunitySocialEmbedCache {
  final _entries = <_EmbedKey, CommunitySocialEmbed>{};

  CommunitySocialEmbed prepare(Uri uri,
      {required String language, required bool isDark, required double width}) {
    final key = (
      uri: socialPostUri(uri),
      language: language,
      isDark: webLinkKind(uri) == WebLinkKind.x && isDark,
      width: width,
    );
    final entry = _entries.remove(key) ??
        CommunitySocialEmbed(key.uri,
            language: key.language, isDark: key.isDark, width: width);
    _entries[key] = entry;
    // 네이티브 WebView는 최근 여섯 개만 보관하고, 현재 표시 중인 것은 유지해요.
    for (final older in _entries.keys.toList()) {
      if (_entries.length <= 6) break;
      final candidate = _entries[older]!;
      if (older != key && !candidate.inUse) {
        _entries.remove(older);
        candidate.dispose();
      }
    }
    return entry;
  }

  CommunitySocialEmbed acquire(Uri uri,
      {required String language, required bool isDark, required double width}) {
    final entry =
        prepare(uri, language: language, isDark: isDark, width: width);
    // 네이티브 뷰는 한 위치에만 붙일 수 있어, 같은 링크를 동시에 표시할 때만 분리해요.
    return entry.inUse
        ? CommunitySocialEmbed(entry.uri,
            language: entry.language, isDark: entry.isDark, width: entry.width)
        : entry;
  }

  void release(CommunitySocialEmbed entry) {
    if (!_entries.containsValue(entry)) entry.dispose();
  }

  void clear() {
    for (final entry in _entries.values) {
      if (!entry.inUse) entry.dispose();
    }
    _entries.clear();
  }
}

class CommunitySocialEmbed extends ChangeNotifier {
  CommunitySocialEmbed(this.uri,
      {required this.language, required this.isDark, required this.width}) {
    unawaited(load());
  }

  final Uri uri;
  final String language;
  final bool isDark;
  final double width;
  WebViewController? controller;
  Timer? _timeout;
  bool _disposed = false;
  double height = 1;
  bool ready = false;
  bool failed = false;
  bool get inUse => hasListeners;

  void _fail() {
    _timeout?.cancel();
    if (_disposed) return;
    failed = true;
    notifyListeners();
  }

  Future<void> load() async {
    _timeout?.cancel();
    ready = false;
    failed = false;
    if (WebViewPlatform.instance == null) {
      _fail();
      return;
    }
    final current = WebViewController();
    controller = current;
    notifyListeners();
    try {
      await current.setJavaScriptMode(JavaScriptMode.unrestricted);
      await current.setBackgroundColor(Colors.transparent);
      await current.enableZoom(false);
      await current.addJavaScriptChannel('LinkEmbed',
          onMessageReceived: (message) {
        if (_disposed || current != controller) return;
        final payload = jsonDecode(message.message) as Map<String, dynamic>;
        if (payload['error'] == true) {
          _fail();
          return;
        }
        final measured = payload['height'];
        if (measured is num && measured.isFinite && measured > 0) {
          _timeout?.cancel();
          height = measured.toDouble();
          ready = true;
          notifyListeners();
        }
      });
      await current.setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          if (!request.isMainFrame || request.url == 'about:blank') {
            return NavigationDecision.navigate;
          }
          final uri = webUri(request.url);
          if (uri != null) {
            unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
          }
          return NavigationDecision.prevent;
        },
        onWebResourceError: (error) {
          if (current == controller && error.isForMainFrame == true) _fail();
        },
      ));
      if (_disposed || current != controller) return;
      _timeout = Timer(const Duration(seconds: 20), _fail);
      await current.loadHtmlString(communitySocialEmbedHtml(uri,
          language: language, isDark: isDark, width: width));
    } catch (_) {
      if (!_disposed && current == controller) _fail();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timeout?.cancel();
    super.dispose();
  }
}
