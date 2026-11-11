//
//  ProfilePage.swift
//  bloom-ios
//
//  Profile tab: the old standalone ProfileView and SettingsView screens folded into one, now
//  that Profile is a persistent tab (RootTabView) instead of two separate sheets off Home's
//  TopBar. User-submitted profile fields (name, date of birth, known conditions, cycle-length
//  bucket) render as plain text until "Edit" is tapped — Settings' app-level controls (sign in,
//  HealthKit export, data export/delete, appearance) stay live-editing throughout, same as
//  before, since those aren't "submitted info" in the same sense.
//
//  Root entry point: this is a tab root (see RootTabView), not presented via `.sheet`.
//

import SwiftData
import SwiftUI

struct ProfilePage: View {
    @Environment(\.modelContext) private var modelContext

    private let appleSignInManager: AppleSignInProviding = AppleSignInManager(
        presentationAnchorProvider: ProfilePresentationAnchorProvider()
    )

    // MARK: Profile (edit-gated)

    @State private var name = ""
    @State private var dateOfBirth = Date()
    @State private var knownConditions: Set<MenstrualCondition> = []
    @State private var cycleLengthBucket: SelfReportedCycleLengthBucket?
    @State private var showingEditProfile = false
    @State private var hasLoadedProfile = false
    @State private var profileErrorMessage: String?

    // MARK: Sign in with Apple

    @State private var signInState: AppleSignInState = .signedOut
    @State private var signInErrorMessage: String?

    // MARK: HealthKit export

    // Must exactly match HealthKitExporter.exportEnabledDefaultsKey's literal value.
    @AppStorage("bloom.healthKitExportEnabled") private var isHealthKitExportEnabled = true

    // MARK: Data & Privacy

    @State private var exportFileURL: URL?
    @State private var isShowingShareSheet = false
    @State private var dataErrorMessage: String?
    @State private var showDeleteConfirmation = false

    // MARK: Appearance

    @AppStorage("bloom.colorSchemeOverride") private var colorSchemeOverride = "system"

