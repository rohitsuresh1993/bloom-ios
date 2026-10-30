//
//  PeriodLog.swift
//
//
//  Created by Rohit Suresh on 8/25/25.
//

import Foundation
import SwiftData

@Model
class PeriodLog {
    var id: UUID
    // Optional: SwiftData's CloudKit integration requires all relationships to be optional.
    var user: User?
    var startDate: Date
    var endDate: Date

    init(id: UUID = UUID(), user: User?, startDate: Date, endDate: Date) {
        self.id = id
        self.user = user
        self.startDate = startDate
        self.endDate = endDate
    }
}

struct PeriodLogDTO: Codable, Identifiable {
    var id: UUID
    var startDate: Date
    var endDate: Date
    var userId: UUID?        // send a reference to the user instead of embedding User
}

extension PeriodLog {
    func toDTO() -> PeriodLogDTO {
        PeriodLogDTO(
            id: self.id,
            startDate: self.startDate,
            endDate: self.endDate,
            userId: self.user?.uuid
        )
    }
}

extension PeriodLogDTO {
    func toModel(user: User?) -> PeriodLog {
        PeriodLog(id: self.id, user: user, startDate: self.startDate, endDate: self.endDate)
    }
}
