import Foundation

// Self-reported at onboarding only — never inferred or detected from logged data.
enum MenstrualCondition: Int, Codable {
    case pcos = 0
    case endometriosis = 1
    case thyroidDisorder = 2
    case uterineFibroids = 3
    case perimenopause = 4
    case onHormonalContraception = 5
    case other = 6
    case preferNotToSay = 7
}
