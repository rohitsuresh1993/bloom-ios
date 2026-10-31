import SwiftData
import SwiftUI

@main
struct CycloApp: App {
    private let modelContainer = PersistenceController.makeContainer()
    private let appLockManager: AppLockManaging = AppLockManager()

    var body: some Scene {
        WindowGroup {
            AppLockGateView(appLockManager: appLockManager) {
                HomePage()
            }
        }
        .modelContainer(modelContainer)
    }
}
