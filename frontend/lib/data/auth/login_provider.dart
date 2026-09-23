enum LoginProvider {
  kakao('Kakao'),
  line('LINE'),
  apple('Apple'),
  google('Google'),
  email('email');

  const LoginProvider(this.displayName);
  final String displayName;

  String get label => 'Continue with $displayName';
}

class LoginOptions {
  const LoginOptions({required this.recommended, this.other = const []});

  final List<LoginProvider> recommended;
  final List<LoginProvider> other;

  factory LoginOptions.fromJson(Map<String, dynamic> json) {
    List<LoginProvider> parse(Object? value) => (value as List)
        .map((name) => LoginProvider.values.byName(name as String))
        .toList(growable: false);
    return LoginOptions(
      recommended: parse(json['providers']),
      other: parse(json['other_providers'] ?? const []),
    );
  }
}
