import AppKit
import SwiftUI
import ApplicationServices

@main
enum MusApp {
    static func main() {
        if CommandLine.arguments.contains("--list-mice") {
            let monitor = MouseDeviceMonitor()
            monitor.onChange = { devices in
                for mouse in devices { print("\(mouse.brand) | \(mouse.title) | \(mouse.connection)") }
                if devices.isEmpty { print("No mouse detected") }
            }
            monitor.start()
            monitor.stop()
            return
        }
        if CommandLine.arguments.contains("--self-check") {
            print("Mus 0.1.0 | macOS 14+ | \(ProcessInfo.processInfo.operatingSystemVersionString)")
            print("Current process accessibility: \(AXIsProcessTrusted() ? "granted" : "not granted")")
            print("CLI permission may be inherited from the terminal. Check the GUI for the app permission.")
            print("Standard mouse events; Bluetooth / Bolt transport-independent. No HID++ access.")
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Do not leave duplicate event taps running after opening another build.
        let id = Bundle.main.bundleIdentifier ?? "local.mus.app"
        if NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSRunningApplication.runningApplications(withBundleIdentifier: id)
                .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier })?
                .activate(options: [.activateAllWindows])
            NSApp.terminate(nil)
            return
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        installMainMenu()
        model.onChange = { [weak self] in
            self?.updateMenu()
            self?.installMainMenu()
        }
        model.refresh()
        updateMenu()
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main) { [weak self] _ in self?.model.refresh() })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification,
            object: nil, queue: .main) { [weak self] _ in self?.model.cancelLearning() })
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main) { [weak self] _ in self?.model.suspend() })
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main) { [weak self] _ in self?.model.refresh() })
        let launchedAtLogin = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: keyAELaunchedAsLogInItem) != nil
        if !launchedAtLogin || !model.hasPermission { showSettings() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.suspend()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    @objc private func showSettings() {
        if window == nil {
            let created = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 850, height: 760),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            created.title = "Mus"
            created.titlebarAppearsTransparent = true
            created.isReleasedWhenClosed = false
            created.contentView = NSHostingView(rootView: SettingsView(model: model, onHide: { [weak self] in
                self?.model.cancelLearning()
                self?.window?.close()
            }))
            created.center()
            window = created
        }
        model.refresh()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleEnabled() { model.cancelLearning(); model.settings.enabled.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func installMainMenu() {
        let menu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "Mus")
        add(L10n.text("偏好设置…"), action: #selector(showSettings), key: ",", to: applicationMenu)
        applicationMenu.addItem(.separator())
        add(L10n.text("退出 Mus"), action: #selector(quit), key: "q", to: applicationMenu)
        applicationItem.submenu = applicationMenu
        menu.addItem(applicationItem)
        NSApp.mainMenu = menu
    }

    private func updateMenu() {
        guard statusItem != nil else { return }
        // Template rendering follows the menu bar appearance: white on dark, black on light.
        statusItem.button?.image = BrandImages.menuBar
        statusItem.button?.setAccessibilityLabel(L10n.text("Mus 状态栏菜单"))
        statusItem.button?.toolTip = "Mus · \(model.status)"
        let menu = NSMenu()
        let status = NSMenuItem(title: "Mus · \(model.status)", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())
        add(L10n.text("偏好设置…"), action: #selector(showSettings), key: ",", to: menu)
        add(model.settings.enabled ? L10n.text("暂停鼠标设置") : L10n.text("恢复鼠标设置"), action: #selector(toggleEnabled), to: menu)
        menu.addItem(.separator())
        add(L10n.text("退出 Mus"), action: #selector(quit), key: "q", to: menu)
        statusItem.menu = menu
    }

    private func add(_ title: String, action: Selector, key: String = "", to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }
}
