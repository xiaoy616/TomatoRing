import SwiftUI

struct StatsView: View {
    @ObservedObject private var store = StatsStore.shared
    @StateObject private var clearConfirm = TwoStepConfirm()

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "EEE"
        return f
    }()

    private var entries: [DayEntry] { store.recent(7) }
    private var peak: Int { max(1, entries.map { $0.stat.pomodoros }.max() ?? 0) }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height, alignment: .center)
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    StatCard(
                        value: "\(store.today.pomodoros)",
                        unit: "个",
                        label: "今日番茄",
                        tint: .ringGreen
                    )
                    StatCard(
                        value: "\(store.today.focusMinutes)",
                        unit: "分钟",
                        label: "今日专注",
                        tint: .breakGreen
                    )
                }

                chart

                VStack(spacing: 0) {
                    totalRow(title: "累计番茄", value: "\(store.totalPomodoros) 个")
                    Divider().padding(.vertical, 6)
                    totalRow(title: "累计专注", value: formatMinutes(store.totalFocusMinutes))
                    Divider().padding(.vertical, 6)
                    totalRow(title: "记录天数", value: "\(store.activeDays) 天")
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )

                Button {
                    clearConfirm.trigger { store.reset() }
                } label: {
                    Text(clearConfirm.pending ? "确认清空" : "清空数据")
                        .font(.system(size: 11, weight: clearConfirm.pending ? .semibold : .regular))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
        }
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近 7 天")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(entries) { entry in
                    VStack(spacing: 5) {
                        Text("\(entry.stat.pomodoros)")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)

                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(entry.id == entries.last?.id ? Color.ringGreen : Color.ringGreen.opacity(0.30))
                            .frame(height: barHeight(entry.stat.pomodoros))

                        Text(Self.weekdayFormatter.string(from: entry.date))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 108, alignment: .bottom)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private func barHeight(_ count: Int) -> CGFloat {
        guard count > 0 else { return 3 }
        let ratio = CGFloat(count) / CGFloat(peak)
        return max(8, ratio * 74)
    }

    private func totalRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
        }
    }
}

private struct StatCard: View {
    let value: String
    let unit: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}
