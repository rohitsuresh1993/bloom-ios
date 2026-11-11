import AuthenticationServices
import UIKit

// Concrete, UIKit-backed implementation of `ApplePresentationAnchorProviding`
// (Modules/Auth/ApplePresentationAnchorProviding.swift). That protocol is deliberately
// UI-framework-agnostic with no default implementation — ARCHITECTURE.md calls out that a future
// Features/Onboarding view supplies one. This is that implementation, scoped to this feature
// since nothing outside onboarding currently needs to present the Sign in with Apple sheet.
final class OnboardingPresentationAnchorProvider: NSObject, ApplePresentationAnchorProviding {
    func presentationAnchor() -> ASPresentationAnchor {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        // Falling back to a fresh window should never actually happen in practice — onboarding
        // only ever runs while a scene is active and key — but `ASPresentationAnchor` isn't
        // optional, so there has to be something to return.
        return keyWindow ?? ASPresentationAnchor()
    }
}
