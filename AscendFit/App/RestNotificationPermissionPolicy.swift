import UserNotifications

/// Permission changes are reread on activation; only a workout action may prompt.
enum RestNotificationPermissionPolicy {
    enum Action: Equatable { case request, schedule, cancel }

    static func action(status: UNAuthorizationStatus, allowPermissionRequest: Bool) -> Action {
        switch status {
        case .notDetermined: allowPermissionRequest ? .request : .cancel
        case .authorized, .provisional, .ephemeral: .schedule
        case .denied: .cancel
        @unknown default: .cancel
        }
    }
}
