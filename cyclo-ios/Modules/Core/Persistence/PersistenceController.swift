import Foundation
import SwiftData

// Versioned from the start so future schema changes are additive migrations, not rewrites.
enum CycloSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [User.self, PeriodLog.self, Log.self]
    }
}

enum CycloMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [CycloSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

enum PersistenceController {
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(
                schema: Schema(versionedSchema: CycloSchemaV1.self),
                isStoredInMemoryOnly: true
            )
        } else {
            configuration = ModelConfiguration(
                schema: Schema(versionedSchema: CycloSchemaV1.self),
                url: protectedStoreURL(),
                cloudKitDatabase: .none
            )
        }

        do {
            return try ModelContainer(
                for: Schema(versionedSchema: CycloSchemaV1.self),
                migrationPlan: CycloMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            fatalError("Failed to create Cyclo's ModelContainer: \(error)")
        }
    }

    // The store lives in its own directory set to NSFileProtectionComplete, so the database is
    // unreadable whenever the device is locked — including for any background work. New files
    // created inside a directory with this protection class inherit it automatically.
    private static func protectedStoreURL() -> URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let storeDirectory = appSupport.appendingPathComponent("CycloStore", isDirectory: true)

        if !fileManager.fileExists(atPath: storeDirectory.path) {
            try? fileManager.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        }
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: storeDirectory.path
        )

        return storeDirectory.appendingPathComponent("Cyclo.sqlite")
    }
}
