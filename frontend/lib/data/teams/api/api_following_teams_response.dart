class ApiFollowingTeamsUpdateResponse {
  const ApiFollowingTeamsUpdateResponse({required this.ok});

  final bool ok;

  factory ApiFollowingTeamsUpdateResponse.fromJson(Map<String, dynamic> json) {
    final value = json['ok'];
    if (value is! bool) {
      throw const FormatException('Expected required boolean field "ok".');
    }
    return ApiFollowingTeamsUpdateResponse(ok: value);
  }
}

class ApiFavoriteTeamCooldownResponse {
  const ApiFavoriteTeamCooldownResponse({
    required this.message,
    required this.availableAt,
  });

  final String message;
  final String availableAt;

  factory ApiFavoriteTeamCooldownResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final detail = json['detail'];
    if (detail is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the favorite-team cooldown detail to be an object.',
      );
    }
    final message = detail['message'];
    final availableAt = detail['available_at'];
    if (message is! String || message.trim().isEmpty) {
      throw const FormatException(
        'Expected a non-empty favorite-team cooldown message.',
      );
    }
    if (availableAt is! String || availableAt.trim().isEmpty) {
      throw const FormatException(
        'Expected a favorite-team cooldown available_at value.',
      );
    }
    return ApiFavoriteTeamCooldownResponse(
      message: message.trim(),
      availableAt: availableAt.trim(),
    );
  }
}
