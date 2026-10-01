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
