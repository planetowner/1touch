import 'package:flutter/material.dart';
import 'package:onetouch/core/overflow_scrolling_text.dart';
import 'package:onetouch/data/competitions/competition_repository_provider.dart';

const _localCompetitionLogos = <int, String>{
  8: 'assets/EPL.png',
  564: 'assets/laliga.png',
  82: 'assets/bundesliga.png',
  384: 'assets/seriea.png',
  301: 'assets/league1.png',
};

class CompetitionLogo extends StatelessWidget {
  const CompetitionLogo(
      {super.key,
      required this.competitionId,
      this.size = 12,
      this.trailingGap = 0});

  final int competitionId;
  final double size;
  final double trailingGap;

  Widget _loadedFrame(
      BuildContext context, Widget image, int? frame, bool synchronous) {
    if (frame == null && !synchronous) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(right: trailingGap),
      child: SizedBox(width: size, height: size, child: image),
    );
  }

  Widget _assetImage(String asset, Color? tint) => Padding(
        padding: EdgeInsets.only(right: trailingGap),
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          color: tint,
          colorBlendMode: tint == null ? null : BlendMode.srcIn,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final asset = _localCompetitionLogos[competitionId];
    final imagePath = competitionRepository.findById(competitionId)?.imagePath;
    // 어두운 원본 로고만 다크 모드에서 밝게 바꿔요.
    final tint = Theme.of(context).brightness == Brightness.dark &&
            {8, 2, 5}.contains(competitionId)
        ? Colors.white
        : null;
    return ExcludeSemantics(
      child: imagePath == null || imagePath.isEmpty
          ? asset == null
              ? const SizedBox.shrink()
              : _assetImage(asset, tint)
          : Image.network(
              imagePath,
              width: size,
              height: size,
              fit: BoxFit.contain,
              color: tint,
              colorBlendMode: tint == null ? null : BlendMode.srcIn,
              frameBuilder: _loadedFrame,
              errorBuilder: (_, __, ___) => asset == null
                  ? const SizedBox.shrink()
                  : _assetImage(asset, tint),
            ),
    );
  }
}

class CompetitionLabel extends StatelessWidget {
  const CompetitionLabel({
    super.key,
    required this.competitionId,
    required this.label,
    required this.style,
    this.iconSize = 12,
    this.gap = 8,
    this.textKey,
    this.mainAxisSize = MainAxisSize.min,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.maxLines = 1,
    this.textAlign,
    this.overflow = TextOverflow.ellipsis,
    this.scrollOnOverflow = false,
  });

  final int? competitionId;
  final String label;
  final TextStyle style;
  final double iconSize;
  final double gap;
  final Key? textKey;
  final MainAxisSize mainAxisSize;
  final MainAxisAlignment mainAxisAlignment;
  final int? maxLines;
  final TextAlign? textAlign;
  final TextOverflow overflow;
  final bool scrollOnOverflow;

  Widget _labelRow() => Row(
        mainAxisSize: mainAxisSize,
        mainAxisAlignment: mainAxisAlignment,
        children: [
          if (competitionId != null) ...[
            CompetitionLogo(
              competitionId: competitionId!,
              size: iconSize,
              trailingGap: gap,
            ),
          ],
          Flexible(
            child: scrollOnOverflow
                ? OverflowScrollingText(
                    key: textKey,
                    text: label,
                    style: style,
                    alignment: Alignment.center,
                  )
                : Text(
                    label,
                    key: textKey,
                    maxLines: maxLines,
                    softWrap: maxLines != 1,
                    textAlign: textAlign,
                    overflow: overflow,
                    style: style,
                  ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (!scrollOnOverflow) return _labelRow();
    return Align(alignment: Alignment.center, child: _labelRow());
  }
}
