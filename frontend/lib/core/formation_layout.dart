import 'dart:math' as math;
import 'dart:ui';

/// 베스트 11과 경기 라인업이 같은 기준 좌표를 사용해요.
/// 선수 간격은 줄의 인원수로 계산하고, 실제 화면 크기에 맞춰 조정해요.
class FormationLayout {
  const FormationLayout(this.rows);

  factory FormationLayout.forFormation(String formation) {
    return buildFormationLayout(formationLayoutCode(formation));
  }

  static const Size designSize = Size(345, 392);
  static final Offset goalkeeper = Offset(
    designSize.width / 2,
    designSize.height * 7 / 8,
  );

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

FormationLayout buildFormationLayout(String formation) {
  var counts = formation
      .split('-')
      .map(int.tryParse)
      .whereType<int>()
      .where((count) => count > 0)
      .toList();
  if (counts.fold<int>(0, (sum, count) => sum + count) != 10) {
    counts = [4, 1, 2, 3];
  }

  final centerX = FormationLayout.designSize.width / 2;
  final sideInset = FormationLayout.designSize.width / 8;
  final usableWidth = FormationLayout.designSize.width - 2 * sideInset;
  final attackerY = FormationLayout.designSize.height / 8;
  final defenderY = FormationLayout.designSize.height * 0.65;
  final rowGap =
      counts.length == 1 ? 0.0 : (defenderY - attackerY) / (counts.length - 1);

  Offset position(int row, int column) {
    final count = counts[row];
    final middle = (count - 1) / 2;
    final distance = middle == 0 ? 0.0 : (column - middle).abs() / middle;
    final curve = distance * distance;
    final baseY = defenderY - rowGap * row;
    final height = FormationLayout.designSize.height;
    double y;
    if (count == 5 && row == 1 && counts.length == 3) {
      // 미드필더가 5명일 때 중앙과 양쪽 윙백을 안쪽 미드필더보다 앞에 둬요.
      final outerShift = counts.first == 3 ? height * 0.02 : -height * 0.06;
      final wave = math.sin(math.pi * distance);
      y = baseY -
          height * 0.04 +
          height * 0.10 * wave * wave +
          outerShift * curve;
    } else if (row == counts.length - 1 && count >= 3) {
      final bend = height * math.min(0.10, 0.07 + 0.03 * (count - 3));
      y = baseY + bend * curve;
    } else {
      final bend = row == 0
          ? height * math.min(0.08, 0.02 + 0.06 * (count - 3))
          : height * math.min(0.08, 0.04 * (count - 2));
      y = baseY - math.max(0.0, bend) * curve;
    }
    return Offset(
      centerX + (column - middle) * usableWidth / math.max(2, count - 1),
      y,
    );
  }

  return FormationLayout([
    for (var row = 0; row < counts.length; row++)
      [
        for (var column = 0; column < counts[row]; column++)
          position(row, column),
      ],
  ]);
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
