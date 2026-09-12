import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:onetouch/data/auth/google/google_sign_in_identity_service.dart';
import 'package:onetouch/data/auth/google_identity_service.dart';

void main() {
  test('initializes once and returns trimmed ID tokens', () async {
    var initializationCount = 0;
    final tokens = <String?>[' first-token ', 'second-token'];
    final service = GoogleSignInIdentityService.testing(
      initializeSdk: () async => initializationCount++,
      authenticateIdToken: () async => tokens.removeAt(0),
    );

    expect(await service.authenticate(), 'first-token');
    expect(await service.authenticate(), 'second-token');
    expect(initializationCount, 1);
  });

  test('identifies a user-cancelled account picker', () async {
    final sdkError = GoogleSignInException(
      code: GoogleSignInExceptionCode.canceled,
      description: 'User cancelled.',
    );
    final service = GoogleSignInIdentityService.testing(
      initializeSdk: () async {},
      authenticateIdToken: () async => throw sdkError,
    );

    await expectLater(
      service.authenticate(),
      throwsA(
        isA<GoogleIdentityException>()
            .having(
              (error) => error.type,
              'type',
              GoogleIdentityFailureType.cancelled,
            )
            .having((error) => error.cause, 'cause', same(sdkError)),
      ),
    );
  });

  test('identifies missing and blank ID tokens', () async {
    final tokens = <String?>[null, '   '];
    final service = GoogleSignInIdentityService.testing(
      initializeSdk: () async {},
      authenticateIdToken: () async => tokens.removeAt(0),
    );

    for (var i = 0; i < 2; i++) {
      await expectLater(
        service.authenticate(),
        throwsA(
          isA<GoogleIdentityException>().having(
            (error) => error.type,
            'type',
            GoogleIdentityFailureType.missingIdToken,
          ),
        ),
      );
    }
  });

  test('wraps SDK initialization and authentication failures', () async {
    final initializationFailure = GoogleSignInIdentityService.testing(
      initializeSdk: () async => throw StateError('not configured'),
      authenticateIdToken: () async => 'unused',
    );
    final authenticationFailure = GoogleSignInIdentityService.testing(
      initializeSdk: () async {},
      authenticateIdToken: () async => throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.providerConfigurationError,
      ),
    );

    for (final service in [initializationFailure, authenticationFailure]) {
      await expectLater(
        service.authenticate(),
        throwsA(
          isA<GoogleIdentityException>().having(
            (error) => error.type,
            'type',
            GoogleIdentityFailureType.sdk,
          ),
        ),
      );
    }
  });
}
