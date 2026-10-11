import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:onetouch/core/stylesheet.dart';

class MatchTeamName extends StatelessWidget {
  const MatchTeamName({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    // 팀 영역의 폭을 유지하면서 긴 이름도 로고 중심에 맞춰 한 줄로 보여줘요.
    return OverflowBox(
      minWidth: 0,
      maxWidth: double.infinity,
      fit: OverflowBoxFit.deferToChild,
      child: Text(
        name,
        style: Body1.style.copyWith(height: 1.3),
        textAlign: TextAlign.center,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}
