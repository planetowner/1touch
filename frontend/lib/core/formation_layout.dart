import 'dart:ui';

/// 베스트 11과 경기 라인업이 같은 345 × 392 디자인 좌표를 사용해요.
/// 수비부터 공격 순서로 저장하고, 골키퍼 위치는 한 번만 정의해요.
class FormationLayout {
  const FormationLayout(this.rows);

  factory FormationLayout.forFormation(String formation) {
    final code = formationLayoutCode(formation);
    return formationLayouts[code] ?? buildFallbackFormationLayout(code);
  }

  static const Size designSize = Size(345, 392);
  static const Offset goalkeeper = Offset(173, 340);

  final List<List<Offset>> rows;

  Offset? positionForSlot(String slotKey, {bool reverseColumns = false}) {
    final parts = slotKey.split(':');
    if (parts.length != 2) return null;
    final row = int.tryParse(parts[0]);
    final column = int.tryParse(parts[1]);
    if (row == null || column == null || row < 1 || column < 1) return null;
    if (row == 1) return column == 1 ? goalkeeper : null;
    final rowIndex = row - 2;
    if (rowIndex >= rows.length) return null;
    final positions = rows[rowIndex];
    if (column > positions.length) return null;
    final columnIndex = reverseColumns ? positions.length - column : column - 1;
    return positions[columnIndex];
  }
}

