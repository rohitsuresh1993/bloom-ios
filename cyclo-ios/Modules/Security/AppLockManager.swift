import Foundation

final class AppLockManager: AppLockManaging {
    // Short enough to stay quick to enter, long enough it's not trivially guessable as the sole
    // fallback when biometrics are unavailable.
    private static let minimumPINLength = 4

    private let biometricAuthenticator: BiometricAuthenticating
    private let keychainService: String
    private let pinAccount = "appLockPIN"
    private let isEnabledDefaultsKey = "cyclo.appLockEnabled"
    private let userDefaults: UserDefaults

    init(
        biometricAuthenticator: BiometricAuthenticating = BiometricAuthenticator(),
        keychainService: String = "cyclo.cyclo-ios.security",
        userDefaults: UserDefaults = .standard
    ) {
        self.biometricAuthenticator = biometricAuthenticator
        self.keychainService = keychainService
        self.userDefaults = userDefaults
    }

    var isAppLockEnabled: Bool {
        userDefaults.bool(forKey: isEnabledDefaultsKey)
    }

    var isPINSet: Bool {
        KeychainStore.read(service: keychainService, account: pinAccount) != nil
    }

    var isBiometricAuthenticationAvailable: Bool {
        biometricAuthenticator.isAvailable
    }

    var biometricTypeDescription: String {
        biometricAuthenticator.biometryTypeDescription
    }

    func enableAppLock(pin: String) throws {
        guard pin.count >= Self.minimumPINLength else { throw AppLockError.pinTooShort }
        KeychainStore.save(pin, service: keychainService, account: pinAccount)
        userDefaults.set(true, forKey: isEnabledDefaultsKey)
    }

    func disableAppLock() {
        KeychainStore.delete(service: keychainService, account: pinAccount)
        userDefaults.set(false, forKey: isEnabledDefaultsKey)
    }

    func unlockWithBiometrics() async throws -> Bool {
        try await biometricAuthenticator.authenticate(reason: "Unlock Cyclo")
    }

    func unlockWithPIN(_ pin: String) -> Bool {
        guard let storedPIN = KeychainStore.read(service: keychainService, account: pinAccount) else {
            return false
        }
        return pin == storedPIN
    }
}
