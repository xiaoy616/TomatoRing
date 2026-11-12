import AppKit
import Combine
import SwiftUI

final class UIModel: ObservableObject {
    enum Tab: String, CaseIterable {
        case timer, stats, settings

        var title: String {
            switch self {
            case .timer: return "计时"
            case .stats: return "统计"
            case .settings: return "设置"
            }
        }
    }

    @Published var tab: Tab = .timer
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    static weak var shared: AppDelegate?

    private let engine = TimerEngine.shared
    private let settings = Settings.shared
    let ui = UIModel()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var popoverAnchorWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 生命周期

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)
        Notifier.shared.prepare()
        Notifier.shared.requestAuthorizationIfNeeded()
        NotificationProbe.shared.refresh()

        setupPopover()
        setupStatusItem()
        registerURLHandler()

        engine.onUpdate = { [weak self] in self?.refreshStatusItem() }

        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshStatusItem() }
            .store(in: &cancellables)

        refreshStatusItem()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            AppDelegate.shared?.refreshDynamicState()
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { _ in
            AppDelegate.shared?.refreshDynamicState()
        }
    }

    /// 权限、登录项这类系统状态每次打开面板都重新读一次
    func refreshDynamicState() {
        NotificationProbe.shared.refresh()
        LoginItem.shared.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    // MARK: - 界面搭建

    private func setupPopover() {
        let root = PopoverRoot().environmentObject(ui)
        let controller = NSHostingController(rootView: root)
        controller.view.frame = NSRect(x: 0, y: 0, width: 300, height: 510)

        popover = NSPopover()
        popover.delegate = self
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 300, height: 510)
        popover.contentViewController = controller
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = RingImage.idle()
        button.imagePosition = .imageRight
        button.imageScaling = .scaleProportionallyDown
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// 系统通知如果在前台活跃时投递，会被静默处理；投递前先收起面板并让出前台。
    func yieldFrontmostForNotification() {
        guard NSApp.isActive || popover.isShown else { return }
        if popover.isShown {
            popover.performClose(nil)
        }
        NSApp.deactivate()
    }

    // MARK: - 菜单栏刷新

    func refreshStatusItem() {
        guard let button = statusItem?.button else { return }

        if !engine.isActive {
            button.image = RingImage.idle()
        } else {
            let tint: NSColor = engine.paused ? .ringYellow : engine.phase.accent
            button.image = RingImage.make(
                progress: engine.progress,
                color: tint,
                trackColor: tint.withAlphaComponent(engine.paused ? 0.45 : 0.28)
            )
        }

        let shouldShowText = settings.showMenuBarText && engine.isActive
        let text = shouldShowText ? engine.timeText : ""
        button.attributedTitle = NSAttributedString(
            string: text.isEmpty ? "" : text + " ",
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            ]
        )
    }

    // MARK: - 交互

    @objc private func handleStatusItemClick(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    func showPopover(tab: UIModel.Tab? = nil) {
        if let tab { ui.tab = tab }
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        refreshDynamicState()

        // 用固定锚点，避免状态栏宽度变化（比如开关倒计时）把面板推走
        let anchor = makeAnchorWindow(for: button)
        if let anchorView = anchor?.contentView {
            popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        popover.contentViewController?.view.window?.makeKey()
    }

    private func makeAnchorWindow(for button: NSStatusBarButton) -> NSWindow? {
        guard let buttonWindow = button.window else { return nil }
        let rectInWindow = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(rectInWindow)

        let anchor = NSWindow(
            contentRect: NSRect(x: screenRect.maxX - 18, y: screenRect.minY, width: 1, height: 1),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        anchor.isOpaque = false
        anchor.backgroundColor = .clear
        anchor.hasShadow = false
        anchor.ignoresMouseEvents = true
        anchor.level = .statusBar
        anchor.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        anchor.alphaValue = 0.01
        anchor.orderFrontRegardless()

        popoverAnchorWindow?.orderOut(nil)
        popoverAnchorWindow = anchor
        return anchor
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let primary = NSMenuItem(
            title: engine.phase == .idle ? "开始" : (engine.paused ? "继续" : "暂停"),
            action: #selector(menuToggle),
            keyEquivalent: ""
        )
        primary.target = self
        menu.addItem(primary)

        if engine.isActive {
            let skip = NSMenuItem(
                title: engine.phase.isRest ? "跳过休息" : "放弃",
                action: #selector(menuSkip),
                keyEquivalent: ""
            )
            skip.target = self
            menu.addItem(skip)
        }

        menu.addItem(.separator())

        let panel = NSMenuItem(title: "面板", action: #selector(menuShowPanel), keyEquivalent: "")
        panel.target = self
        menu.addItem(panel)

        let stats = NSMenuItem(title: "统计", action: #selector(menuShowStats), keyEquivalent: "")
        stats.target = self
        menu.addItem(stats)

        let settingsItem = NSMenuItem(title: "设置…", action: #selector(menuShowSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出", action: #selector(menuQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func menuToggle() { engine.toggle() }
    @objc private func menuSkip() {
        if engine.phase.isRest {
            engine.skip()
        } else if Confirm.ask(title: "放弃本轮？", message: "本轮不会计入统计。", confirmTitle: "放弃") {
            engine.skip()
        }
    }
    @objc private func menuShowPanel() { showPopover() }
    @objc private func menuShowStats() { showPopover(tab: .stats) }
    @objc private func menuShowSettings() { showPopover(tab: .settings) }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    // MARK: - URL 协议：tomatoring://startstop 等

    private func registerURLHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent _: NSAppleEventDescriptor) {
        guard let string = event.forKeyword(AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: string),
              url.scheme?.lowercased() == "tomatoring" else { return }

        switch url.host?.lowercased() {
        case "startstop", "toggle": engine.toggle()
        case "skip": engine.skip()
        case "reset": engine.reset()
        case "show", "timer": showPopover(tab: .timer)
        case "stats": showPopover(tab: .stats)
        case "settings": showPopover(tab: .settings)
        case "loginon": LoginItem.shared.set(true)
        case "loginoff": LoginItem.shared.set(false)
        case "quit": NSApp.terminate(nil)
        default: break
        }
    }
}

extension AppDelegate {
    /// 面板关闭后把被推迟的菜单栏变更补上
    func popoverDidClose(_ notification: Notification) {
        popoverAnchorWindow?.orderOut(nil)
        popoverAnchorWindow = nil
        refreshStatusItem()
    }
}