const Map<String, FormationLayout> formationLayouts = {
  '2-3-2-1-2': FormationLayout([
    [Offset(124, 264), Offset(222, 264)],
    [Offset(48, 200), Offset(173, 200), Offset(298, 200)],
    [Offset(112, 136), Offset(234, 136)],
    [Offset(173, 80)],
    [Offset(112, 32), Offset(234, 32)],
  ]),
  '3-4-2-1': FormationLayout([
    [Offset(80, 264), Offset(173, 264), Offset(266, 264)],
    [Offset(52, 176), Offset(134, 184), Offset(209.5, 184), Offset(293, 176)],
    [Offset(120, 111), Offset(226, 111)],
    [Offset(173, 44)],
  ]),
  '4-2-1-3': FormationLayout([
    [Offset(48, 232), Offset(128, 264), Offset(218, 264), Offset(298, 232)],
    [Offset(128, 184), Offset(218, 184)],
    [Offset(173, 120)],
    [Offset(56, 64), Offset(173, 44), Offset(290, 64)],
  ]),
  '4-4-1-1': FormationLayout([
    [Offset(48, 220), Offset(132, 252), Offset(214, 252), Offset(298, 220)],
    [Offset(52, 152), Offset(132, 176), Offset(214, 176), Offset(294, 152)],
    [Offset(173, 108)],
    [Offset(173, 44)],
  ]),
  '3-3-1-3': FormationLayout([
    [Offset(74, 264), Offset(173, 264), Offset(269.5, 264)],
    [Offset(96, 192), Offset(173, 192), Offset(250, 192)],
    [Offset(173, 120)],
    [Offset(48, 56), Offset(173, 44), Offset(298, 56)],
  ]),
  '4-1-2-1-2': FormationLayout([
    [Offset(48, 236), Offset(132, 268), Offset(214, 268), Offset(298, 236)],
    [Offset(173, 200)],
    [Offset(99.5, 152), Offset(247, 152)],
    [Offset(173, 112)],
    [Offset(124, 48), Offset(222, 48)],
  ]),
  '4-3-1-2': FormationLayout([
    [Offset(48, 236), Offset(132, 260), Offset(214, 260), Offset(298, 236)],
    [Offset(88, 168), Offset(173, 184), Offset(258, 168)],
    [Offset(173, 108)],
    [Offset(124, 48), Offset(222, 48)],
  ]),
  '5-3-1-1': FormationLayout([
    [
      Offset(48, 224),
      Offset(107, 256),
      Offset(173, 256),
      Offset(239, 256),
      Offset(298, 224)
    ],
    [Offset(94, 160), Offset(173, 184), Offset(249.5, 160)],
    [Offset(173, 108)],
    [Offset(173, 44)],
  ]),
  '3-1-4-2': FormationLayout([
    [Offset(80, 264), Offset(173, 264), Offset(266, 264)],
    [Offset(173, 192)],
    [Offset(62, 128), Offset(136, 128), Offset(210, 128), Offset(284, 128)],
    [Offset(132, 48), Offset(214, 48)],
  ]),
  '3-4-3': FormationLayout([
    [Offset(80, 256), Offset(173, 264), Offset(266, 256)],
    [Offset(49.5, 160), Offset(133, 176), Offset(215, 176), Offset(297, 160)],
    [Offset(80, 76), Offset(173, 44), Offset(266, 76)],
  ]),
  '4-2-2-2': FormationLayout([
    [Offset(48, 220), Offset(132, 252), Offset(214, 252), Offset(298, 220)],
    [Offset(120, 184), Offset(226, 184)],
    [Offset(120, 116), Offset(226, 116)],
    [Offset(120, 48), Offset(226, 48)],
  ]),
  '4-4-2': FormationLayout([
    [Offset(48, 220), Offset(132, 252), Offset(214, 252), Offset(298, 220)],
    [Offset(52, 120), Offset(132, 168), Offset(214, 168), Offset(294, 120)],
    [Offset(124, 48), Offset(222, 48)],
  ]),
  '3-3-2-2': FormationLayout([
    [Offset(62, 264), Offset(173, 264), Offset(281.5, 264)],
    [Offset(96, 192), Offset(173, 192), Offset(250, 192)],
    [Offset(132, 120), Offset(214, 120)],
    [Offset(124, 48), Offset(222, 48)],
  ]),
  '4-1-2-3': FormationLayout([
    [Offset(48, 220), Offset(132, 252), Offset(214, 252), Offset(298, 220)],
    [Offset(173, 192)],
    [Offset(124, 128), Offset(222, 128)],
    [Offset(48, 72), Offset(173, 44), Offset(298, 72)],
  ]),
  '4-3-2-1': FormationLayout([
    [Offset(48, 236), Offset(132, 268), Offset(214, 268), Offset(298, 236)],
    [Offset(90, 172), Offset(173, 200), Offset(253.5, 172)],
    [Offset(131.5, 112), Offset(215, 112)],
    [Offset(173, 44)],
  ]),
  '5-3-2': FormationLayout([
    [
      Offset(48, 226),
      Offset(104, 256),
      Offset(171, 256),
      Offset(242, 256),
      Offset(298, 226)
    ],
    [Offset(90, 128), Offset(173, 168), Offset(253.5, 128)],
    [Offset(124, 48), Offset(222, 48)],
  ]),
  '3-2-3-2': FormationLayout([
    [Offset(78, 264), Offset(173, 264), Offset(265.5, 264)],
    [Offset(124, 192), Offset(222, 192)],
    [Offset(56, 112), Offset(173, 128), Offset(290, 112)],
    [Offset(124, 48), Offset(222, 48)],
  ]),
  '3-5-1-1': FormationLayout([
    [Offset(76, 264), Offset(173, 264), Offset(270, 264)],
    [
      Offset(48, 144),
      Offset(108, 190),
      Offset(173, 190),
      Offset(238, 190),
      Offset(298, 144)
    ],
    [Offset(173, 108)],
    [Offset(173, 44)],
  ]),
  '4-2-3-1': FormationLayout([
    [Offset(48, 220), Offset(132, 252), Offset(214, 252), Offset(298, 220)],
    [Offset(116, 176), Offset(230, 176)],
    [Offset(48, 104), Offset(173, 120), Offset(298, 104)],
    [Offset(173, 44)],
  ]),
  '4-5-1': FormationLayout([
    [Offset(48, 220), Offset(132, 252), Offset(214, 252), Offset(298, 220)],
    [
      Offset(46, 112),
      Offset(105, 160),
      Offset(173, 136),
      Offset(240, 160),
      Offset(299, 112)
    ],
    [Offset(173, 44)],
  ]),
  '3-3-3-1': FormationLayout([
    [Offset(78, 264), Offset(173, 264), Offset(265.5, 264)],
    [Offset(100, 188), Offset(173, 188), Offset(246, 188)],
    [Offset(72, 108), Offset(173, 116), Offset(274, 108)],
    [Offset(173, 44)],
  ]),
  '4-1-3-2': FormationLayout([
    [Offset(48, 236), Offset(132, 268), Offset(214, 268), Offset(298, 236)],
    [Offset(173, 200)],
    [Offset(48, 108), Offset(173, 124), Offset(298, 108)],
    [Offset(124, 48), Offset(222, 48)],
  ]),
  '5-4-1': FormationLayout([
    [
      Offset(48, 224),
      Offset(107, 256),
      Offset(173, 256),
      Offset(239, 256),
      Offset(298, 224)
    ],
    [Offset(50, 128), Offset(132, 160), Offset(214, 160), Offset(295, 128)],
    [Offset(173, 44)],
  ]),
  '3-2-4-1': FormationLayout([
    [Offset(78, 264), Offset(173, 264), Offset(265.5, 264)],
    [Offset(132, 192), Offset(214, 192)],
    [Offset(50, 100), Offset(132, 116), Offset(214, 116), Offset(296, 100)],
    [Offset(173, 44)],
  ]),
  '3-5-2': FormationLayout([
    [Offset(80, 264), Offset(173, 264), Offset(266, 264)],
    [
      Offset(48, 144),
      Offset(116, 176),
      Offset(173, 136),
      Offset(230, 176),
      Offset(298, 144)
    ],
    [Offset(124, 48), Offset(222, 48)],
  ]),
  '4-2-4': FormationLayout([
    [Offset(48, 220), Offset(132, 252), Offset(214, 252), Offset(298, 220)],
    [Offset(132, 152), Offset(214, 152)],
    [Offset(48, 88), Offset(124, 48), Offset(222, 48), Offset(298, 88)],
  ]),
  '5-2-3': FormationLayout([
    [
      Offset(45, 224),
      Offset(107, 256),
      Offset(173, 256),
      Offset(239, 256),
      Offset(295, 224)
    ],
    [Offset(120, 152), Offset(226, 152)],
    [Offset(48, 72), Offset(173, 44), Offset(298, 72)],
  ]),
  '3-4-1-2': FormationLayout([
    [Offset(78, 264), Offset(173, 264), Offset(265.5, 264)],
    [Offset(47, 180), Offset(132, 188), Offset(214, 188), Offset(298, 180)],
    [Offset(173, 120)],
    [Offset(124, 48), Offset(222, 48)],
  ]),
  '4-1-4-1': FormationLayout([
    [Offset(48, 220), Offset(132, 252), Offset(214, 252), Offset(298, 220)],
    [Offset(173, 188)],
    [Offset(48, 104), Offset(132, 120), Offset(214, 120), Offset(298, 104)],
    [Offset(173, 44)],
  ]),
};

