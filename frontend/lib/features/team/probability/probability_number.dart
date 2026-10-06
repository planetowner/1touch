import 'package:flutter/material.dart';
import 'package:onetouch/core/probability_display.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/models/team_probability.dart';

class ProbabilityNumber extends StatelessWidget {
  const ProbabilityNumber({
    super.key,
    required this.card,
    required this.keyPrefix,
    this.keySuffix = '',
  });

  final TeamProbabilityCard card;
  final String keyPrefix;
  final String keySuffix;

  @override
  Widget build(BuildContext context) {
    final display = probabilityDisplay(card);
    // 부등호는 숫자의 세로 중앙에, 단위는 숫자의 하단에 맞춰요.
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (display.prefix.isNotEmpty)
              Text(display.prefix,
                  key: ValueKey('$keyPrefix-prefix$keySuffix'),
                  style: Heading3.latinStyle),
            Text(display.number,
                key: ValueKey('$keyPrefix-value$keySuffix'),
                style: Heading1.latinStyle.copyWith(height: .9)),
          ],
        ),
        Text('%',
            key: ValueKey('$keyPrefix-percent$keySuffix'),
            style: Heading3.latinStyle),
      ],
    );
  }
}
