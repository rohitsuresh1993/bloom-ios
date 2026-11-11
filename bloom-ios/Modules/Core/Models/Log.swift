import Foundation
import SwiftData

@Model
class Log {
    var id: UUID
    var timestamp: Date
    var mood: [Mood]?
    var symptoms: [Symptoms]?
    var sexualActivity: [SexualActivity]?
    var sexDrive: SexDrive?
    var vaginalDischarge: VaginalDischarge?
    var ovulationTestResult: OvulationTestResult?
    var pregnancyTest: PregnancyTest?
    var oralContraceptiveStatus: OralContraceptiveStatus?
    var physicalActivity: [PhysicalActivity]?
    var digestionAndStool: [DigestionAndStool]?
    var flowIntensity: FlowIntensity?
    var other: [Other]?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        mood: [Mood]? = nil,
        symptoms: [Symptoms]? = nil,
        sexualActivity: [SexualActivity]? = nil,
        sexDrive: SexDrive? = nil,
        vaginalDischarge: VaginalDischarge? = nil,
        ovulationTestResult: OvulationTestResult? = nil,
        pregnancyTest: PregnancyTest? = nil,
        oralContraceptiveStatus: OralContraceptiveStatus? = nil,
        physicalActivity: [PhysicalActivity]? = nil,
        digestionAndStool: [DigestionAndStool]? = nil,
        flowIntensity: FlowIntensity? = nil,
        other: [Other]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.mood = mood
        self.symptoms = symptoms
        self.sexualActivity = sexualActivity
        self.sexDrive = sexDrive
        self.vaginalDischarge = vaginalDischarge
        self.ovulationTestResult = ovulationTestResult
        self.pregnancyTest = pregnancyTest
        self.oralContraceptiveStatus = oralContraceptiveStatus
        self.physicalActivity = physicalActivity
        self.digestionAndStool = digestionAndStool
        self.flowIntensity = flowIntensity
        self.other = other
    }
}

struct LogDTO: Codable, Identifiable {
    var id: UUID
    var timestamp: Date
    var mood: [Mood]?
    var symptoms: [Symptoms]?
    var sexualActivity: [SexualActivity]?
    var sexDrive: SexDrive?
    var vaginalDischarge: VaginalDischarge?
    var ovulationTestResult: OvulationTestResult?
    var pregnancyTest: PregnancyTest?
    var oralContraceptiveStatus: OralContraceptiveStatus?
    var physicalActivity: [PhysicalActivity]?
    var digestionAndStool: [DigestionAndStool]?
    var flowIntensity: FlowIntensity?
    var other: [Other]?
}

extension Log {
    func toDTO() -> LogDTO {
        LogDTO(
            id: id,
            timestamp: timestamp,
            mood: mood,
            symptoms: symptoms,
            sexualActivity: sexualActivity,
            sexDrive: sexDrive,
            vaginalDischarge: vaginalDischarge,
            ovulationTestResult: ovulationTestResult,
            pregnancyTest: pregnancyTest,
            oralContraceptiveStatus: oralContraceptiveStatus,
            physicalActivity: physicalActivity,
            digestionAndStool: digestionAndStool,
            flowIntensity: flowIntensity,
            other: other
        )
    }
}

extension LogDTO {
    func toModel() -> Log {
        Log(
            id: id,
            timestamp: timestamp,
            mood: mood,
            symptoms: symptoms,
            sexualActivity: sexualActivity,
            sexDrive: sexDrive,
            vaginalDischarge: vaginalDischarge,
            ovulationTestResult: ovulationTestResult,
            pregnancyTest: pregnancyTest,
            oralContraceptiveStatus: oralContraceptiveStatus,
            physicalActivity: physicalActivity,
            digestionAndStool: digestionAndStool,
            flowIntensity: flowIntensity,
            other: other
        )
    }
}
