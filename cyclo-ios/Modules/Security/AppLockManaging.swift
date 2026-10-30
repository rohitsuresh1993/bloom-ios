import Foundation

enum AppLockError: Error {
    case pinTooShort
}

// Optional, user-enabled biometric app-lock with a Keychain-backed PIN fallback for when
// biometrics are unavailable. Implemented as a presentation-layer gate (AppLockGateView), not a
// data-layer concern — SwiftData's own file protection already covers the store at rest.
protocol AppLockManaging {
    var isAppLockEnabled: Bool { get }
    var isPINSet: Bool { get }
    var isBiometricAuthenticationAvailable: Bool { get }
    var biometricTypeDescription: String { get }

    func enableAppLock(pin: String) throws
    func disableAppLock()
    func unlockWithBiometrics() async throws -> Bool
    func unlockWithPIN(_ pin: String) -> Bool
}
