//
//  LogDayView.swift
//  cyclo-ios
//
//  Day-log entry screen covering the full `Log` model surface (Modules/Core/Models/Log.swift).
//  Single-valued categories (sexDrive, vaginalDischarge, ovulationTestResult, pregnancyTest,
//  oralContraceptiveStatus, flowIntensity) get a SingleSelectChipSection that allows a "none
//  selected" state; array-valued categories (mood, symptoms, sexualActivity,
//  physicalActivity, digestionAndStool, other) get a MultiSelectChipSection. `nil` on the
//  model always means "not logged that day" — an empty selection in this view is saved back
//  as `nil`, never as an empty array.
//
//  Loads today's (or `date`'s) existing `Log` via `LogRepository.log(on:)` so re-opening this
//  screen edits the day's entry instead of creating a duplicate, and saves via
//  `LogRepository.saveLog(_:)`.
//
//  Root entry point: present `LogDayView()` from anywhere (e.g. via `.sheet`).
//

import SwiftUI
import SwiftData

struct LogDayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let date: Date

    @State private var mood: [Mood] = []
    @State private var symptoms: [Symptoms] = []
    @State private var sexualActivity: [SexualActivity] = []
    @State private var physicalActivity: [PhysicalActivity] = []
    @State private var digestionAndStool: [DigestionAndStool] = []
    @State private var other: [Other] = []

    @State private var sexDrive: SexDrive?
    @State private var vaginalDischarge: VaginalDischarge?
    @State private var ovulationTestResult: OvulationTestResult?
    @State private var pregnancyTest: PregnancyTest?
    @State private var oralContraceptiveStatus: OralContraceptiveStatus?
    @State private var flowIntensity: FlowIntensity?

    @State private var existingLog: Log?
    @State private var hasLoaded = false
    @State private var errorMessage: String?

    init(date: Date = Date()) {
        self.date = date
    }

    private var logRepository: LogRepository {
        LogRepository(modelContext: modelContext)
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

                MultiSelectChipSection(title: "Mood", selection: $mood)
                MultiSelectChipSection(title: "Symptoms", selection: $symptoms)
                SingleSelectChipSection(title: "Flow Intensity", selection: $flowIntensity)
                MultiSelectChipSection(title: "Sexual Activity", selection: $sexualActivity)
                SingleSelectChipSection(title: "Sex Drive", selection: $sexDrive)
                SingleSelectChipSection(title: "Vaginal Discharge", selection: $vaginalDischarge)
                SingleSelectChipSection(title: "Ovulation Test", selection: $ovulationTestResult)
                SingleSelectChipSection(title: "Pregnancy Test", selection: $pregnancyTest)
                SingleSelectChipSection(title: "Oral Contraceptive", selection: $oralContraceptiveStatus)
                MultiSelectChipSection(title: "Physical Activity", selection: $physicalActivity)
                MultiSelectChipSection(title: "Digestion & Stool", selection: $digestionAndStool)
                MultiSelectChipSection(title: "Other", selection: $other)
            }
            .navigationTitle(date.formatted(date: .abbreviated, time: .omitted))
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
            .onAppear(perform: loadExistingLog)
        }
    }

    private func loadExistingLog() {
        guard !hasLoaded else { return }
        hasLoaded = true
        do {
            guard let log = try logRepository.log(on: date) else { return }
            existingLog = log
            mood = log.mood ?? []
            symptoms = log.symptoms ?? []
            sexualActivity = log.sexualActivity ?? []
            physicalActivity = log.physicalActivity ?? []
            digestionAndStool = log.digestionAndStool ?? []
            other = log.other ?? []
            sexDrive = log.sexDrive
            vaginalDischarge = log.vaginalDischarge
            ovulationTestResult = log.ovulationTestResult
            pregnancyTest = log.pregnancyTest
            oralContraceptiveStatus = log.oralContraceptiveStatus
            flowIntensity = log.flowIntensity
        } catch {
            errorMessage = "Couldn't load this day's log: \(error.localizedDescription)"
        }
    }

    private func save() {
        let log = existingLog ?? Log(timestamp: date)
        log.mood = mood.isEmpty ? nil : mood
        log.symptoms = symptoms.isEmpty ? nil : symptoms
        log.sexualActivity = sexualActivity.isEmpty ? nil : sexualActivity
        log.physicalActivity = physicalActivity.isEmpty ? nil : physicalActivity
        log.digestionAndStool = digestionAndStool.isEmpty ? nil : digestionAndStool
        log.other = other.isEmpty ? nil : other
        log.sexDrive = sexDrive
        log.vaginalDischarge = vaginalDischarge
        log.ovulationTestResult = ovulationTestResult
        log.pregnancyTest = pregnancyTest
        log.oralContraceptiveStatus = oralContraceptiveStatus
        log.flowIntensity = flowIntensity

        do {
            try logRepository.saveLog(log)
            dismiss()
        } catch {
            errorMessage = "Couldn't save this log: \(error.localizedDescription)"
        }
    }
}

#Preview {
    LogDayView()
}
