import Foundation

enum AppleSignInState {
    case signedIn
    case signedOut
}

enum AppleSignInError: Error {
    case unexpectedCredentialType
}

// Optional, skippable, never gates core logging functionality — see ARCHITECTURE.md "Account
// model". Wrapped behind a protocol so it's mockable in tests: ASAuthorizationController isn't
// reliably unit-testable in a simulator.
protocol AppleSignInProviding {
    // Nil when no identity has ever been stored — the common case, since sign-in is optional.
    var storedUserIdentifier: String? { get }

    // Presents the system Sign in with Apple sheet and, on success, persists the opaque
    // per-app user identifier to Keychain. Deliberately requests no name/email scopes — nothing
    // in Cyclo consumes either (see ARCHITECTURE.md: User.name is self-entered at onboarding,
    // not pulled from Apple ID).
    func signIn() async throws -> String

    func signOut()

    // Re-checks with Apple whether a previously stored identifier is still valid, e.g. the user
    // revoked Cyclo's access in their Apple ID settings since the last launch.
    func currentSignInState() async -> AppleSignInState
}
