import AppKit
import Foundation
import UserNotifications

/// 系统提示音 + 通知封装。
enum Sound {
    static func play() {
        guard Settings.shared.soundEnabled else { return }
        if let sound = NSSound(named: NSSound.Name("Glass")) {
            sound.volume = 0.8
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}

final class Notifier: NSObject {
    static let shared = Notifier()
    static let restCategory = "REST_STARTED"
    static let skipAction = "SKIP_REST"
    static let restFinishedCategory = "REST_FINISHED"
    static let startFocusAction = "START_FOCUS"

    private let center = UNUserNotificationCenter.current()

    func prepare() {
        center.delegate = self
        let skip = UNNotificationAction(identifier: Self.skipAction, title: "跳过休息", options: [])
        let started = UNNotificationCategory(
            identifier: Self.restCategory,
            actions: [skip],
            intentIdentifiers: [],
            options: []
        )
        let startFocus = UNNotificationAction(identifier: Self.startFocusAction, title: "继续专注", options: [])
        let finished = UNNotificationCategory(
            identifier: Self.restFinishedCategory,
            actions: [startFocus],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([started, finished])
    }

    /// 检查真实授权状态；仅在未决定时弹系统授权框。
    func requestAuthorizationIfNeeded(_ completion: ((Bool) -> Void)? = nil) {
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                    if let error {
                        AppLog.write("notification auth failed: \(error.localizedDescription)")
                    } else {
                        AppLog.write("notification auth granted=\(granted)")
                    }
                    DispatchQueue.main.async { completion?(granted) }
                }
            case .authorized, .provisional, .ephemeral:
                AppLog.write("notification already authorized (status=\(settings.authorizationStatus.rawValue))")
                DispatchQueue.main.async { completion?(true) }
            default:
                AppLog.write("notification authorization denied by system settings (status=\(settings.authorizationStatus.rawValue))")
                DispatchQueue.main.async { completion?(false) }
            }
        }
    }

    func post(title: String, body: String, category: String? = nil, delay: TimeInterval = 0) {
        guard Settings.shared.notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let category {
            content.categoryIdentifier = category
        }
        let trigger: UNNotificationTrigger? = delay > 0
            ? UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            : nil
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error {
                AppLog.write("notification post FAILED: \(error.localizedDescription)")
            } else {
                AppLog.write("notification posted ok: \(title)")
            }
        }
    }
}

extension Notifier: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case Self.skipAction:
            DispatchQueue.main.async { TimerEngine.shared.skip() }
        case Self.startFocusAction:
            DispatchQueue.main.async {
                if TimerEngine.shared.phase == .idle {
                    TimerEngine.shared.toggle()
                }
            }
        default:
            break
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

/// 设置页里展示通知权限状态 / 发测试通知的小工具。
final class NotificationProbe: ObservableObject {
    static let shared = NotificationProbe()

    @Published private(set) var status: String = "检查中…"
    private init() {}

    func refresh() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let text: String
            switch settings.authorizationStatus {
            case .authorized: text = "已允许"
            case .provisional, .ephemeral: text = "临时允许"
            case .denied: text = "已拒绝"
            case .notDetermined: text = "未授权"
            @unknown default: text = "未知状态"
            }
            AppLog.write("settings: auth=\(settings.authorizationStatus.rawValue) alert=\(settings.alertSetting.rawValue) style=\(settings.alertStyle.rawValue) sound=\(settings.soundSetting.rawValue) badge=\(settings.badgeSetting.rawValue) nc=\(settings.notificationCenterSetting.rawValue) lock=\(settings.lockScreenSetting.rawValue) previews=\(settings.showPreviewsSetting.rawValue) scheduled=\(settings.scheduledDeliverySetting.rawValue) timeSensitive=\(settings.timeSensitiveSetting.rawValue) critical=\(settings.criticalAlertSetting.rawValue)")
            DispatchQueue.main.async {
                self.status = text
            }
        }
    }

    func openSystemSettings() {
        let deepLink = "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(Bundle.main.bundleIdentifier ?? "")"
        if let url = URL(string: deepLink), NSWorkspace.shared.open(url) {
            return
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
