import AuthenticationServices
import Foundation

final class AppleSignInManager: NSObject, AppleSignInProviding {
    private let keychainService: String
    private let keychainAccount = "appleUserIdentifier"
    private var signInContinuation: CheckedContinuation<String, Error>?

    var presentationAnchorProvider: ApplePresentationAnchorProviding

    init(
        presentationAnchorProvider: ApplePresentationAnchorProviding,
        keychainService: String = "bloom.bloom-ios.auth"
    ) {
        self.keychainService = keychainService
        self.presentationAnchorProvider = presentationAnchorProvider
    }

    var storedUserIdentifier: String? {
        KeychainStore.read(service: keychainService, account: keychainAccount)
    }

    func signIn() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            signInContinuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = []

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func signOut() {
        KeychainStore.delete(service: keychainService, account: keychainAccount)
    }

    func currentSignInState() async -> AppleSignInState {
        guard let identifier = storedUserIdentifier else { return .signedOut }

        return await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: identifier) { state, _ in
                continuation.resume(returning: state == .authorized ? .signedIn : .signedOut)
            }
        }
    }
}

extension AppleSignInManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        defer { signInContinuation = nil }

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            signInContinuation?.resume(throwing: AppleSignInError.unexpectedCredentialType)
            return
        }

        let identifier = credential.user
        KeychainStore.save(identifier, service: keychainService, account: keychainAccount)
        signInContinuation?.resume(returning: identifier)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        signInContinuation?.resume(throwing: error)
        signInContinuation = nil
    }
}

extension AppleSignInManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchorProvider.presentationAnchor()
    }
}
