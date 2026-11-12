import Foundation
import Combine

/// 所有偏好设置，直接绑定到 UserDefaults，改完立即落盘。
final class Settings: ObservableObject {
    static let shared = Settings()

    private let defaults = UserDefaults.standard
    private var isLoading = true

    @Published var workMinutes: Int = 45 {
        didSet { persist(workMinutes, "workMinutes", 1...180) }
    }
    @Published var shortRestMinutes: Int = 10 {
        didSet { persist(shortRestMinutes, "shortRestMinutes", 1...60) }
    }
    @Published var longRestMinutes: Int = 20 {
        didSet { persist(longRestMinutes, "longRestMinutes", 1...120) }
    }
    /// 每完成多少个番茄安排一次长休息
    @Published var longRestEvery: Int = 2 {
        didSet { persist(longRestEvery, "longRestEvery", 2...12) }
    }
    @Published var showMenuBarText: Bool = true {
        didSet { defaults.set(showMenuBarText, forKey: "showMenuBarText") }
    }
    @Published var soundEnabled: Bool = true {
        didSet { defaults.set(soundEnabled, forKey: "soundEnabled") }
    }
    /// 长休息结束后回到空闲，而不是直接开始下一轮
    @Published var stopAfterRest: Bool = true {
        didSet { defaults.set(stopAfterRest, forKey: "stopAfterRest") }
    }
    @Published var notificationsEnabled: Bool = true {
        didSet { defaults.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    private init() {
        let d = defaults
        workMinutes = Self.read(d, "workMinutes", 45)
        shortRestMinutes = Self.read(d, "shortRestMinutes", 10)
        longRestMinutes = Self.read(d, "longRestMinutes", 20)
        longRestEvery = Self.read(d, "longRestEvery", 2)
        showMenuBarText = d.object(forKey: "showMenuBarText") as? Bool ?? true
        soundEnabled = d.object(forKey: "soundEnabled") as? Bool ?? true
        stopAfterRest = d.object(forKey: "stopAfterRest") as? Bool ?? true
        notificationsEnabled = d.object(forKey: "notificationsEnabled") as? Bool ?? true
        isLoading = false
    }

    private static func read(_ d: UserDefaults, _ key: String, _ fallback: Int) -> Int {
        guard let value = d.object(forKey: key) as? Int, value > 0 else { return fallback }
        return value
    }

    private func persist(_ value: Int, _ key: String, _ range: ClosedRange<Int>) {
        guard !isLoading else { return }
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        defaults.set(clamped, forKey: key)
        guard clamped != value else { return }
        // 手动输入越界时把值修正回来（再触发一次 didSet 后即稳定）
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch key {
            case "workMinutes": self.workMinutes = clamped
            case "shortRestMinutes": self.shortRestMinutes = clamped
            case "longRestMinutes": self.longRestMinutes = clamped
            case "longRestEvery": self.longRestEvery = clamped
            default: break
            }
        }
    }
}
