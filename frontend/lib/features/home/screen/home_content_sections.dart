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
    required this.fallbacks,
  });

  final List<HomeContentItem> news;
  final List<HomeContentItem> fallbacks;

  @override
  Widget build(BuildContext context) =>
      _HomeContentList(items: news, fallbacks: fallbacks);
}

class _HomeContentList extends StatelessWidget {
  const _HomeContentList({required this.items, required this.fallbacks});

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
              fallback: fallbacks[index % fallbacks.length],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContentCard extends StatefulWidget {
  const _HomeContentCard({
    super.key,
    required this.item,
    required this.fallback,
  });

  final HomeContentItem item;
  final HomeContentItem fallback;

  @override
  State<_HomeContentCard> createState() => _HomeContentCardState();
}

class _HomeContentCardState extends State<_HomeContentCard> {
  bool _useFallback = false;

  @override
  void didUpdateWidget(_HomeContentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.imageUrl != widget.item.imageUrl) {
      _useFallback = false;
    }
  }

  Future<void> _openDestination(String? value) async {
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _handleImageError() {
    if (_useFallback) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_useFallback) setState(() => _useFallback = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = _useFallback ? widget.fallback : widget.item;
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
                SizedBox(
                  height: 37,
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Body1_b.style,
                  ),
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
    final imageUrl = widget.item.imageUrl;
    if (!_useFallback && imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: 119,
        height: 68,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          _handleImageError();
          return _fallbackImage();
        },
      );
    }
    return _fallbackImage();
  }

  Widget _fallbackImage() {
    return Image.asset(
      widget.fallback.fallbackAsset,
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
