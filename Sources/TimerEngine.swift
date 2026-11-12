import AppKit
import Combine
import Foundation

/// 番茄钟核心：idle → work → rest → (work | idle) 的状态机 + 基于结束时刻的计时。
final class TimerEngine: ObservableObject {
    static let shared = TimerEngine()

    enum Phase: Equatable {
        case idle
        case work
        case shortRest
        case longRest

        var isRest: Bool { self == .shortRest || self == .longRest }

        var title: String {
            switch self {
            case .idle: return "待开始"
            case .work: return "专注"
            case .shortRest: return "短休息"
            case .longRest: return "长休息"
            }
        }

        var accent: NSColor {
            switch self {
            case .work, .idle: return .ringGreen
            case .shortRest, .longRest: return .ringBlue
            }
        }
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var paused = false
    @Published private(set) var remaining: Double = 0
    @Published private(set) var total: Double = 0
    @Published private(set) var completedInSet: Int = 0

    /// 0…1，已过去的比例（圆环填充量）
    var progress: Double {
        guard total > 0 else { return 0 }
        return min(max(1 - remaining / total, 0), 1)
    }

    var isActive: Bool { phase != .idle }
    var isRunning: Bool { isActive && !paused }
    var timeText: String { formatDuration(remaining) }

    /// 每次 tick 或状态变化后通知外部刷新菜单栏
    var onUpdate: (() -> Void)?

    private let settings = Settings.shared
    private let stats = StatsStore.shared
    private var endsAt: Date?
    private var timer: DispatchSourceTimer?

    private init() {}

    // MARK: - 控制

    func toggle() {
        Notifier.shared.requestAuthorizationIfNeeded()
        switch phase {
        case .idle: startWork()
        default:
            if paused { resume() } else { pause() }
        }
    }

    /// 休息中 → 直接进入下一轮专注；专注中 → 放弃本轮
    func skip() {
        switch phase {
        case .shortRest, .longRest:
            startWork()
        case .work:
            abandon()
        case .idle:
            break
        }
    }

    func reset() {
        abandon()
    }

    // MARK: - 状态迁移

    private func startWork() {
        phase = .work
        begin(seconds: Double(max(1, settings.workMinutes)) * 60)
    }

    private func startRest() {
        let useLong = completedInSet >= max(2, settings.longRestEvery)
        phase = useLong ? .longRest : .shortRest
        let seconds = Double(useLong ? settings.longRestMinutes : settings.shortRestMinutes) * 60
        if useLong { completedInSet = 0 }
        let restText = useLong ? "长休息 \(settings.longRestMinutes) 分钟" : "休息 \(settings.shortRestMinutes) 分钟"
        begin(seconds: max(60, seconds))
        AppDelegate.shared?.yieldFrontmostForNotification()
        Notifier.shared.post(
            title: "专注完成",
            body: restText,
            category: Notifier.restCategory
        )
    }

    private func abandon() {
        stopTimer()
        phase = .idle
        paused = false
        remaining = 0
        total = 0
        endsAt = nil
        completedInSet = 0
        notifyUpdate()
    }

    private func begin(seconds: Double) {
        total = seconds
        remaining = seconds
        endsAt = Date().addingTimeInterval(seconds)
        paused = false
        startTimer()
        notifyUpdate()
    }

    private func pause() {
        remaining = liveRemaining
        endsAt = nil
        paused = true
        stopTimer()
        notifyUpdate()
    }

    private func resume() {
        guard remaining > 0 else { return }
        endsAt = Date().addingTimeInterval(remaining)
        paused = false
        startTimer()
        notifyUpdate()
    }

    // MARK: - 计时

    private var liveRemaining: Double {
        guard let endsAt else { return remaining }
        return max(0, endsAt.timeIntervalSinceNow)
    }

    private func startTimer() {
        stopTimer()
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now(), repeating: .milliseconds(200), leeway: .milliseconds(40))
        source.setEventHandler { [weak self] in self?.tick() }
        source.resume()
        timer = source
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        guard endsAt != nil else { return }
        remaining = liveRemaining
        if remaining <= 0 {
            finishPhase(overshoot: -remaining)
        } else {
            notifyUpdate()
        }
    }

    private func finishPhase(overshoot: Double) {
        stopTimer()
        let finished = phase

        // 睡眠/休眠导致大幅超时，就不连续推进，直接回到空闲
        if overshoot > 180 {
            abandon()
            return
        }

        switch finished {
        case .work:
            completedInSet += 1
            stats.addPomodoro(minutes: settings.workMinutes)
            Sound.play()
            startRest()
        case .shortRest, .longRest:
            stats.addRest()
            Sound.play()
            AppDelegate.shared?.yieldFrontmostForNotification()
            Notifier.shared.post(
                title: "休息结束",
                body: "专注 \(settings.workMinutes) 分钟",
                category: Notifier.restFinishedCategory
            )
            if settings.stopAfterRest {
                abandon()
            } else {
                startWork()
            }
        case .idle:
            break
        }
    }

    private func notifyUpdate() {
        onUpdate?()
    }

    // MARK: - 展示

    var phaseLabel: String {
        if paused { return "暂停" }
        return phase.title
    }

    var sessionText: String {
        "\(min(completedInSet + (phase == .work ? 1 : 0), max(2, settings.longRestEvery))) / \(max(2, settings.longRestEvery))"
    }

    var primaryActionTitle: String {
        if phase == .idle { return "开始" }
        return paused ? "继续" : "暂停"
    }

    var secondaryActionTitle: String {
        phase.isRest ? "跳过休息" : "放弃"
    }
}