    private var userRepository: UserRepository { UserRepository(modelContext: modelContext) }

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                appLockSection
                signInSection
                healthKitSection
                dataSection
                aboutSection
                appearanceSection
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: loadProfile)
            .task {
                signInState = await appleSignInManager.currentSignInState()
                // Safe to call unconditionally: once authorization is already determined
                // (granted or denied), this is a silent no-op with no UI shown — it only
                // actually prompts the first time, which is exactly when we want it to.
                if isHealthKitExportEnabled {
                    try? await HealthKitExporter().requestAuthorization()
                }
            }
            // Attached to the Form itself, not nested inside profileSection's Section — a
            // `.sheet` nested inside a Form Section has caused this exact "presents then
            // immediately dismisses" failure elsewhere in this app before (see SettingsView's
            // git history for the App Lock PIN sheet). This is the stable placement.
            .sheet(isPresented: $showingEditProfile) {
                EditProfileSheet(
                    name: name,
                    dateOfBirth: dateOfBirth,
                    knownConditions: knownConditions,
                    cycleLengthBucket: cycleLengthBucket,
                    onSave: saveProfile
                )
            }
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section {
            if let profileErrorMessage {
                Text(profileErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            LabeledContent("Name", value: name.isEmpty ? "Not set" : name)
            LabeledContent("Date of Birth", value: dateOfBirth.formatted(date: .abbreviated, time: .omitted))
            LabeledContent("Known Conditions", value: knownConditionsSummary)
            LabeledContent("Cycle Length", value: cycleLengthBucket.map(Self.label(forBucket:)) ?? "Not set")
        } header: {
            HStack {
                Text("Profile")
                Spacer()
                Button("Edit") { showingEditProfile = true }
                    .font(.caption.weight(.semibold))
                    .textCase(nil)
            }
        }
    }

    private var knownConditionsSummary: String {
        guard !knownConditions.isEmpty else { return "None" }
        return knownConditions.map(Self.label(forCondition:)).sorted().joined(separator: ", ")
    }

    private func loadProfile() {
        guard !hasLoadedProfile else { return }
        hasLoadedProfile = true
        do {
            let user = try userRepository.currentUser()
            name = user.name
            dateOfBirth = user.dateOfBirth
            knownConditions = Set(user.knownConditions)
            cycleLengthBucket = SelfReportedCycleLengthBucket(
                rawValue: UserDefaults.standard.string(forKey: OnboardingViewModel.cycleLengthBucketDefaultsKey) ?? ""
            )
            profileErrorMessage = nil
        } catch {
            profileErrorMessage = "Couldn't load your profile: \(error.localizedDescription)"
        }
    }

    // Passed to EditProfileSheet as `onSave` — returns an error message to show inline in the
    // sheet, or nil on success (in which case the sheet dismisses itself). Only writes back to
    // this screen's own @State once the save actually succeeds, so a cancelled edit never
    // touches it.
    private func saveProfile(
        name: String,
        dateOfBirth: Date,
        knownConditions: Set<MenstrualCondition>,
        cycleLengthBucket: SelfReportedCycleLengthBucket?
    ) -> String? {
        do {
            _ = try userRepository.updateProfile(
                name: name,
                dateOfBirth: dateOfBirth,
                knownConditions: Array(knownConditions)
            )

            if let cycleLengthBucket {
                UserDefaults.standard.set(cycleLengthBucket.rawValue, forKey: OnboardingViewModel.cycleLengthBucketDefaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: OnboardingViewModel.cycleLengthBucketDefaultsKey)
            }

            self.name = name
            self.dateOfBirth = dateOfBirth
            self.knownConditions = knownConditions
            self.cycleLengthBucket = cycleLengthBucket
            profileErrorMessage = nil
            return nil
        } catch {
            return "Couldn't save your profile: \(error.localizedDescription)"
        }
    }

    // Duplicates KnownConditionsStepView/CycleLengthBucketStepView's own private `label(for:)`
    // helpers — those are read-only display strings for this section's non-editing state, and
    // those views' own labels are private to their own picker rows, not meant to be shared.
    private static func label(forCondition condition: MenstrualCondition) -> String {
        switch condition {
        case .pcos: return "PCOS"
        case .endometriosis: return "Endometriosis"
        case .thyroidDisorder: return "Thyroid disorder"
        case .uterineFibroids: return "Uterine fibroids"
        case .perimenopause: return "Perimenopause"
        case .onHormonalContraception: return "Currently on hormonal contraception"
        case .other: return "Other / none of these"
        case .preferNotToSay: return "Prefer not to say"
        }
    }

    private static func label(forBucket bucket: SelfReportedCycleLengthBucket) -> String {
        switch bucket {
        case .typical: return "~28 days"
        case .shorter: return "Shorter than that"
        case .longer: return "Longer than that"
        case .notSure: return "Not sure"
        }
    }

    // MARK: - App Lock

    // Bloom doesn't implement its own PIN/biometric lock — see ARCHITECTURE.md's "Security"
    // note. This just points the user at iOS 18+'s own per-app Face ID/Touch ID/passcode lock.
    private var appLockSection: some View {
        Section {
            Label("Press and hold the Bloom app icon on your Home Screen, then tap "
                + "\u{201C}Require Face ID\u{201D} to lock it with Face ID, Touch ID, or your "
                + "device passcode.", systemImage: "faceid")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } header: {
            Text("App Lock")
        } footer: {
            Text("Bloom uses iOS's own per-app lock instead of a separate PIN.")
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
        // Presented directly via UIActivityViewController rather than ShareLink — see
        // ActivityShareSheet's own comment.
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
                .appendingPathComponent("bloom-export-\(timestamp).json")
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

            appleSignInManager.signOut()
            UserDefaults.standard.removeObject(forKey: OnboardingViewModel.cycleLengthBucketDefaultsKey)
            // BloomApp's RootRouterView reads this via @AppStorage and will reactively swap back
            // to OnboardingRootView, tearing down RootTabView (and this screen with it) — no
            // further navigation needed here.
            UserDefaults.standard.set(false, forKey: OnboardingViewModel.onboardingCompletedDefaultsKey)
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

// MARK: - Edit Profile sheet

// Owns its own local copies of the four fields, seeded from ProfilePage's current values at
// `init` — Cancel just dismisses without ever calling `onSave`, so ProfilePage's own state is
// untouched until a save actually succeeds.
private struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var dateOfBirth: Date
    @State private var knownConditions: Set<MenstrualCondition>
    @State private var cycleLengthBucket: SelfReportedCycleLengthBucket?
    @State private var errorMessage: String?

    // Returns an error message to display, or nil on success (in which case this sheet
    // dismisses itself).
    let onSave: (String, Date, Set<MenstrualCondition>, SelfReportedCycleLengthBucket?) -> String?

    init(
        name: String,
        dateOfBirth: Date,
        knownConditions: Set<MenstrualCondition>,
        cycleLengthBucket: SelfReportedCycleLengthBucket?,
        onSave: @escaping (String, Date, Set<MenstrualCondition>, SelfReportedCycleLengthBucket?) -> String?
    ) {
        _name = State(initialValue: name)
        _dateOfBirth = State(initialValue: dateOfBirth)
        _knownConditions = State(initialValue: knownConditions)
        _cycleLengthBucket = State(initialValue: cycleLengthBucket)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Name") {
                    TextField("Name", text: $name)
                }
                Section("Date of Birth") {
                    DateOfBirthStepView(date: $dateOfBirth)
                }
                Section("Known Conditions") {
                    KnownConditionsStepView(selection: $knownConditions)
                }
                Section("Cycle Length") {
                    CycleLengthBucketStepView(selection: $cycleLengthBucket)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: submit)
                        .fontWeight(.semibold)
                        .tint(Color.bloomPrimary)
                }
            }
        }
    }

    private func submit() {
        if let saveError = onSave(name, dateOfBirth, knownConditions, cycleLengthBucket) {
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
    ProfilePage()
        .modelContainer(PersistenceController.makeContainer(inMemory: true))
}
