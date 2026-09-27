import Testing
import UserNotifications
@testable import AscendFit

@Suite("Rest notification permission reconciliation")
struct RestNotificationPermissionTests {
    @Test("Foreground permission changes reconcile without unsolicited prompts")
    func foregroundPermissionChanges() {
        #expect(RestNotificationPermissionPolicy.action(status: .notDetermined, allowPermissionRequest: false) == .cancel)
        #expect(RestNotificationPermissionPolicy.action(status: .denied, allowPermissionRequest: false) == .cancel)
        #expect(RestNotificationPermissionPolicy.action(status: .authorized, allowPermissionRequest: false) == .schedule)
        #expect(RestNotificationPermissionPolicy.action(status: .provisional, allowPermissionRequest: false) == .schedule)
    }

    @Test("A workout action may request permission but never overrides denial")
    func workoutActionPermission() {
        #expect(RestNotificationPermissionPolicy.action(status: .notDetermined, allowPermissionRequest: true) == .request)
        #expect(RestNotificationPermissionPolicy.action(status: .denied, allowPermissionRequest: true) == .cancel)
    }
}
