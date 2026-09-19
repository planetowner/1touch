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
  Widget build(BuildContext context) =>
      _HomeContentList(items: highlights, fallbacks: fallbacks);
}

class MyNews extends StatelessWidget {
  const MyNews({
    super.key,
    required this.news,
    this.isLoading = false,
    this.hasError = false,
    this.isKorean = false,
    this.onRetry,
  });

  final List<HomeContentItem> news;
  final bool isLoading;
  final bool hasError;
  final bool isKorean;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (hasError || news.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            hasError
                ? (isKorean ? '뉴스를 불러오지 못했어요' : 'Unable to load news.')
                : (isKorean ? '아직 등록된 팀 뉴스가 없어요' : 'No team news yet.'),
            style: Body2.style,
          ),
          if (hasError && onRetry != null)
            TextButton(
                onPressed: onRetry, child: Text(isKorean ? '다시 시도' : 'Retry')),
        ]),
      );
    }
    return _HomeContentList(items: news);
  }
}

class _HomeContentList extends StatelessWidget {
  const _HomeContentList({required this.items, this.fallbacks = const []});

  final List<HomeContentItem> items;
  final List<HomeContentItem> fallbacks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          items.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
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
                  '${item.source} ${item.timeLabel}',
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
