import AuthenticationServices

// ASAuthorizationController needs a window to present its sheet from. Pulled behind a protocol,
// deliberately with no UIKit-based default implementation here — Auth stays UI-framework-
// agnostic, same convention as Prediction. Features/Onboarding supplies a concrete
// UIWindowScene-backed implementation once that UI exists.
protocol ApplePresentationAnchorProviding: AnyObject {
    func presentationAnchor() -> ASPresentationAnchor
}
