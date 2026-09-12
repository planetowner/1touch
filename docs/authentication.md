# Authentication Architecture

## Status

This document describes the intended production authentication architecture. It
is a reference for future frontend and backend work; the complete flow is not
implemented yet.

The verified Google flow now supersedes the older generic Firebase social-login
proposal later in this document:

- iOS uses bundle ID `com.onetouch.football` and Google Sign-In SDK 7.2.
- `GoogleSignInIdentityService` initializes the SDK once, opens the account
  picker, and returns the Google ID token.
- `ApiGoogleAuthRepository` sends that token to `POST /v1/auth/google` as
  `{"id_token":"..."}` and returns the backend `access_token`.
- The Google onboarding button now calls the complete SDK-to-backend flow. It
  shows progress, ignores user cancellation, and presents recoverable failures.
- `AuthService` now coordinates those boundaries and establishes an in-memory
  `AuthSession` only after the backend exchange succeeds.
- `auth_repository_provider.dart` is the composition root for the real Google
  SDK service, auth API repository, in-memory session, and overall service.
- Signed-out authentication configuration requires only `API_BASE_URI`; it
  does not depend on the temporary `API_SESSION_TOKEN` used by protected API
  repositories during migration.
- Session persistence and replacement of the temporary compile-time bearer
  token remain future work.

Apple and Kakao contracts must be verified independently before extending the
overall authentication repository. Do not infer them from the Google flow.

## Native Google account picker

Flutter does not draw or imitate the Google account popup. A user tap will
eventually call `GoogleSignIn.instance.authenticate()` through
`GoogleSignInIdentityService`. The Flutter plugin forwards that call over the
platform boundary to Google's native iOS SDK, which presents the Google-owned
account and consent interface above the Flutter application.

After the user chooses an account, Google redirects back to the app through the
configured reversed URL scheme. The iOS plugin receives that callback and
completes the Dart `authenticate()` future with a `GoogleSignInAccount`. The
wrapper immediately reads `account.authentication.idToken` and passes it to the
1Touch authentication repository.

```text
Flutter Google button
        |
        | authenticate()
        v
google_sign_in Flutter plugin
        |
        | platform channel
        v
Google Sign-In SDK for iOS
        |
        | native account/consent UI
        | reversed URL-scheme callback
        v
Google ID token
        |
        | POST /v1/auth/google
        v
1Touch access token
```

The exact Google screen can vary depending on whether accounts are already
known, consent was previously granted, or the user cancelled. Cancellation is
returned as a Google SDK error and is mapped to
`GoogleIdentityFailureType.cancelled`. The popup is not visible yet because the
existing onboarding button has not been connected to the identity service.

The Flutter application currently contains mock authentication behavior:

- The Apple and Facebook buttons continue onboarding without authenticating.
- Google currently routes to the existing Welcome page after authentication;
  `/v1/users/me` account-state routing is not connected yet.
- Email signup validates the form, waits briefly, and opens the verification
  screen without creating an account.
- The verification screen accepts any value containing at least four
  characters.

Firebase is already initialized in the application, and the project includes
`firebase_auth`. Production work should replace the mock handlers without
redesigning the existing screens.

## Architecture Decision

Use Firebase Authentication for email/password and supported social-provider
authentication. Use trusted backend code, preferably Firebase callable Cloud
Functions, for the custom six-digit email verification code.

The Flutter application must not generate or validate a production email code.
Doing so would expose the expected value and allow a modified client to bypass
verification.

### Responsibility boundaries

| Flutter application | Firebase Authentication | Trusted backend |
| --- | --- | --- |
| Render authentication screens | Create email/password users | Generate email codes |
| Validate input format | Authenticate provider credentials | Hash and store codes |
| Start social-provider flows | Maintain the user session | Enforce expiry and rate limits |
| Call backend functions | Issue ID tokens | Send verification emails |
| Display loading and errors | Expose `emailVerified` state | Verify submitted codes |
| Route users based on auth state | Refresh authentication claims | Mark emails as verified |

If the application later introduces its own API, that API must verify the
Firebase ID token on every authenticated request. It must not trust a UID or
email supplied separately by the client.

## Email/Password Signup Flow

```text
Flutter signup screen
        |
        | createUserWithEmailAndPassword(email, password)
        v
Firebase Authentication
        |
        | UID + signed-in session (emailVerified = false)
        v
Flutter calls sendEmailOtp()
        |
        v
Callable Cloud Function
        |-- derives UID and email from authenticated Firebase user
        |-- checks resend/rate limits
        |-- generates a secure six-digit code
        |-- stores a hash with expiry and attempt count
        `-- sends the code through the configured email provider
        |
        v
