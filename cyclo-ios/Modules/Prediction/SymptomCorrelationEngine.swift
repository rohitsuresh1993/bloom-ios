import Foundation

enum CyclePhase {
    case menstrual
    case follicular
    case ovulatory
    case luteal
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

    private struct PhaseSymptomKey: Hashable {
        let phase: CyclePhase
        let symptom: Symptoms
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

    private static func phase(forDayOffset dayOffset: Int, cycleLength: Double, lutealPhaseLength: Double) -> CyclePhase {
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
