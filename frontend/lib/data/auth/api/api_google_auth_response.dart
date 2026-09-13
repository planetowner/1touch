class ApiGoogleAuthResponse {
  const ApiGoogleAuthResponse({required this.accessToken});

  final String accessToken;

  factory ApiGoogleAuthResponse.fromJson(Map<String, dynamic> json) {
    final accessToken = json['access_token'];
    if (accessToken is! String || accessToken.trim().isEmpty) {
      throw const FormatException(
        'Expected "access_token" to be a non-empty string.',
      );
    }
    return ApiGoogleAuthResponse(accessToken: accessToken.trim());
  }
}
