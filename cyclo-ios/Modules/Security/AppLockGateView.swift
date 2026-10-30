import SwiftUI

@MainActor
final class AppLockGateViewModel: ObservableObject {
    @Published var isLocked: Bool
    @Published var pinEntry: String = ""
    @Published var errorMessage: String?

    private let appLockManager: AppLockManaging

    var biometricTypeDescription: String { appLockManager.biometricTypeDescription }
    var isBiometricAuthenticationAvailable: Bool { appLockManager.isBiometricAuthenticationAvailable }

    init(appLockManager: AppLockManaging) {
        self.appLockManager = appLockManager
        self.isLocked = appLockManager.isAppLockEnabled
    }

    func lockIfNeeded() async {
        guard appLockManager.isAppLockEnabled else {
            isLocked = false
            return
        }
        isLocked = true
        await attemptBiometricUnlock()
    }

    func lock() {
        guard appLockManager.isAppLockEnabled else { return }
        isLocked = true
    }

    func attemptBiometricUnlock() async {
        guard appLockManager.isBiometricAuthenticationAvailable else { return }
        // A failed/cancelled biometric attempt isn't fatal — the PIN field stays available.
        if let unlocked = try? await appLockManager.unlockWithBiometrics(), unlocked {
            isLocked = false
            errorMessage = nil
        }
    }

    func submitPIN() {
        if appLockManager.unlockWithPIN(pinEntry) {
            isLocked = false
            errorMessage = nil
        } else {
            errorMessage = "Incorrect PIN"
        }
        pinEntry = ""
    }
}

// Presentation-layer gate in front of the root WindowGroup — not a data-layer concern (SwiftData's
// own file protection already covers the store at rest). Renders only `content` when app lock is
// disabled, so it's safe to wrap unconditionally.
struct AppLockGateView<Content: View>: View {
    @StateObject private var viewModel: AppLockGateViewModel
    @Environment(\.scenePhase) private var scenePhase
    private let content: Content

    init(appLockManager: AppLockManaging, @ViewBuilder content: () -> Content) {
        _viewModel = StateObject(wrappedValue: AppLockGateViewModel(appLockManager: appLockManager))
        self.content = content()
    }

    var body: some View {
        ZStack {
            content

            if viewModel.isLocked {
                LockScreenView(viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        .task { await viewModel.lockIfNeeded() }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                viewModel.lock()
            case .active:
                Task { await viewModel.lockIfNeeded() }
            default:
                break
            }
        }
    }
}

private struct LockScreenView: View {
    @ObservedObject var viewModel: AppLockGateViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Cyclo is locked")
                .font(.title2.bold())

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            SecureField("PIN", text: $viewModel.pinEntry)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 200)
                .onSubmit { viewModel.submitPIN() }

            Button("Unlock") { viewModel.submitPIN() }

            if viewModel.isBiometricAuthenticationAvailable {
                Button("Use \(viewModel.biometricTypeDescription)") {
                    Task { await viewModel.attemptBiometricUnlock() }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
