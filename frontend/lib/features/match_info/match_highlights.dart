part of 'match_info_features.dart';

class MatchHighlights extends StatefulWidget {
  final int homeTeamId;
  final int awayTeamId;
  final HomeContentRepository? repository;

  const MatchHighlights({
    super.key,
    required this.homeTeamId,
    required this.awayTeamId,
    this.repository,
  });

  @override
  State<MatchHighlights> createState() => _MatchHighlightsState();
}

class _MatchHighlightsState extends State<MatchHighlights> {
  HomeContentItem? _highlight;
  bool _networkImageFailed = false;
  int _requestId = 0;

  HomeContentRepository get _repository =>
      widget.repository ?? homeContentRepository;

  @override
  void initState() {
    super.initState();
    _loadHighlight();
  }

  @override
  void didUpdateWidget(MatchHighlights oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.homeTeamId != widget.homeTeamId ||
        oldWidget.awayTeamId != widget.awayTeamId ||
        oldWidget.repository != widget.repository) {
      _highlight = null;
      _networkImageFailed = false;
      _loadHighlight();
    }
  }

  Future<void> _loadHighlight() async {
    final requestId = ++_requestId;
    try {
      final highlight = await _repository.loadForMatch(
        homeTeamId: widget.homeTeamId,
        awayTeamId: widget.awayTeamId,
      );
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
    final uri = Uri.tryParse(_highlight?.destinationUrl ?? '');
    if (uri == null || _networkImageFailed) return;
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
    final canOpen =
        _highlight?.destinationUrl?.isNotEmpty == true && !_networkImageFailed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("HIGHLIGHTS", style: Body2_b.style),
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
    final imageUrl = _highlight?.imageUrl;
    if (!_networkImageFailed && imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: double.infinity,
        height: 194,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          _handleImageError();
          return _unavailablePlaceholder();
        },
      );
    }
    return _unavailablePlaceholder();
  }

  Widget _unavailablePlaceholder() {
    return Container(
      width: double.infinity,
      height: 194,
      alignment: Alignment.center,
      color: AppColors.of(context).cardBackground,
      child: Text(
        'HIGHLIGHTS UNAVAILABLE',
        style: Body2_b.style.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
