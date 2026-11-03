//
//  ProfileView.swift
//  cyclo-ios
//
//  Profile screen — lets the user view/edit the self-reported profile fields collected at
//  onboarding: name, date of birth, known conditions, and cycle-length bucket. Reuses
//  Onboarding's step views (`DateOfBirthStepView`, `KnownConditionsStepView`,
//  `CycleLengthBucketStepView`) unmodified via cross-feature import — they're already pure
//  `@Binding`-driven components with no dependency on `OnboardingViewModel`. Name/date of
//  birth/known conditions save through `UserRepository.updateProfile`; the cycle-length bucket
//  is a cold-start-only prediction nudge stored in `UserDefaults` (see
//  `OnboardingViewModel.cycleLengthBucketDefaultsKey`), not a field on `User`, so it's written
//  back separately.
//
//  Root entry point: present `ProfileView()` from anywhere (e.g. via `.sheet`).
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var dateOfBirth: Date = Date()
    @State private var knownConditions: Set<MenstrualCondition> = []
    @State private var cycleLengthBucket: SelfReportedCycleLengthBucket?

    @State private var hasLoaded = false
    @State private var errorMessage: String?

    private var userRepository: UserRepository {
        UserRepository(modelContext: modelContext)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
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
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .tint(Color.cycloPrimary)
                }
            }
            .onAppear(perform: loadProfile)
        }
    }

    private func loadProfile() {
        guard !hasLoaded else { return }
        hasLoaded = true
        do {
            let user = try userRepository.currentUser()
            name = user.name
            dateOfBirth = user.dateOfBirth
            knownConditions = Set(user.knownConditions)
            cycleLengthBucket = SelfReportedCycleLengthBucket(
                rawValue: UserDefaults.standard.string(forKey: OnboardingViewModel.cycleLengthBucketDefaultsKey) ?? ""
            )
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load your profile: \(error.localizedDescription)"
        }
    }

    private func save() {
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

            dismiss()
        } catch {
            errorMessage = "Couldn't save your profile: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ProfileView()
}
