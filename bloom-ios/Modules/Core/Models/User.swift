//
//  User.swift
//
//
//  Created by Rohit Suresh on 8/22/25.
//

import Foundation
import SwiftData

@Model
class User: Identifiable {
    // Not @Attribute(.unique): SwiftData's CloudKit integration doesn't support unique
    // constraints. Uniqueness (one profile per device) is enforced by UserRepository instead.
    var uuid: UUID
    var name: String
    var dateOfBirth: Date
    var knownConditions: [MenstrualCondition]
    var modifiedAt: Date

    init(name: String, dateOfBirth: Date, knownConditions: [MenstrualCondition] = []) {
        self.uuid = UUID()
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.knownConditions = knownConditions
        self.modifiedAt = Date()
    }
}
