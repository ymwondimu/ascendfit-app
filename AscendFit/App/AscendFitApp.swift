import SwiftUI

@main
struct AscendFitApp: App {
    private let preferenceStore: UserDefaults = {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--ui-testing") || arguments.contains("--ui-testing-onboarding") else {
            return .standard
        }
        let testID = ProcessInfo.processInfo.environment["ASCEND_FIT_UI_TEST_STORE_ID"]
            .flatMap(UUID.init(uuidString:)) ?? UUID()
        return UserDefaults(suiteName: "AscendFitUITests-\(testID.uuidString)")!
    }()

    var body: some Scene {
        WindowGroup {
            RootView(preferenceStore: preferenceStore)
                .defaultAppStorage(preferenceStore)
        }
    }
}