FormationLayout buildFallbackFormationLayout(String formation) {
  final counts = formation
      .split('-')
      .map(int.tryParse)
      .whereType<int>()
      .where((count) => count > 0)
      .toList();
  if (counts.fold<int>(0, (sum, count) => sum + count) != 10) {
    return formationLayouts['4-1-2-3']!;
  }

  const bottom = 252.0;
  const top = 52.0;
  final gap = counts.length == 1 ? 0.0 : (bottom - top) / (counts.length - 1);
  return FormationLayout([
    for (var row = 0; row < counts.length; row += 1)
      _evenlySpacedRow(counts[row], bottom - gap * row),
  ]);
}

List<Offset> _evenlySpacedRow(int count, double y) {
  if (count == 1) return [Offset(173, y)];
  const left = 48.0;
  const right = 298.0;
  final gap = (right - left) / (count - 1);
  return [
    for (var index = 0; index < count; index += 1) Offset(left + gap * index, y)
  ];
}

/// 포메이션 이름은 유지하고, 4-3-3의 그림만 4-1-2-3으로 배치해요.
String formationLayoutCode(String formation) {
  final normalized = formation.trim();
  final compact = normalized.replaceAll('-', '');
  if (compact == '433' || compact == '4123') return '4-1-2-3';
  return normalized;
}

/// 두 화면 모두 가운데 미드필더를 뒤에, 양옆 미드필더를 앞에 배치해요.
String formationLayoutSlotKey(String? formation, String slotKey) {
  if (formation?.trim().replaceAll('-', '') != '433') return slotKey;
  return switch (slotKey) {
    '3:1' => '4:1',
    '3:2' => '3:1',
    '3:3' => '4:2',
    '4:1' => '5:1',
    '4:2' => '5:2',
    '4:3' => '5:3',
    _ => slotKey,
  };
}
