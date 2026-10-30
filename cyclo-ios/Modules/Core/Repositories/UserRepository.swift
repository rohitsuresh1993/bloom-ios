import Foundation
import SwiftData

enum UserRepositoryError: Error {
    case dateOfBirthInFuture
    case dateOfBirthOutOfRange
}

protocol UserRepositoring {
    // Cyclo is accountless and single-profile-per-device: this always returns the one local
    // profile, creating it on first call. Uniqueness is enforced here rather than with a
    // SwiftData `.unique` constraint, since that's unsupported once CloudKit sync is enabled.
    func currentUser() throws -> User
    func updateProfile(name: String, dateOfBirth: Date, knownConditions: [MenstrualCondition]) throws -> User
}

final class UserRepository: UserRepositoring {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func currentUser() throws -> User {
        if let existing = try modelContext.fetch(FetchDescriptor<User>()).first {
            return existing
        }
        let user = User(name: "", dateOfBirth: Date())
        modelContext.insert(user)
        try modelContext.save()
        return user
    }

    func updateProfile(name: String, dateOfBirth: Date, knownConditions: [MenstrualCondition]) throws -> User {
        try Self.validate(dateOfBirth: dateOfBirth)
        let user = try currentUser()
        user.name = name
        user.dateOfBirth = dateOfBirth
        user.knownConditions = knownConditions
        user.modifiedAt = Date()
        try modelContext.save()
        return user
    }

    private static func validate(dateOfBirth: Date) throws {
        let now = Date()
        guard dateOfBirth <= now else {
            throw UserRepositoryError.dateOfBirthInFuture
        }
        guard let earliestReasonable = Calendar.current.date(byAdding: .year, value: -120, to: now),
              dateOfBirth >= earliestReasonable else {
            throw UserRepositoryError.dateOfBirthOutOfRange
        }
    }
}
