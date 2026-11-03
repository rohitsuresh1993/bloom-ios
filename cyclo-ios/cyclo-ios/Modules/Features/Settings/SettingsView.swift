import SwiftData
import SwiftUI

// Live-editing settings screen, standard iOS Settings-app feel: every control applies
// immediately when changed (there's nothing to Cancel/Save), so the toolbar is just a single
// Done button to dismiss.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Default params work fine here: all of AppLockManager/AppleSignInManager's state is
    // UserDefaults/Keychain-backed, not in-memory, so this instance stays interchangeable with
    // the one CycloApp constructs for AppLockGateView.
    private let appLockManager: AppLockManaging = AppLockManager()
    private let appleSignInManager: AppleSignInProviding = AppleSignInManager(
        presentationAnchorProvider: SettingsPresentationAnchorProvider()
    )

    // MARK: App Lock

    @State private var isAppLockEnabled = false
    @State private var isPINSet = false
    @State private var showPINFields = false
    @State private var newPIN = ""
    @State private var confirmPIN = ""
    @State private var pinErrorMessage: String?

    // MARK: Sign in with Apple

    @State private var signInState: AppleSignInState = .signedOut
    @State private var signInErrorMessage: String?

    // MARK: HealthKit export

    // Must exactly match HealthKitExporter.exportEnabledDefaultsKey's literal value.
    @AppStorage("cyclo.healthKitExportEnabled") private var isHealthKitExportEnabled = true

    // MARK: Data & Privacy

    @State private var exportFileURL: URL?
    @State private var dataErrorMessage: String?
    @State private var showDeleteConfirmation = false

    // MARK: Appearance

    @AppStorage("cyclo.colorSchemeOverride") private var colorSchemeOverride = "system"

    var body: some View {
        NavigationStack {
            Form {
                appLockSection
                signInSection
                healthKitSection
                dataSection
                aboutSection
                appearanceSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                isAppLockEnabled = appLockManager.isAppLockEnabled
                isPINSet = appLockManager.isPINSet
            }
            .task {
                signInState = await appleSignInManager.currentSignInState()
            }
        }
    }

    // MARK: - App Lock

    private var appLockSection: some View {
        Section {
            Toggle("App Lock", isOn: $isAppLockEnabled)
                .onChange(of: isAppLockEnabled) { _, newValue in
                    if newValue {
                        if !appLockManager.isPINSet {
                            showPINFields = true
                        }
                    } else {
                        appLockManager.disableAppLock()
                        showPINFields = false
                        newPIN = ""
                        confirmPIN = ""
                        pinErrorMessage = nil
                        isPINSet = false
                    }
                }

            if showPINFields {
                SecureField("New PIN", text: $newPIN)
                    .keyboardType(.numberPad)
                SecureField("Confirm PIN", text: $confirmPIN)
                    .keyboardType(.numberPad)

                if let pinErrorMessage {
                    Text(pinErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack {
                    Button("Cancel", role: .cancel) { cancelPINEntry() }
                    Spacer()
                    Button("Set PIN") { submitPIN() }
                }
            } else if isAppLockEnabled && isPINSet {
                Button("Change PIN") { showPINFields = true }
            }

            if appLockManager.isBiometricAuthenticationAvailable {
                Text("\(appLockManager.biometricTypeDescription) will also be available to unlock Cyclo.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("App Lock")
        }
    }

    private func submitPIN() {
        // AppLockManager has no exported minimum-length constant (it's a private `4` inside
        // AppLockManager) — hardcoded here to mirror that private minimum.
        guard newPIN.count >= 4 else {
            pinErrorMessage = "PIN must be at least 4 digits."
            return
        }
        guard newPIN == confirmPIN else {
            pinErrorMessage = "PINs don't match."
            return
        }
        do {
            try appLockManager.enableAppLock(pin: newPIN)
            isAppLockEnabled = true
            isPINSet = true
            showPINFields = false
            newPIN = ""
            confirmPIN = ""
            pinErrorMessage = nil
        } catch {
            pinErrorMessage = "PIN must be at least 4 digits."
        }
    }

    private func cancelPINEntry() {
        showPINFields = false
        newPIN = ""
        confirmPIN = ""
        pinErrorMessage = nil
        // The PIN was never actually set (either a fresh enable the user backed out of, or a
        // "Change PIN" the user backed out of while no PIN existed yet) — don't let the toggle
        // appear on in that case.
        if !appLockManager.isPINSet {
            isAppLockEnabled = false
        }
    }

    // MARK: - Sign in with Apple

    private var signInSection: some View {
        Section {
            Text(signInState == .signedIn ? "Signed in with Apple" : "Not signed in")
                .foregroundStyle(.secondary)

            if let signInErrorMessage {
                Text(signInErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if signInState == .signedOut {
                Button("Sign in with Apple") {
                    Task {
                        do {
                            _ = try await appleSignInManager.signIn()
                            signInState = .signedIn
                            signInErrorMessage = nil
                        } catch {
                            signInErrorMessage = "Sign in with Apple didn't complete. You can try again later."
                        }
                    }
                }
            } else {
                Button("Sign Out", role: .destructive) {
                    appleSignInManager.signOut()
                    signInState = .signedOut
                }
            }
        } header: {
            Text("Sign in with Apple")
        }
    }

    // MARK: - HealthKit export

    private var healthKitSection: some View {
        Section {
            Toggle("Export to Apple Health", isOn: $isHealthKitExportEnabled)
        } header: {
            Text("Health")
        } footer: {
            Text("When on, period flow, ovulation test results, sexual activity, and contraceptive use are mirrored to Apple Health as you log them.")
        }
    }

    // MARK: - Data & Privacy

    private var dataSection: some View {
        Section {
            Button("Export My Data") { exportData() }

            if let exportFileURL {
                ShareLink(item: exportFileURL) {
                    Label("Share Export", systemImage: "square.and.arrow.up")
                }
            }

            if let dataErrorMessage {
                Text(dataErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Delete All My Data", role: .destructive) {
                showDeleteConfirmation = true
            }
        } header: {
            Text("Data & Privacy")
        }
        .confirmationDialog(
            "Delete all your data? This can't be undone.",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive) { deleteAllData() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private struct DataExport: Codable {
        let periods: [PeriodLogDTO]
        let logs: [LogDTO]
    }

    private func exportData() {
        dataErrorMessage = nil
        do {
            let cycleRepository = CycleRepository(modelContext: modelContext)
            let logRepository = LogRepository(modelContext: modelContext)

            let periods = try cycleRepository.allPeriodLogs().map { $0.toDTO() }
            let logs = try logRepository.allLogs().map { $0.toDTO() }
            let export = DataExport(periods: periods, logs: logs)

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(export)

            let timestamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("cyclo-export-\(timestamp).json")
            try data.write(to: fileURL, options: .atomic)

            exportFileURL = fileURL
        } catch {
            dataErrorMessage = "Couldn't export your data. Please try again."
        }
    }

    private func deleteAllData() {
        do {
            for periodLog in try modelContext.fetch(FetchDescriptor<PeriodLog>()) {
                modelContext.delete(periodLog)
            }
            for log in try modelContext.fetch(FetchDescriptor<Log>()) {
                modelContext.delete(log)
            }
            for user in try modelContext.fetch(FetchDescriptor<User>()) {
                modelContext.delete(user)
            }
            try modelContext.save()

            appLockManager.disableAppLock()
            appleSignInManager.signOut()
            UserDefaults.standard.removeObject(forKey: OnboardingViewModel.cycleLengthBucketDefaultsKey)
            // CycloApp's RootRouterView reads this via @AppStorage and will reactively swap back
            // to OnboardingRootView once this sheet dismisses — no further plumbing needed.
            UserDefaults.standard.set(false, forKey: OnboardingViewModel.onboardingCompletedDefaultsKey)

            dismiss()
        } catch {
            dataErrorMessage = "Couldn't delete your data. Please try again."
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    .foregroundStyle(.secondary)
            }

            NavigationLink("Privacy Policy") {
                PrivacyPolicyView()
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section {
            Picker("Appearance", selection: $colorSchemeOverride) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Appearance")
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(PersistenceController.makeContainer(inMemory: true))
}
