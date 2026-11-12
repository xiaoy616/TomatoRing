import AppKit

/// 破坏性操作前的确认框。
enum Confirm {
    static func ask(title: String, message: String, confirmTitle: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }
}

/// 面板内的二次确认：第一次点变红提示，4 秒内再点一次才执行。
final class TwoStepConfirm: ObservableObject {
    @Published private(set) var pending = false
    private var resetWork: DispatchWorkItem?

    func trigger(_ action: @escaping () -> Void) {
        if pending {
            resetWork?.cancel()
            resetWork = nil
            pending = false
            action()
            return
        }
        pending = true
        let work = DispatchWorkItem { [weak self] in
            self?.pending = false
            self?.resetWork = nil
        }
        resetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }

    func cancel() {
        resetWork?.cancel()
        resetWork = nil
        pending = false
    }
}
