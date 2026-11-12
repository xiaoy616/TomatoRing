import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = Settings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                group("时长") {
                    NumberRow(title: "专注", value: $settings.workMinutes, range: 1...180)
                    NumberRow(title: "短休息", value: $settings.shortRestMinutes, range: 1...60)
                    NumberRow(title: "长休息", value: $settings.longRestMinutes, range: 1...120)
                    NumberRow(title: "长休息间隔", value: $settings.longRestEvery, range: 2...12, unit: "个番茄")
                }

                group("启动") {
                    LoginItemRow()
                }

                group("提醒") {
                    ToggleRow(title: "提示音", isOn: $settings.soundEnabled)
                    ToggleRow(title: "系统通知", isOn: $settings.notificationsEnabled)
                    NotificationRow()
                }

                group("其他") {
                    ToggleRow(title: "菜单栏倒计时", isOn: $settings.showMenuBarText)
                    ToggleRow(title: "休息后停止", isOn: $settings.stopAfterRest)
                }

                Text("番茄环 1.0")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
            .padding(14)
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 4)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

private struct NumberRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var unit: String = "分钟"

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12))
            Spacer()

            TextField(
                "",
                value: Binding(
                    get: { value },
                    set: { value = min(max($0, range.lowerBound), range.upperBound) }
                ),
                format: .number
            )
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .font(.system(size: 12, design: .rounded).monospacedDigit())
            .frame(width: 44)

            Text(unit)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            Stepper("", value: $value, in: range)
                .labelsHidden()
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

private struct LoginItemRow: View {
    @ObservedObject private var login = LoginItem.shared

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text("开机启动")
                    .font(.system(size: 12))
                if let message = login.message {
                    Text(message)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Toggle(
                "",
                isOn: Binding(
                    get: { login.isEnabled },
                    set: { login.set($0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(.vertical, 3)
    }
}

private struct NotificationRow: View {
    @ObservedObject private var probe = NotificationProbe.shared

    var body: some View {
        HStack {
            Text("通知权限")
                .font(.system(size: 12))
            Spacer()
            if probe.status.contains("拒绝") {
                Button("去允许") { probe.openSystemSettings() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.blue)
            } else {
                Text(probe.status)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .onAppear { probe.refresh() }
    }
}

private struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
        .padding(.vertical, 4)
    }
}