Flutter verification screen
        |
        | verifyEmailOtp(code)
        v
Callable Cloud Function
        |-- validates code, expiry, attempts, and single-use state
        |-- marks Firebase Auth emailVerified = true
        `-- consumes the verification record
        |
        v
Flutter reloads the user and refreshes the ID token
        |
        v
Continue onboarding
```

### Signup button sequence

When the user presses **Sign Up**:

1. Flutter validates required fields, the email format, password requirements,
   and acceptance of the terms.
2. Flutter calls Firebase Authentication's
   `createUserWithEmailAndPassword`. Firebase receives and stores the password;
   custom Cloud Functions must never receive it.
3. Firebase creates the account and returns an authenticated session whose
   `emailVerified` value is `false`.
4. Flutter calls the authenticated `sendEmailOtp` function without sending an
   email address in the request.
5. The function obtains the UID from its authentication context and obtains the
   canonical email from Firebase Authentication.
6. After the backend confirms that the email was queued, Flutter opens the
   existing verification screen.
7. If account creation or email delivery fails, Flutter stays on the current
   screen and presents a recoverable error.

The first name, last name, and username should be written to a protected user
profile only after the team defines its profile schema. They may be saved as a
pending profile keyed by UID, but they must not be treated as trusted simply
because they came from an authenticated client.

## Six-Digit Code Requirements

The backend must:

- Generate the code with a cryptographically secure random-number generator.
- Produce exactly six decimal digits, including codes with leading zeroes.
- Store an HMAC or equivalent keyed hash rather than the plain code.
- Keep the hashing key in server-managed secrets, never in source control or
  the Flutter application.
- Expire a code after ten minutes.
- Allow no more than five failed verification attempts per issued code.
- Enforce at least a 60-second resend cooldown.
- Apply longer-window rate limits per UID and email address.
- Invalidate previous codes when a new code is issued.
- Consume a successful code atomically so it cannot be reused.
- Avoid responses that reveal whether an arbitrary email address has an
  account.

Suggested server-only record:

```text
emailVerificationCodes/{uid}
  codeHash: string
  expiresAt: timestamp
  attempts: number
  lastSentAt: timestamp
  consumed: boolean
```

Clients must have no direct read or write access to these records. Firebase
Admin code can access them independently of client Security Rules.

## Proposed Backend Contract

The exact response structure may be adjusted when the backend is implemented,
but the frontend should depend on a small, stable contract.

### `sendEmailOtp()`

- Authentication: required Firebase user
- Request data: none
- Email source: Firebase Authentication record for the authenticated UID
- Success response:

```json
{
  "sent": true,
  "expiresInSeconds": 600,
  "retryAfterSeconds": 60
}
```

Calling the same function again acts as **Send again**. A separate resend
function is unnecessary unless backend requirements later differ.

### `verifyEmailOtp(code)`

- Authentication: required Firebase user
- Request data:

```json
{
  "code": "038421"
}
```

- Success response:

```json
{
  "verified": true
}
```

The backend must compare hashes using a timing-safe operation and update the
attempt count atomically. On success, it uses the Firebase Admin SDK to set the
user's `emailVerified` property to `true` and then consumes the code.

Frontend-visible errors should distinguish at least:

- Invalid code
- Expired code
- Too many attempts
- Resend cooldown
- Temporary email-delivery or network failure

Error messages should be actionable without exposing server internals.

## Frontend Integration

Authentication screens should call an `AuthService` rather than embedding
Firebase and callable-function logic throughout widgets. This lets UI tests use
a fake implementation and keeps production authentication replaceable.

The service should cover these operations conceptually:

```dart
abstract interface class AuthService {
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<void> sendEmailOtp();
  Future<void> verifyEmailOtp(String code);
  Future<void> signInWithSocialProvider(SocialProvider provider);
  Future<void> signOut();
}
```

After successful OTP verification, Flutter must reload the current Firebase
user and force-refresh its ID token before checking `emailVerified`. Without a
token refresh, database rules or a custom API may continue seeing the old
unverified claim until the cached token expires.

The verification field should accept exactly six numeric characters. This is
input validation only; the backend remains the authority.

## Returning and Interrupted Users

Authentication routing must handle these states:

