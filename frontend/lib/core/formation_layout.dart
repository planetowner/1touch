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
    designSize.height - 60,
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
    // 필드 선수 10명으로 해석할 수 없으면 기본 배치로 돌아가요.
    counts = [4, 1, 2, 3];
  }

  final centerX = FormationLayout.designSize.width / 2;
  // 345 × 392 시안의 줄 간격을 기준으로 다른 줄 수는 사이를 보간해요.
  const rowAnchors = [264.0, 184.0, 116.0, 40.0];

  double rowY(int row) {
    if (counts.length == 1) return rowAnchors.last;
    final anchor = row * (rowAnchors.length - 1) / (counts.length - 1);
    final lower = anchor.floor();
    final upper = anchor.ceil();
    final progress = anchor - lower;
    return rowAnchors[lower] * (1 - progress) + rowAnchors[upper] * progress;
  }

  Offset position(int row, int column) {
    final count = counts[row];
    final middle = (count - 1) / 2;
    final distance = middle == 0 ? 0.0 : (column - middle).abs() / middle;
    final curve = distance * distance;
    final baseY = rowY(row);
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
    } else if (count >= 3) {
      // 네 명 수비의 바깥쪽은 16px, 세 명 공격의 바깥쪽은 12px 휘어요.
      final bend = count * 4.0;
      final edgeCurve = curve * curve;
      y = baseY + (row == counts.length - 1 ? bend : -bend) * edgeCurve;
    } else {
      y = baseY;
    }
    // 345px 시안에서 두 명은 87.5px, 세 명은 220px, 그 이상은 252px 폭에 배치해요.
    // 각 포메이션의 좌표를 따로 저장하지 않고 줄 인원수로 간격을 나눠요.
    final span = switch (count) {
      1 => 0.0,
      2 => 87.5,
      3 => 220.0,
      _ => 252.0,
    };
    return Offset(
      centerX + (column - middle) * span / math.max(1, count - 1),
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
