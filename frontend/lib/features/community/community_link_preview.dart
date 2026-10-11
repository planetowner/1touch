import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/web_links.dart';
import 'package:onetouch/data/link_previews/link_preview_repository.dart';
import 'package:onetouch/features/community/community_linked_text.dart';
import 'package:onetouch/features/community/community_post_image.dart';
import 'package:onetouch/features/community/community_social_embed_html.dart';
import 'package:onetouch/features/community/community_ui.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CommunityLinkPreview extends StatelessWidget {
  const CommunityLinkPreview({super.key, required this.uri, this.repository});
  final Uri uri;
  final LinkPreviewRepository? repository;

  @override
  Widget build(BuildContext context) => webLinkKind(uri) == WebLinkKind.website
      ? _WebsitePreview(key: ValueKey(uri), uri: uri, repository: repository)
      : _SocialPreview(key: ValueKey(uri), uri: uri);
}

class CommunityWebsiteCard extends StatelessWidget {
  const CommunityWebsiteCard(
      {super.key, required this.uri, required this.data});
  final Uri uri;
  final LinkPreviewData data;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      link: true,
      child: GestureDetector(
        onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ColoredBox(
            color: AppColors.of(context).cardBackground,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (data.imageUri != null)
                  AspectRatio(
                    aspectRatio: 345 / 173,
                    child:
                        CommunityPostImage(mediaUrl: data.imageUri.toString()),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(data.title,
                          style:
                              CommunityText.title(context, text: data.title)),
                      const SizedBox(height: 8),
                      Text(uri.toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CommunityText.body(context, text: '').copyWith(
                              fontSize: 12,
                              color: foreground.withValues(alpha: .5),
                              decoration: TextDecoration.underline)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WebsitePreview extends StatefulWidget {
  const _WebsitePreview({super.key, required this.uri, this.repository});
  final Uri uri;
  final LinkPreviewRepository? repository;

  @override
  State<_WebsitePreview> createState() => _WebsitePreviewState();
}

class _WebsitePreviewState extends State<_WebsitePreview> {
  late Future<LinkPreviewData> _preview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _preview = (widget.repository ?? LinkPreviewRepository()).load(widget.uri);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<LinkPreviewData>(
        future: _preview,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _UnavailableLink(
                uri: widget.uri, onRetry: () => setState(_load));
          }
          if (!snapshot.hasData) return const _LinkLoading();
          return CommunityWebsiteCard(uri: widget.uri, data: snapshot.data!);
        },
      );
}

class _SocialPreview extends StatefulWidget {
  const _SocialPreview({super.key, required this.uri});
  final Uri uri;

  @override
  State<_SocialPreview> createState() => _SocialPreviewState();
}

class _SocialPreviewState extends State<_SocialPreview> {
  WebViewController? _controller;
  Timer? _timeout;
  String? _language;
  bool? _isDark;
  double _height = 1;
  bool _ready = false;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    final isDark = webLinkKind(widget.uri) == WebLinkKind.x &&
        Theme.of(context).brightness == Brightness.dark;
    if (_language == language && _isDark == isDark) return;
    _language = language;
    _isDark = isDark;
    // X 공식 임베드는 생성할 때 테마가 정해져, 앱 테마가 바뀌면 다시 불러와요.
    _load();
  }

  void _fail() {
    _timeout?.cancel();
    if (mounted) setState(() => _failed = true);
  }

  Future<void> _load() async {
    _timeout?.cancel();
    _ready = false;
    _failed = false;
    // WebView를 지원하지 않는 플랫폼에서도 원문 링크는 열 수 있어요.
    if (WebViewPlatform.instance == null) {
      _failed = true;
      return;
    }
    final controller = WebViewController();
    _controller = controller;
    try {
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.transparent);
      await controller.enableZoom(false);
      await controller.addJavaScriptChannel('LinkEmbed',
          onMessageReceived: (message) {
        if (!mounted || controller != _controller) return;
        final payload = jsonDecode(message.message) as Map<String, dynamic>;
        if (payload['error'] == true) {
          _fail();
          return;
        }
        final height = payload['height'];
        if (height is num && height.isFinite && height > 0) {
          _timeout?.cancel();
          // 공식 위젯이 계산한 높이를 따라가야 긴 캡션과 영상도 잘리지 않아요.
          setState(() {
            _height = height.toDouble();
            _ready = true;
          });
        }
      });
      await controller.setNavigationDelegate(NavigationDelegate(
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
          if (controller == _controller && error.isForMainFrame == true) _fail();
        },
      ));
      if (!mounted || controller != _controller) return;
      _timeout = Timer(const Duration(seconds: 20), _fail);
      await controller.loadHtmlString(communitySocialEmbedHtml(widget.uri,
          language: _language!, isDark: _isDark!));
    } catch (_) {
      if (mounted && controller == _controller) _fail();
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return _UnavailableLink(
          uri: widget.uri,
          onRetry: () => setState(() {
                _load();
              }));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (!_ready) const _LinkLoading(),
      // 내부 색상과 모서리는 공식 위젯이 소유해요. 앱에서 잘라내거나 다시 그리지 않아요.
      if (_controller != null)
        SizedBox(
          height: _height,
          child: WebViewWidget(controller: _controller!),
        ),
    ]);
  }
}

class _LinkLoading extends StatelessWidget {
  const _LinkLoading();
  @override
  Widget build(BuildContext context) =>
      const Center(child: FootballLoadingIndicator());
}

class _UnavailableLink extends StatelessWidget {
  const _UnavailableLink({required this.uri, required this.onRetry});
  final Uri uri;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CommunityLinkedText(
              text: uri.toString(),
              showLinkIcons: true,
              style: CommunityText.body(context)),
          TextButton(onPressed: onRetry, child: Text(tr(context, 'Retry'))),
        ],
      );
}
