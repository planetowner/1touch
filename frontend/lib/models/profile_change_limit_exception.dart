// 닉네임과 최애팀은 같은 변경 제한 응답을 사용해요.
class ProfileChangeLimitException implements Exception {
  const ProfileChangeLimitException({
    required this.availableAt,
    required this.maxChanges,
    required this.windowDays,
  });

  final DateTime availableAt;
  final int maxChanges;
  final int windowDays;

  factory ProfileChangeLimitException.fromJson(Map<String, dynamic> detail) {
    return ProfileChangeLimitException(
      availableAt: DateTime.parse(detail['available_at'] as String).toUtc(),
      maxChanges: detail['max_changes'] as int,
      windowDays: detail['window_days'] as int,
    );
  }
}
