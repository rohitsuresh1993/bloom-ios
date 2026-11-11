import Foundation

// `FertilityEngine.fertilityWindow` returns nil instead of one of these when the user reports
// being on hormonal contraception — showing a fertile window would be medically misleading, so
// callers simply don't render anything rather than checking a suppression flag.
struct FertilityWindow {
    let estimatedOvulationDate: Date
    let fertileWindowStart: Date
    let fertileWindowEnd: Date
    // true when a logged positive/peak OvulationTestResult confirmed this cycle's ovulation date
    // directly, rather than it being inferred from the luteal-phase blend.
    let isConfirmedByTest: Bool
}
