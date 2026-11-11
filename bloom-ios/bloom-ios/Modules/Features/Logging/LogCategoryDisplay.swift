//
//  LogCategoryDisplay.swift
//  bloom-ios
//
//  Retroactively conforms every `Log` category enum (Modules/Core/Models/LogCategories/*) to
//  `LogCategoryOption` so the Logging screens can list and label their cases, without editing
//  those model files. `allOptions` is listed explicitly (not derived from `CaseIterable`
//  synthesis, which requires the conformance to be declared alongside the enum) so this stays
//  a pure addition from the Logging feature's own files.
//
//  `iconSystemName` below is a placeholder SF Symbol per case — a reasonable decorative choice,
//  not a carefully-curated icon set, picked to be broadly available (SF Symbols shipped by
//  iOS 16/17 at the latest) given there's no way to visually verify every glyph in this
//  environment. Swap for real icon tokens if/when the app gets a proper icon set.
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

    var iconSystemName: String? {
        switch self {
        case .calm: return "leaf.fill"
        case .happy: return "face.smiling"
        case .energetic: return "bolt.fill"
        case .frisky: return "flame.fill"
        case .moodSwings: return "arrow.left.arrow.right"
        case .irritated: return "exclamationmark.triangle.fill"
        case .sad: return "cloud.rain.fill"
        case .anxious: return "waveform.path.ecg"
        case .depressed: return "cloud.fill"
        case .feelingGuilty: return "hand.raised.fill"
        case .obsessiveThoughts: return "arrow.triangle.2.circlepath"
        case .lowEnergy: return "battery.25"
        case .apathetic: return "minus.circle.fill"
        case .confused: return "questionmark.circle.fill"
        case .verySelfCritical: return "exclamationmark.bubble.fill"
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

    var iconSystemName: String? {
        switch self {
        case .everythingIsFine: return "hand.thumbsup.fill"
        case .cramps: return "bolt.heart.fill"
        case .tenderBreasts: return "heart.fill"
        case .headache: return "brain.head.profile"
        case .acne: return "circle.grid.2x2.fill"
        case .backache: return "figure.walk"
        case .fatigue: return "zzz"
        case .cravings: return "fork.knife"
        case .insomnia: return "moon.zzz.fill"
        case .abdominalPain: return "bolt.fill"
        case .vaginalItching: return "allergens"
        case .vaginalDryness: return "drop"
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

    var iconSystemName: String? {
        switch self {
        case .didntHaveSex: return "xmark.circle.fill"
        case .protectedSex: return "shield.fill"
        case .unprotectedSex: return "shield.slash.fill"
        case .oralSex: return "heart.circle.fill"
        case .analSex: return "circle.fill"
        case .masturbation: return "hand.raised.fill"
        case .sensualTouch: return "hands.sparkles.fill"
        case .sexToys: return "sparkles"
        case .orgasm: return "star.fill"
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

    var iconSystemName: String? {
        switch self {
        case .highSexDrive: return "heart.fill"
        case .neutralSexDrive: return "heart"
        case .lowSexDrive: return "heart.slash"
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

    var iconSystemName: String? {
        switch self {
        case .noDischarge: return "circle.slash"
        case .creamy: return "drop.fill"
        case .watery: return "drop"
        case .sticky: return "water.waves"
        case .eggWhite: return "oval.fill"
        case .spotting: return "circle.grid.2x2.fill"
        case .unusual: return "exclamationmark.triangle.fill"
        case .clumpyWhite: return "cloud.fill"
        case .gray: return "circle.fill"
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

    var iconSystemName: String? {
        switch self {
        case .negative: return "minus.circle.fill"
        case .lowFertility: return "chart.bar.fill"
        case .highFertility: return "chart.bar.xaxis"
        case .peak: return "flame.fill"
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

    var iconSystemName: String? {
        switch self {
        case .didntTakeTests: return "circle.slash"
        case .positive: return "plus.circle.fill"
        case .negative: return "minus.circle.fill"
        case .faintLine: return "line.diagonal"
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

    var iconSystemName: String? {
        switch self {
        case .takenOnTime: return "checkmark.circle.fill"
        case .yesterdaysPill: return "clock.arrow.circlepath"
        case .missedPill: return "xmark.circle.fill"
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

    var iconSystemName: String? {
        switch self {
        case .didntExercise: return "figure.stand"
        case .yoga: return "figure.yoga"
        case .gym: return "dumbbell.fill"
        case .aerobicsAndDancing: return "music.note"
        case .swimming: return "figure.pool.swim"
        case .teamSports: return "sportscourt.fill"
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .walking: return "figure.walk"
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

    var iconSystemName: String? {
        switch self {
        case .normal: return "checkmark.circle.fill"
        case .nausea: return "exclamationmark.circle.fill"
        case .bloating: return "circle.inset.filled"
        case .constipation: return "lock.fill"
        case .diarrhea: return "drop.fill"
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

    var iconSystemName: String? {
        switch self {
        case .spotting: return "drop"
        case .light: return "drop.fill"
        case .medium: return "drop.fill"
        case .heavy: return "drop.fill"
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

    var iconSystemName: String? {
        switch self {
        case .travel: return "airplane"
        case .stress: return "bolt.fill"
        case .meditation: return "figure.mind.and.body"
        case .journaling: return "book.fill"
        case .kegelExercises: return "figure.strengthtraining.traditional"
        case .breathingExercises: return "lungs.fill"
        case .diseaseOrInjury: return "bandage.fill"
        case .alcohol: return "wineglass.fill"
        }
    }
}
