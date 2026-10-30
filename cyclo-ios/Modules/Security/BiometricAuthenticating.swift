import Foundation

// Wrapped behind a protocol so it's mockable in tests — LAContext's real biometric prompt isn't
// reliably unit-testable in a simulator.
protocol BiometricAuthenticating {
    // Whether Face ID/Touch ID/Optic ID is available and enrolled on this device right now.
    var isAvailable: Bool { get }

    // Human-readable label for whichever biometry type this device has, for UI copy — callers
    // shouldn't need to branch on biometry type themselves.
    var biometryTypeDescription: String { get }

    func authenticate(reason: String) async throws -> Bool
}
