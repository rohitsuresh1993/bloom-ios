import AuthenticationServices
import UIKit

// Concrete, UIKit-backed implementation of `ApplePresentationAnchorProviding`
// (Modules/Auth/ApplePresentationAnchorProviding.swift), scoped to Settings. Near-identical to
// `OnboardingPresentationAnchorProvider` (Modules/Features/Onboarding/
// OnboardingPresentationAnchorProvider.swift), which is explicitly scoped/named to Onboarding
// only per its own doc comment — Settings needs the same window-scene lookup to re-present the
// Sign in with Apple sheet from its own screen, so it gets its own small copy rather than reusing
// that one.
final class SettingsPresentationAnchorProvider: NSObject, ApplePresentationAnchorProviding {
    func presentationAnchor() -> ASPresentationAnchor {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        // Falling back to a fresh window should never actually happen in practice — Settings
        // only ever runs while a scene is active and key — but `ASPresentationAnchor` isn't
        // optional, so there has to be something to return.
        return keyWindow ?? ASPresentationAnchor()
    }
}
