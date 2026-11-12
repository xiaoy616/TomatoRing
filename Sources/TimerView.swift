import SwiftUI

extension TimerEngine.Phase {
    var color: Color {
        switch self {
        case .work, .idle: return .ringGreen
        case .shortRest, .longRest: return .ringBlue
        }
    }
}

struct TimerView: View {
    @ObservedObject private var engine = TimerEngine.shared
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var stats = StatsStore.shared
    @StateObject private var abandonConfirm = TwoStepConfirm()

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            ring

            Text(engine.sessionText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 12)

            HStack(spacing: 8) {
                Button {
                    engine.toggle()
                } label: {
                    Text(engine.primaryActionTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(engine.phase.color)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    if engine.phase.isRest {
                        engine.skip()
                    } else {
                        abandonConfirm.trigger { engine.skip() }
                    }
                } label: {
                    Text(engine.phase.isRest ? "跳过休息" : (abandonConfirm.pending ? "确认放弃" : "放弃"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(abandonConfirm.pending ? Color.white : (engine.isActive ? Color.primary : Color.secondary))
                        .frame(width: 92)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(abandonConfirm.pending ? Color.red.opacity(0.85) : Color.primary.opacity(0.07))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!engine.isActive)
                .opacity(engine.isActive ? 1 : 0.45)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)

            Spacer(minLength: 12)

            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 10))
                Text("今日 \(stats.today.pomodoros) 个番茄 · \(formatMinutes(stats.today.focusMinutes))")
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, 14)
        }
    }

    private var ringColor: Color {
        if engine.paused { return .ringYellow }
        return engine.isActive ? engine.phase.color : Color.ringGreen.opacity(0.5)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(engine.paused ? 0.28 : 0.16), lineWidth: 16)

            Circle()
                .trim(from: 0, to: engine.isActive ? max(engine.progress, 0.0001) : 1)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.2), value: engine.progress)

            VStack(spacing: 4) {
                Text(engine.timeText)
                    .font(.system(size: 40, weight: .medium, design: .rounded))
                    .monospacedDigit()
                Text(engine.phaseLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 200, height: 200)
    }
}
