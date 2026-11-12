import Foundation
import ServiceManagement
import Combine

/// 开机自启：优先用 SMAppService，失败（ad-hoc 签名常见）则回退到 LaunchAgent。
final class LoginItem: ObservableObject {
    static let shared = LoginItem()

    @Published private(set) var isEnabled = false
    @Published private(set) var message: String?

    private let defaults = UserDefaults.standard
    private let agentLabel = "local.tomatoring.loginitem"

    private var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist")
    }

    private init() {
        refresh()
    }

    func refresh() {
        var enabled = FileManager.default.fileExists(atPath: agentURL.path)
        if #available(macOS 13.0, *) {
            enabled = enabled || SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval {
                message = "需在「系统设置 → 通用 → 登录项」中允许"
            } else if message?.hasPrefix("需在") == true {
                message = nil
            }
        }
        isEnabled = enabled
    }

    func set(_ enabled: Bool) {
        if enabled { enable() } else { disable() }
        refresh()
    }

    private func enable() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
                message = nil
                NSLog("login item registered via SMAppService (status=\(SMAppService.mainApp.status.rawValue))")
                return
            } catch {
                NSLog("SMAppService register failed: \(error.localizedDescription)")
            }
        }
        writeAgent()
    }

    private func disable() {
        if #available(macOS 13.0, *) {
            try? SMAppService.mainApp.unregister()
        }
        try? FileManager.default.removeItem(at: agentURL)
        message = nil
    }

    /// 回退方案：LaunchAgent 下次登录生效
    private func writeAgent() {
        guard let bundlePath = Bundle.main.bundlePath as String? else { return }
        let plist: [String: Any] = [
            "Label": agentLabel,
            "ProgramArguments": ["/usr/bin/open", bundlePath],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
        ]
        do {
            try FileManager.default.createDirectory(
                at: agentURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: agentURL, options: .atomic)
            message = "已写入登录项，下次登录生效"
            NSLog("login item fallback LaunchAgent written to \(agentURL.path)")
        } catch {
            message = "设置失败：\(error.localizedDescription)"
        }
    }
}
