import Foundation

enum CyclePhase {
    case menstrual
    case follicular
    case ovulatory
    case luteal
}

extension CyclePhase {
    // Display name for UI surfaces (cycle-phase ring center label, "patterns" card headings).
    // Kept next to the phase enum itself rather than scattered across call sites.
    var displayName: String {
        switch self {
        case .menstrual: return "Menstrual"
        case .follicular: return "Follicular"
        case .ovulatory: return "Ovulatory"
        case .luteal: return "Luteal"
        }
    }
}

// Retrospective pattern-surfacing over already-logged data, not forward prediction — the data
// volume and self-report noise here don't support a confident forward claim. A group-by-and-
// count, nothing ML about it.
enum SymptomCorrelationEngine {
    struct SymptomObservation {
        let date: Date
        let symptoms: [Symptoms]
    }

    struct PhaseFrequency {
        let phase: CyclePhase
        let symptom: Symptoms
        // Number of the user's own cycles (out of `cyclesObserved`) in which this symptom was
        // logged at least once during this phase.
        let occurrences: Int
        let cyclesObserved: Int
    }

    // Mood's parallel to SymptomObservation/PhaseFrequency above — same retrospective
    // group-by-and-count, just bucketing Mood instead of Symptoms, so mood patterns can surface
    // alongside symptom patterns (e.g. in HomeViewModel's "what you might notice today" card).
    struct MoodObservation {
        let date: Date
        let moods: [Mood]
    }

    struct MoodPhaseFrequency {
        let phase: CyclePhase
        let mood: Mood
        // Number of the user's own cycles (out of `cyclesObserved`) in which this mood was
        // logged at least once during this phase.
        let occurrences: Int
        let cyclesObserved: Int
    }

    private struct PhaseSymptomKey: Hashable {
        let phase: CyclePhase
        let symptom: Symptoms
    }

    private struct PhaseMoodKey: Hashable {
        let phase: CyclePhase
        let mood: Mood
    }

    // `periodStartDates` is this user's own history, used both to bound each cycle and, via
    // `typicalCycleLength`/`typicalLutealPhaseLength`, to map each observation's day-offset into
    // a phase. Needs at least two period starts to bound a single complete cycle.
    static func phaseFrequencies(
        observations: [SymptomObservation],
        periodStartDates: [Date],
        typicalCycleLength: Double,
        typicalLutealPhaseLength: Double,
        calendar: Calendar = .current
    ) -> [PhaseFrequency] {
        let sortedStarts = periodStartDates.sorted()
        guard sortedStarts.count >= 2 else { return [] }

        let cycleCount = sortedStarts.count - 1
        var cyclesContainingKey: [PhaseSymptomKey: Int] = [:]

        for cycleIndex in 0..<cycleCount {
            let cycleStart = sortedStarts[cycleIndex]
            let cycleEnd = sortedStarts[cycleIndex + 1]
            let cycleObservations = observations.filter { $0.date >= cycleStart && $0.date < cycleEnd }

            var keysSeenThisCycle = Set<PhaseSymptomKey>()
            for observation in cycleObservations {
                let dayOffset = calendar.dateComponents([.day], from: cycleStart, to: observation.date).day ?? 0
                let phase = phase(
                    forDayOffset: dayOffset,
                    cycleLength: typicalCycleLength,
                    lutealPhaseLength: typicalLutealPhaseLength
                )
                for symptom in observation.symptoms {
                    keysSeenThisCycle.insert(PhaseSymptomKey(phase: phase, symptom: symptom))
                }
            }

            for key in keysSeenThisCycle {
                cyclesContainingKey[key, default: 0] += 1
            }
        }

        return cyclesContainingKey.map { key, count in
            PhaseFrequency(phase: key.phase, symptom: key.symptom, occurrences: count, cyclesObserved: cycleCount)
        }
    }

    // Mood's parallel to `phaseFrequencies` above: identical cycle-bounding/day-offset/phase-
    // bucketing logic (including reuse of the same `phase(forDayOffset:cycleLength:
    // lutealPhaseLength:)` helper below), just keyed on Mood instead of Symptoms.
    static func moodPhaseFrequencies(
        observations: [MoodObservation],
        periodStartDates: [Date],
        typicalCycleLength: Double,
        typicalLutealPhaseLength: Double,
        calendar: Calendar = .current
    ) -> [MoodPhaseFrequency] {
        let sortedStarts = periodStartDates.sorted()
        guard sortedStarts.count >= 2 else { return [] }

        let cycleCount = sortedStarts.count - 1
        var cyclesContainingKey: [PhaseMoodKey: Int] = [:]

        for cycleIndex in 0..<cycleCount {
            let cycleStart = sortedStarts[cycleIndex]
            let cycleEnd = sortedStarts[cycleIndex + 1]
            let cycleObservations = observations.filter { $0.date >= cycleStart && $0.date < cycleEnd }

            var keysSeenThisCycle = Set<PhaseMoodKey>()
            for observation in cycleObservations {
                let dayOffset = calendar.dateComponents([.day], from: cycleStart, to: observation.date).day ?? 0
                let phase = phase(
                    forDayOffset: dayOffset,
                    cycleLength: typicalCycleLength,
                    lutealPhaseLength: typicalLutealPhaseLength
                )
                for mood in observation.moods {
                    keysSeenThisCycle.insert(PhaseMoodKey(phase: phase, mood: mood))
                }
            }

            for key in keysSeenThisCycle {
                cyclesContainingKey[key, default: 0] += 1
            }
        }

        return cyclesContainingKey.map { key, count in
            MoodPhaseFrequency(phase: key.phase, mood: key.mood, occurrences: count, cyclesObserved: cycleCount)
        }
    }

    // Shared by `phaseFrequencies` and `moodPhaseFrequencies` above, and (intentionally not
    // `private`) by HomeViewModel too, so the cycle-phase ring's "today's phase" label stays
    // bucketed exactly the same way as the patterns card that surfaces alongside it.
    static func phase(forDayOffset dayOffset: Int, cycleLength: Double, lutealPhaseLength: Double) -> CyclePhase {
        let menstrualLength = PredictionConstants.assumedMenstrualPhaseLength
        let ovulationDay = cycleLength - lutealPhaseLength
        let ovulatoryWindowStart = ovulationDay - 1
        let ovulatoryWindowEnd = ovulationDay + 1

        let day = Double(dayOffset)
        if day < menstrualLength {
            return .menstrual
        } else if day < ovulatoryWindowStart {
            return .follicular
        } else if day <= ovulatoryWindowEnd {
            return .ovulatory
        } else {
            return .luteal
        }
    }
}
