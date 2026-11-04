import SwiftData
import SwiftUI
import UIKit

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
    @State private var showingPINSheet = false

    // MARK: Sign in with Apple

    @State private var signInState: AppleSignInState = .signedOut
    @State private var signInErrorMessage: String?

    // MARK: HealthKit export

    // Must exactly match HealthKitExporter.exportEnabledDefaultsKey's literal value.
    @AppStorage("cyclo.healthKitExportEnabled") private var isHealthKitExportEnabled = true

    // MARK: Data & Privacy

    @State private var exportFileURL: URL?
    @State private var isShowingShareSheet = false
    @State private var dataErrorMessage: String?
    @State private var showDeleteConfirmation = false

    // MARK: Appearance

    // Mirrors CycloApp's own `@AppStorage` of the same key. Applying `.preferredColorScheme`
    // again here (not just at the app root) is necessary because this view is presented as a
    // `.sheet` — UIKit caches a presented sheet's trait-collection override at presentation
    // time, so a `.preferredColorScheme` change made only at the WindowGroup root doesn't
    // propagate live into an already-presented sheet until it's dismissed and re-presented.
    // Applying it directly within this view's own hierarchy makes it update immediately.
    @AppStorage("cyclo.colorSchemeOverride") private var colorSchemeOverride = "system"

    private var resolvedColorScheme: ColorScheme? {
        switch colorSchemeOverride {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

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
                // Safe to call unconditionally: once authorization is already determined
                // (granted or denied), this is a silent no-op with no UI shown — it only
                // actually prompts the first time, which is exactly when we want it to.
                if isHealthKitExportEnabled {
                    try? await HealthKitExporter().requestAuthorization()
                }
            }
        }
        .preferredColorScheme(resolvedColorScheme)
    }

    // MARK: - App Lock

    // PIN entry is presented as its own `.sheet` rather than inline rows within this Section.
    // It used to be inline rows that appeared/disappeared in the same Section as the Toggle —
    // SwiftUI's Form/List row-diffing animation for that kind of same-transaction insert could
    // visually desync the Toggle's displayed state from `isAppLockEnabled` (it would appear to
    // snap back off right as "Set PIN" was tapped, regardless of whether the PIN was valid). A
    // sheet sidesteps that List-diffing entirely and is the more standard pattern anyway.
    private var appLockSection: some View {
        Section {
            Toggle("App Lock", isOn: $isAppLockEnabled)
                .onChange(of: isAppLockEnabled) { _, newValue in
                    if newValue {
                        if appLockManager.isPINSet {
                            isPINSet = true
                        } else {
                            showingPINSheet = true
                        }
                    } else {
                        appLockManager.disableAppLock()
                        isPINSet = false
                    }
                }

            if isAppLockEnabled && isPINSet {
                Button("Change PIN") { showingPINSheet = true }
            }

            if appLockManager.isBiometricAuthenticationAvailable {
                Text("\(appLockManager.biometricTypeDescription) will also be available to unlock Cyclo.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("App Lock")
        }
        .sheet(isPresented: $showingPINSheet) {
            PINEntrySheet(
                onSave: { pin in
                    do {
                        try appLockManager.enableAppLock(pin: pin)
                        isAppLockEnabled = true
                        isPINSet = true
                        return nil
                    } catch {
                        return "PIN must be at least 4 digits."
                    }
                },
                onCancel: {
                    // The PIN was never actually set (either a fresh enable the user backed out
                    // of, or a "Change PIN" backed out of while no PIN existed yet) — don't let
                    // the toggle appear on in that case.
                    if !appLockManager.isPINSet {
                        isAppLockEnabled = false
                    }
                }
            )
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
                .onChange(of: isHealthKitExportEnabled) { _, newValue in
                    guard newValue else { return }
                    Task { try? await HealthKitExporter().requestAuthorization() }
                }
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
        // Presented directly via UIActivityViewController rather than ShareLink: ShareLink only
        // appeared as a *second*, newly-inserted row after "Export My Data" was tapped, and
        // tapping that freshly-inserted row unreliably did nothing — the same class of List/Form
        // row-insertion tap issue seen elsewhere in this app (see PeriodDayRangeCalendar's
        // comments). One tap now both exports and presents the share sheet.
        .sheet(isPresented: $isShowingShareSheet) {
            if let exportFileURL {
                ActivityShareSheet(activityItems: [exportFileURL])
            }
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
            isShowingShareSheet = true
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

// MARK: - PIN entry sheet

private struct PINEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    // Returns an error message to display, or nil on success (in which case this sheet dismisses
    // itself — the caller is still responsible for updating its own PIN/enabled state).
    let onSave: (String) -> String?
    let onCancel: () -> Void

    @State private var newPIN = ""
    @State private var confirmPIN = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("New PIN", text: $newPIN)
                        .keyboardType(.numberPad)
                    SecureField("Confirm PIN", text: $confirmPIN)
                        .keyboardType(.numberPad)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("At least 4 digits.")
                }
            }
            .navigationTitle("Set PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set PIN") { submit() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func submit() {
        guard newPIN == confirmPIN else {
            errorMessage = "PINs don't match."
            return
        }
        if let saveError = onSave(newPIN) {
            errorMessage = saveError
        } else {
            dismiss()
        }
    }
}

// MARK: - Share sheet

// A thin UIActivityViewController wrapper — used instead of ShareLink so the share sheet
// presents directly from the same tap that triggers the export, with no intermediate row.
private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
        .modelContainer(PersistenceController.makeContainer(inMemory: true))
}
