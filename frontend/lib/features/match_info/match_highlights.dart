part of 'match_info_features.dart';

class MatchHighlights extends StatefulWidget {
  final int fixtureId;
  final FixtureHighlightRepository? repository;

  const MatchHighlights({
    super.key,
    required this.fixtureId,
    this.repository,
  });

  @override
  State<MatchHighlights> createState() => _MatchHighlightsState();
}

class _MatchHighlightsState extends State<MatchHighlights> {
  FixtureHighlight? _highlight;
  bool _networkImageFailed = false;
  int _requestId = 0;

  FixtureHighlightRepository get _repository =>
      widget.repository ?? fixtureHighlightRepository;

  @override
  void initState() {
    super.initState();
    _loadHighlight();
  }

  @override
  void didUpdateWidget(MatchHighlights oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fixtureId != widget.fixtureId ||
        oldWidget.repository != widget.repository) {
      _highlight = null;
      _networkImageFailed = false;
      _loadHighlight();
    }
  }

  Future<void> _loadHighlight() async {
    final requestId = ++_requestId;
    try {
      final highlight = await _repository.loadForFixture(widget.fixtureId);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _highlight = highlight;
        _networkImageFailed = false;
      });
    } on Object {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _highlight = null;
        _networkImageFailed = false;
      });
    }
  }

  Future<void> _openHighlight() async {
    final highlight = _highlight;
    if (highlight == null) return;
    final uri = Uri.parse(highlight.videoUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _handleImageError() {
    if (_networkImageFailed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_networkImageFailed) {
        setState(() => _networkImageFailed = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canOpen = _highlight != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(context, "HIGHLIGHTS"), style: Body2_b.style),
        const SizedBox(height: 16),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canOpen ? _openHighlight : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _buildImage(),
          ),
        ),
      ],
    );
  }

  Widget _buildImage() {
    final imageUrl = _highlight?.thumbnailUrl;
    if (!_networkImageFailed && imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: double.infinity,
        height: 194,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          _handleImageError();
          return _placeholder();
        },
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    // 썸네일이 없어도 확인된 경기 영상은 열 수 있어요.
    return Container(
      width: double.infinity,
      height: 194,
      alignment: Alignment.center,
      color: AppColors.of(context).cardBackground,
      child: _highlight != null
          ? const Icon(Icons.play_circle_outline, size: 48)
          : Text(
              tr(context, 'HIGHLIGHTS UNAVAILABLE'),
              style: Body2_b.style.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
    );
  }
}
