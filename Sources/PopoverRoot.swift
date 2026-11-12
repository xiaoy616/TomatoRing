import SwiftUI

struct PopoverRoot: View {
    @EnvironmentObject private var ui: UIModel

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            Group {
                switch ui.tab {
                case .timer: TimerView()
                case .stats: StatsView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 300, height: 510)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(UIModel.Tab.allCases, id: \.self) { tab in
                Button {
                    ui.tab = tab
                } label: {
                    Text(tab.title)
                        .font(.system(size: 12, weight: ui.tab == tab ? .semibold : .regular))
                        .foregroundStyle(ui.tab == tab ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(ui.tab == tab ? Color.primary.opacity(0.08) : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}
