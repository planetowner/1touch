import 'package:onetouch/models/community_ban.dart';

/// GET /community/suspension의 종료 시각과 사유 코드를 화면용 상태로 바꿔요.
class ApiCommunityBanResponse {
  const ApiCommunityBanResponse(this.ban);

  final CommunityBanStatus? ban;

  factory ApiCommunityBanResponse.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('suspension')) {
      throw const FormatException('Expected suspension field.');
    }
    final value = json['suspension'];
    if (value == null) return const ApiCommunityBanResponse(null);
    if (value is! Map<String, dynamic> || !value.containsKey('reason')) {
      throw const FormatException(
          'Expected suspension with reason and ends_at.');
    }
    final rawEnd = value['ends_at'];
    final endsAt = rawEnd is String ? DateTime.tryParse(rawEnd) : null;
    if (endsAt == null || !endsAt.isUtc) {
      throw const FormatException('Expected ends_at with a UTC offset.');
    }
    CommunityBanReason? reason;
    final code = value['reason'];
    if (code != null) {
      for (final candidate in CommunityBanReason.values) {
        if (candidate.code == code) reason = candidate;
      }
      if (reason == null) {
        throw FormatException('Unknown community suspension reason: $code');
      }
    }
    return ApiCommunityBanResponse(
        CommunityBanStatus(reason: reason, endsAt: endsAt.toUtc()));
  }
}