| State | Destination |
| --- | --- |
| Signed out | Authentication/onboarding entry |
| Signed in with unverified email | Email verification screen |
| Signed in and verified, onboarding incomplete | Next onboarding step |
| Signed in, verified, onboarding complete | Main application |

If the user closes the application after signup, the next launch must detect
the unverified Firebase user and return to verification. **Send again** calls
`sendEmailOtp` and respects the server-provided cooldown.

A scheduled backend task may delete unverified accounts and pending profiles
after an agreed retention period, such as 24 or 48 hours. The product and
privacy requirements must define that period before implementation.

## Social Login

Google, Apple, and Facebook authentication starts in Flutter through the
provider's supported SDK or Firebase provider flow. The resulting provider
credential is exchanged with Firebase Authentication, which creates or signs
in the Firebase user.

Social users normally skip the custom six-digit email-code flow. Routing must
use the resulting Firebase account state and the product's provider policy
rather than assuming every provider always supplies a usable, verified email.

Before enabling multiple providers, define account-linking behavior for cases
where the same person uses the same email with different providers. Never merge
accounts using only an unverified email received from the client.

## Authorization and Security Rules

An authenticated Firebase session does not mean the email has been verified.
After email/password signup, the user is authenticated while
`emailVerified == false`.

Protected Firebase data must require a verified token, conceptually:

```text
auth != null && auth.token.email_verified == true
```

Apply the expression using the syntax of the selected Firebase database
product. OTP records must deny all client reads and writes. Public or
pre-verification data should be explicitly scoped rather than making the whole
database accessible.

Flutter route guards improve user experience but are not a security boundary.
A modified client can bypass UI navigation, so authorization must be enforced
by Firebase Security Rules and by any custom backend.

## Email Delivery

The backend needs a transactional email service such as Amazon SES, SendGrid,
Mailgun, Resend, or SMTP through Firebase's Trigger Email extension. Provider
API keys and SMTP credentials must be stored in server-managed secrets.

The verification email should include:

- The six-digit code
- The expiration period
- A notice to ignore the message if the recipient did not sign up
- No password or other sensitive account data

Delivery logs must not record the plain verification code.

## Mock Authentication

A fake `AuthService` may accept a documented test code such as `123456` for
local UI development. It must:

- Be clearly labeled as mock behavior.
- Be selected through a development-only configuration.
- Never be enabled in production builds.
- Never share storage or logic with production OTP verification.

Passing the mock flow proves only that the screens and navigation work; it does
not test identity, email delivery, backend verification, or authorization.

## Implementation Checklist

### Backend

- [ ] Enable email/password authentication in Firebase.
- [ ] Choose and configure an email-delivery provider.
- [ ] Implement `sendEmailOtp` as an authenticated callable function.
- [ ] Implement `verifyEmailOtp` with atomic attempt and consumption handling.
- [ ] Store OTP hashing and email-provider keys in server-managed secrets.
- [ ] Add expiry, resend cooldown, attempt limits, and longer-window rate limits.
- [ ] Update Firebase Authentication's `emailVerified` value on success.
- [ ] Protect OTP storage from all client access.
- [ ] Add Security Rules for verified-only protected data.
- [ ] Add automated tests for success, incorrect code, expiry, reuse, cooldown,
      concurrency, and abuse limits.

### Flutter

- [ ] Introduce the `AuthService` boundary.
- [ ] Replace the signup mock delay with Firebase account creation and
      `sendEmailOtp`.
- [ ] Restrict verification input to exactly six digits.
- [ ] Replace the verification mock with `verifyEmailOtp`.
- [ ] Connect **Send again** to `sendEmailOtp` and display its cooldown.
- [ ] Reload the Firebase user and force-refresh the ID token after success.
- [ ] Add authentication routing for signed-out, unverified, verified, and
      onboarding-complete states.
- [ ] Present actionable errors and preserve user input after recoverable
      failures.
- [ ] Add widget and integration tests using a fake `AuthService`.
- [ ] Configure and test each social provider separately on supported platforms.

## Definition of Done

Email verification is complete only when:

1. A real email is delivered with a secure six-digit code.
2. Invalid, expired, reused, and rate-limited codes are rejected server-side.
3. A successful code sets Firebase `emailVerified` to `true`.
4. Flutter refreshes the user/token and routes correctly.
5. Unverified users cannot access protected data even with a modified client.
6. Automated tests cover the primary success and abuse scenarios.
