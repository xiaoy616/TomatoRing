import Foundation
import Combine

struct DayStat: Codable {
    var pomodoros: Int = 0
    var focusMinutes: Int = 0
    var rests: Int = 0
}

struct DayEntry: Identifiable {
    let id: String
    let date: Date
    let stat: DayStat
}

/// 按天累计的番茄统计，存成一个小 JSON 文件。
final class StatsStore: ObservableObject {
    static let shared = StatsStore()

    @Published private(set) var days: [String: DayStat] = [:]

    private let fileURL: URL
    private let keyFormatter: DateFormatter

    private init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support")
        let dir = base.appendingPathComponent("TomatoRing", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("stats.json")

        keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM-dd"
        keyFormatter.locale = Locale(identifier: "en_US_POSIX")
        keyFormatter.timeZone = .current

        load()
    }

    // MARK: - 读取

    var today: DayStat { days[key(for: Date())] ?? DayStat() }

    var totalPomodoros: Int { days.values.reduce(0) { $0 + $1.pomodoros } }
    var totalFocusMinutes: Int { days.values.reduce(0) { $0 + $1.focusMinutes } }
    var activeDays: Int { days.values.filter { $0.pomodoros > 0 }.count }

    /// 今日目标完成情况（用每多少个番茄长休息来估算一天的目标）
    func recent(_ count: Int = 7) -> [DayEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<count).reversed().compactMap { offset -> DayEntry? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = keyFormatter.string(from: date)
            return DayEntry(id: key, date: date, stat: days[key] ?? DayStat())
        }
    }

    // MARK: - 写入

    func addPomodoro(minutes: Int) {
        mutate { stat in
            stat.pomodoros += 1
            stat.focusMinutes += max(0, minutes)
        }
    }

    func addRest() {
        mutate { $0.rests += 1 }
    }

    func reset() {
        days = [:]
        save()
    }

    private func mutate(_ change: (inout DayStat) -> Void) {
        let key = keyFormatter.string(from: Date())
        var stat = days[key] ?? DayStat()
        change(&stat)
        days[key] = stat
        save()
    }

    private func key(for date: Date) -> String {
        keyFormatter.string(from: date)
    }

    // MARK: - 持久化

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard let decoded = try? JSONDecoder().decode([String: DayStat].self, from: data) else { return }
        days = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(days) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
