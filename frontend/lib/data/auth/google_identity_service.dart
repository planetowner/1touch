enum GoogleIdentityFailureType {
  cancelled,
  missingIdToken,
  sdk,
}

class GoogleIdentityException implements Exception {
  const GoogleIdentityException(this.type, {this.cause});

  final GoogleIdentityFailureType type;
  final Object? cause;

  @override
  String toString() => 'GoogleIdentityException($type, cause: $cause)';
}

abstract interface class GoogleIdentityService {
  Future<String> authenticate();
}
