import Foundation

// Cold-start fallback for the Mood/Symptoms insight cards on Home: generalized population-level
// tendencies by cycle phase, used until a user has enough of their own logged history for
// SymptomCorrelationEngine's retrospective per-user frequencies to take over (see
// HomeViewModel.buildSymptomInsights/buildMoodInsights).
//
// IMPORTANT: same honesty standard as PriorTable — these are reasonable, commonly-cited
// population tendencies synthesized from the research cited in ARCHITECTURE.md (PMS/PMDD
// prevalence literature; luteal-phase progesterone/estrogen-drop symptom clusters; follicular/
// ovulatory estrogen-rise mood-and-energy literature), not pulled from one sourced study and not
// personalized to this user's age/conditions. Ranked roughly by how often each is cited as
// common for that phase, most-cited first. Replace with carefully-sourced per-condition/age-
// bucketed figures in the same follow-up pass flagged for PriorTable, if that's ever warranted.
enum PopulationInsights {
    static func topSymptoms(forPhase phase: CyclePhase) -> [Symptoms] {
        switch phase {
        case .menstrual: return [.cramps, .fatigue, .backache]
        case .follicular: return [.acne]
        case .ovulatory: return [.abdominalPain]
        case .luteal: return [.tenderBreasts, .cravings, .fatigue]
        }
    }

    static func topMoods(forPhase phase: CyclePhase) -> [Mood] {
        switch phase {
        case .menstrual: return [.lowEnergy, .sad]
        case .follicular: return [.energetic, .happy]
        case .ovulatory: return [.energetic, .frisky]
        case .luteal: return [.irritated, .moodSwings, .anxious]
        }
    }
}
