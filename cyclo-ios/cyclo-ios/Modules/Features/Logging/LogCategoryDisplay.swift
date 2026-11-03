//
//  LogCategoryDisplay.swift
//  cyclo-ios
//
//  Retroactively conforms every `Log` category enum (Modules/Core/Models/LogCategories/*) to
//  `LogCategoryOption` so the Logging screens can list and label their cases, without editing
//  those model files. `allOptions` is listed explicitly (not derived from `CaseIterable`
//  synthesis, which requires the conformance to be declared alongside the enum) so this stays
//  a pure addition from the Logging feature's own files.
//

import Foundation

extension Mood: LogCategoryOption {
    static let allOptions: [Mood] = [
        .calm, .happy, .energetic, .frisky, .moodSwings, .irritated, .sad, .anxious,
        .depressed, .feelingGuilty, .obsessiveThoughts, .lowEnergy, .apathetic, .confused,
        .verySelfCritical
    ]

    var displayName: String {
        switch self {
        case .calm: return "Calm"
        case .happy: return "Happy"
        case .energetic: return "Energetic"
        case .frisky: return "Frisky"
        case .moodSwings: return "Mood swings"
        case .irritated: return "Irritated"
        case .sad: return "Sad"
        case .anxious: return "Anxious"
        case .depressed: return "Depressed"
        case .feelingGuilty: return "Feeling guilty"
        case .obsessiveThoughts: return "Obsessive thoughts"
        case .lowEnergy: return "Low energy"
        case .apathetic: return "Apathetic"
        case .confused: return "Confused"
        case .verySelfCritical: return "Very self-critical"
        }
    }
}

extension Symptoms: LogCategoryOption {
    static let allOptions: [Symptoms] = [
        .everythingIsFine, .cramps, .tenderBreasts, .headache, .acne, .backache, .fatigue,
        .cravings, .insomnia, .abdominalPain, .vaginalItching, .vaginalDryness
    ]

    var displayName: String {
        switch self {
        case .everythingIsFine: return "Everything is fine"
        case .cramps: return "Cramps"
        case .tenderBreasts: return "Tender breasts"
        case .headache: return "Headache"
        case .acne: return "Acne"
        case .backache: return "Backache"
        case .fatigue: return "Fatigue"
        case .cravings: return "Cravings"
        case .insomnia: return "Insomnia"
        case .abdominalPain: return "Abdominal pain"
        case .vaginalItching: return "Vaginal itching"
        case .vaginalDryness: return "Vaginal dryness"
        }
    }
}

extension SexualActivity: LogCategoryOption {
    static let allOptions: [SexualActivity] = [
        .didntHaveSex, .protectedSex, .unprotectedSex, .oralSex, .analSex, .masturbation,
        .sensualTouch, .sexToys, .orgasm
    ]

    var displayName: String {
        switch self {
        case .didntHaveSex: return "Didn't have sex"
        case .protectedSex: return "Protected sex"
        case .unprotectedSex: return "Unprotected sex"
        case .oralSex: return "Oral sex"
        case .analSex: return "Anal sex"
        case .masturbation: return "Masturbation"
        case .sensualTouch: return "Sensual touch"
        case .sexToys: return "Sex toys"
        case .orgasm: return "Orgasm"
        }
    }
}

extension SexDrive: LogCategoryOption {
    static let allOptions: [SexDrive] = [.highSexDrive, .neutralSexDrive, .lowSexDrive]

    var displayName: String {
        switch self {
        case .highSexDrive: return "High"
        case .neutralSexDrive: return "Neutral"
        case .lowSexDrive: return "Low"
        }
    }
}

extension VaginalDischarge: LogCategoryOption {
    static let allOptions: [VaginalDischarge] = [
        .noDischarge, .creamy, .watery, .sticky, .eggWhite, .spotting, .unusual, .clumpyWhite,
        .gray
    ]

    var displayName: String {
        switch self {
        case .noDischarge: return "No discharge"
        case .creamy: return "Creamy"
        case .watery: return "Watery"
        case .sticky: return "Sticky"
        case .eggWhite: return "Egg white"
        case .spotting: return "Spotting"
        case .unusual: return "Unusual"
        case .clumpyWhite: return "Clumpy white"
        case .gray: return "Gray"
        }
    }
}

extension OvulationTestResult: LogCategoryOption {
    static let allOptions: [OvulationTestResult] = [.negative, .lowFertility, .highFertility, .peak]

    var displayName: String {
        switch self {
        case .negative: return "Negative"
        case .lowFertility: return "Low fertility"
        case .highFertility: return "High fertility"
        case .peak: return "Peak"
        }
    }
}

extension PregnancyTest: LogCategoryOption {
    static let allOptions: [PregnancyTest] = [.didntTakeTests, .positive, .negative, .faintLine]

    var displayName: String {
        switch self {
        case .didntTakeTests: return "Didn't test"
        case .positive: return "Positive"
        case .negative: return "Negative"
        case .faintLine: return "Faint line"
        }
    }
}

extension OralContraceptiveStatus: LogCategoryOption {
    static let allOptions: [OralContraceptiveStatus] = [.takenOnTime, .yesterdaysPill, .missedPill]

    var displayName: String {
        switch self {
        case .takenOnTime: return "Taken on time"
        case .yesterdaysPill: return "Yesterday's pill"
        case .missedPill: return "Missed pill"
        }
    }
}

extension PhysicalActivity: LogCategoryOption {
    static let allOptions: [PhysicalActivity] = [
        .didntExercise, .yoga, .gym, .aerobicsAndDancing, .swimming, .teamSports, .running,
        .cycling, .walking
    ]

    var displayName: String {
        switch self {
        case .didntExercise: return "Didn't exercise"
        case .yoga: return "Yoga"
        case .gym: return "Gym"
        case .aerobicsAndDancing: return "Aerobics & dancing"
        case .swimming: return "Swimming"
        case .teamSports: return "Team sports"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        }
    }
}

extension DigestionAndStool: LogCategoryOption {
    static let allOptions: [DigestionAndStool] = [.normal, .nausea, .bloating, .constipation, .diarrhea]

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .nausea: return "Nausea"
        case .bloating: return "Bloating"
        case .constipation: return "Constipation"
        case .diarrhea: return "Diarrhea"
        }
    }
}

extension FlowIntensity: LogCategoryOption {
    static let allOptions: [FlowIntensity] = [.spotting, .light, .medium, .heavy]

    var displayName: String {
        switch self {
        case .spotting: return "Spotting"
        case .light: return "Light"
        case .medium: return "Medium"
        case .heavy: return "Heavy"
        }
    }
}

extension Other: LogCategoryOption {
    static let allOptions: [Other] = [
        .travel, .stress, .meditation, .journaling, .kegelExercises, .breathingExercises,
        .diseaseOrInjury, .alcohol
    ]

    var displayName: String {
        switch self {
        case .travel: return "Travel"
        case .stress: return "Stress"
        case .meditation: return "Meditation"
        case .journaling: return "Journaling"
        case .kegelExercises: return "Kegel exercises"
        case .breathingExercises: return "Breathing exercises"
        case .diseaseOrInjury: return "Disease or injury"
        case .alcohol: return "Alcohol"
        }
    }
}
