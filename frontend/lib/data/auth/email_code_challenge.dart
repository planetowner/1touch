class EmailCodeChallenge {
  const EmailCodeChallenge({
    required this.challengeId,
    required this.expiresInSeconds,
  });

  final String challengeId;
  final int expiresInSeconds;

  factory EmailCodeChallenge.fromJson(Map<String, dynamic> json) {
    final challengeId = json['challenge_id'];
    final expiresIn = json['expires_in'];
    if (challengeId is! String || challengeId.trim().isEmpty) {
      throw const FormatException(
        'Email-code response is missing challenge_id.',
      );
    }
    if (expiresIn is! int || expiresIn <= 0) {
      throw const FormatException(
        'Email-code response has an invalid expires_in value.',
      );
    }
    return EmailCodeChallenge(
      challengeId: challengeId,
      expiresInSeconds: expiresIn,
    );
  }
}
