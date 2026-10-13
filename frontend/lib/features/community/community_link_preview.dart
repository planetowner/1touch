import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/web_links.dart';
import 'package:onetouch/data/link_previews/link_preview_repository.dart';
import 'package:onetouch/features/community/community_linked_text.dart';
import 'package:onetouch/features/community/community_post_image.dart';
import 'package:onetouch/features/community/community_social_embed_cache.dart';
import 'package:onetouch/features/community/community_ui.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CommunityLinkPreview extends StatelessWidget {
  const CommunityLinkPreview(
      {super.key, required this.uri, this.repository, this.followingContent});
  final Uri uri;
  final LinkPreviewRepository? repository;
  final Widget? followingContent;

  @override
  Widget build(BuildContext context) => webLinkKind(uri) == WebLinkKind.website
      ? _WebsitePreview(
          key: ValueKey(uri),
          uri: uri,
          repository: repository,
          followingContent: followingContent)
      : LayoutBuilder(
          builder: (context, constraints) => _SocialPreview(
              key: ValueKey(uri),
              uri: uri,
              width: constraints.maxWidth,
              followingContent: followingContent));
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
                    child: CommunityPostImage(
                      mediaUrl: data.imageUri.toString(),
                      imageProvider:
                          CachedNetworkImageProvider(data.imageUri.toString()),
                    ),
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
  const _WebsitePreview(
      {super.key, required this.uri, this.repository, this.followingContent});
  final Uri uri;
  final LinkPreviewRepository? repository;
  final Widget? followingContent;

  @override
  State<_WebsitePreview> createState() => _WebsitePreviewState();
}

class _WebsitePreviewState extends State<_WebsitePreview> {
  late Future<LinkPreviewData> _preview;
  LinkPreviewData? _initialData;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repository = widget.repository ?? linkPreviewRepository;
    _initialData = repository.cached(widget.uri);
    _preview = repository.load(widget.uri);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<LinkPreviewData>(
        future: _preview,
        initialData: _initialData,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _withFollowing(
                _UnavailableLink(
                    uri: widget.uri, onRetry: () => setState(_load)),
                widget.followingContent);
          }
          if (!snapshot.hasData) return const _LinkLoading();
          return _withFollowing(
              CommunityWebsiteCard(uri: widget.uri, data: snapshot.data!),
              widget.followingContent);
        },
      );
}

class _SocialPreview extends StatefulWidget {
  const _SocialPreview(
      {super.key,
      required this.uri,
      required this.width,
      this.followingContent});
  final Uri uri;
  final double width;
  final Widget? followingContent;

  @override
  State<_SocialPreview> createState() => _SocialPreviewState();
}

class _SocialPreviewState extends State<_SocialPreview> {
  CommunitySocialEmbed? _embed;
  (String, bool, double)? _configuration;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepare();
  }

  @override
  void didUpdateWidget(_SocialPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepare();
  }

  void _prepare() {
    final language = Localizations.localeOf(context).languageCode;
    final isDark = webLinkKind(widget.uri) == WebLinkKind.x &&
        Theme.of(context).brightness == Brightness.dark;
    final configuration = (language, isDark, widget.width);
    if (_configuration == configuration) return;
    _configuration = configuration;
    _release();
    final embed = communitySocialEmbedCache.acquire(widget.uri,
        language: language, isDark: isDark, width: widget.width);
    _embed = embed..addListener(_changed);
  }

  void _release() {
    final embed = _embed;
    if (embed == null) return;
    embed.removeListener(_changed);
    communitySocialEmbedCache.release(embed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final embed = _embed!;
    if (embed.failed) {
      return _withFollowing(
          _UnavailableLink(uri: widget.uri, onRetry: embed.load),
          widget.followingContent);
    }
    final preview = Column(mainAxisSize: MainAxisSize.min, children: [
      if (!embed.ready) const _LinkLoading(),
      // 목록에서 준비한 WebView와 높이를 그대로 써서 진입 때 본문이 밀리지 않아요.
      if (embed.controller != null)
        SizedBox(
          height: embed.height,
          child: WebViewWidget(controller: embed.controller!),
        ),
    ]);
    return _withFollowing(
        preview, embed.ready ? widget.followingContent : null);
  }
}

Widget _withFollowing(Widget preview, Widget? following) => following == null
    ? preview
    : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [preview, const SizedBox(height: 24), following],
      );

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
