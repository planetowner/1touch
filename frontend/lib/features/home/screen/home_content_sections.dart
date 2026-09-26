part of 'home_screen_features.dart';

class MyHighlights extends StatelessWidget {
  const MyHighlights({
    super.key,
    required this.highlights,
    required this.fallbacks,
  });

  final List<HomeContentItem> highlights;
  final List<HomeContentItem> fallbacks;

  @override
  Widget build(BuildContext context) => highlights.isEmpty
      ? Padding(
          padding: EdgeInsets.all(24),
          child: Text(tr(context, 'No highlights available yet.')))
      : _HomeContentList(
          items: highlights,
          fallbacks: fallbacks,
          addTrailingItemSpacing: false,
        );
}

class MyNews extends StatelessWidget {
  const MyNews({
    super.key,
    required this.news,
    this.isLoading = false,
    this.hasError = false,
    this.onRetry,
  });

  final List<HomeContentItem> news;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (news.isNotEmpty) {
      return _HomeContentList(items: news);
    }
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          hasError
              ? tr(context, 'Unable to load news.')
              : tr(context, 'No team news yet.'),
          style: Body2.style,
        ),
        if (hasError && onRetry != null)
          TextButton(onPressed: onRetry, child: Text(tr(context, 'Retry'))),
      ]),
    );
  }
}

class _HomeContentList extends StatelessWidget {
  const _HomeContentList({
    required this.items,
    this.fallbacks = const [],
    this.addTrailingItemSpacing = true,
  });

  final List<HomeContentItem> items;
  final List<HomeContentItem> fallbacks;
  final bool addTrailingItemSpacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          items.length,
          (index) => Padding(
            padding: EdgeInsets.only(
              bottom:
                  index < items.length - 1 || addTrailingItemSpacing ? 16 : 0,
            ),
            child: _HomeContentCard(
              key: ValueKey('${items[index].destinationUrl}-$index'),
              item: items[index],
              fallback: fallbacks.isEmpty
                  ? null
                  : fallbacks[index % fallbacks.length],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContentCard extends StatelessWidget {
  const _HomeContentCard({
    super.key,
    required this.item,
    required this.fallback,
  });

  final HomeContentItem item;
  final HomeContentItem? fallback;

  Future<void> _openDestination(String? value) async {
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    // 이미지 오류가 나도 실제 기사 제목과 원문 링크는 유지해요.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: item.destinationUrl == null
          ? null
          : () => _openDestination(item.destinationUrl),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _buildImage(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Body1_b.style,
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (item.source.trim().isNotEmpty) item.source.trim(),
                    relativeDateLabel(
                      item.publishedAt,
                      locale: Localizations.localeOf(context),
                      showTimeToday: true,
                      missingDateLabel: 'Latest',
                    ),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Body2.style,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    final imageUrl = item.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: 119,
        height: 68,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return _fallbackImage();
        },
      );
    }
    return _fallbackImage();
  }

  Widget _fallbackImage() {
    if (fallback == null) {
      return const SizedBox(
          width: 119, height: 68, child: Icon(Icons.article_outlined));
    }
    return Image.asset(
      fallback!.fallbackAsset,
      width: 119,
      height: 68,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox(
        width: 119,
        height: 68,
        child: Icon(Icons.error, color: Colors.red),
      ),
    );
  }
}
