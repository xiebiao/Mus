import AppKit
import ApplicationServices
import Observation
import ServiceManagement
import MouseCore

@Observable
final class AppModel {
    var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: "interfaceLanguage")
            L10n.language = language
            cancelLearning()
            notice = nil
            onChange?()
        }
    }
    var settings: MouseSettings {
        didSet {
            guard settings.isValid else { settings = oldValue; return }
            if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: "mouseSettings.v1") }
            service.updateSettings(settings)
            onChange?()
        }
    }
    var mice: [MouseDevice] = []
    @ObservationIgnored private let deviceMonitor = MouseDeviceMonitor()
    var hasPermission = false
    var running = false
    var loginEnabled = false
    var loginNeedsApproval = false
    var notice: String?
    var learningRear: Bool?
    private var learnedButton: (rear: Bool, number: Int64)?
    var lastButton: String {
        guard let learnedButton else { return L10n.text("侧键顺序不对？点“识别”后按对应侧键即可。") }
        return L10n.format("已识别 %@ · 按键 %lld", learnedButton.rear ? L10n.text("后侧键") : L10n.text("前侧键"), learnedButton.number)
    }
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let service = EventTapService()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var learningTimer: Timer?

    var status: String {
        if !hasPermission { return L10n.text("等待辅助功能权限") }
        if !running { return L10n.text("监听尚未启动") }
        return settings.enabled ? L10n.text("正在运行") : L10n.text("已暂停")
    }

    init(defaults: UserDefaults = .standard, legacyDefaults: [UserDefaults]? = nil) {
        self.defaults = defaults
        // Prefer the latest app identity, and never overwrite settings already saved by Mus.
        // Isolated test/preview defaults do not read the user's real preferences.
        let previous = legacyDefaults ?? (defaults === UserDefaults.standard
            ? ["local.tinymouse.app", "local.tinylogi.app"].compactMap { UserDefaults(suiteName: $0) } : [])
        if defaults.data(forKey: "mouseSettings.v1") == nil {
            for old in previous {
                guard let data = old.data(forKey: "mouseSettings.v1"),
                      let saved = try? JSONDecoder().decode(MouseSettings.self, from: data), saved.isValid else { continue }
                defaults.set(data, forKey: "mouseSettings.v1")
                break
            }
        }
        if defaults.string(forKey: "interfaceLanguage") == nil {
            for old in previous {
                guard let language = old.string(forKey: "interfaceLanguage"), AppLanguage(rawValue: language) != nil else { continue }
                defaults.set(language, forKey: "interfaceLanguage")
                break
            }
        }
        let savedLanguage = AppLanguage(rawValue: defaults.string(forKey: "interfaceLanguage") ?? "system") ?? .system
        language = savedLanguage
        L10n.language = savedLanguage
        if let data = defaults.data(forKey: "mouseSettings.v1"),
           let saved = try? JSONDecoder().decode(MouseSettings.self, from: data), saved.isValid {
            settings = saved
        } else {
            settings = MouseSettings()
            if defaults.data(forKey: "mouseSettings.v1") != nil {
                notice = L10n.text("保存的设置无法读取，已使用默认值。")
            }
        }
        service.updateSettings(settings)
        service.onButton = { [weak self] button in self?.learned(button) }
        service.onStatus = { [weak self] message in
            self?.notice = message
            self?.running = self?.service.isRunning ?? false
            self?.onChange?()
        }
    }

    func refresh() {
        deviceMonitor.onChange = { [weak self] devices in
            if self?.mice != devices { self?.mice = devices }
        }
        deviceMonitor.start()
        hasPermission = AXIsProcessTrusted()
        if hasPermission { running = service.start() }
        else { service.stop(); running = false; cancelLearning() }
        loginEnabled = SMAppService.mainApp.status == .enabled
        loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
        onChange?()
    }

    func openPermissionSettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            notice = nil
        } catch { notice = L10n.format("开机启动设置失败：%@", error.localizedDescription) }
        loginEnabled = SMAppService.mainApp.status == .enabled
        loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
    }

    func learn(rear: Bool) {
        guard running else { notice = L10n.text("请先授予辅助功能权限并启动监听。"); return }
        cancelLearning()
        learningRear = rear
        service.learning = true
        learningTimer = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { [weak self] _ in
            self?.cancelLearning()
            self?.notice = L10n.text("未收到侧键事件。请确认鼠标已连接，并退出其他鼠标映射工具。")
        }
    }

    func cancelLearning() {
        learningTimer?.invalidate()
        learningTimer = nil
        learningRear = nil
        service.learning = false
    }

    private func learned(_ button: Int64) {
        guard let rear = learningRear else { return }
        var updated = settings
        if rear {
            if updated.front.button == button { updated.front.button = updated.rear.button }
            updated.rear.button = button
        } else {
            if updated.rear.button == button { updated.rear.button = updated.front.button }
            updated.front.button = button
        }
        settings = updated
        learnedButton = (rear, button + 1)
        cancelLearning()
        notice = nil
    }

    func suspend() { deviceMonitor.stop(); cancelLearning(); service.stop(); running = false; onChange?() }
    func resetSettings() { cancelLearning(); settings = MouseSettings(); notice = L10n.text("已恢复默认设置。") }

    func copyDiagnostics() {
        let report = """
        Mus 0.1.0
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Accessibility: \(hasPermission)
        Event tap: \(running)
        Enabled: \(settings.enabled)
        Reverse vertical / horizontal: \(settings.reverseVertical) / \(settings.reverseHorizontal)
        Scroll tuning / smooth: \(settings.scroll.enabled) / \(settings.scroll.smooth)
        Scroll minimum step / speed / duration: \(settings.scroll.minimumStep) / \(settings.scroll.speed) / \(settings.scroll.duration)
        Rear / front button: \(settings.rear.button) / \(settings.front.button)
        Actions: \(settings.rear.action.rawValue) / \(settings.front.action.rawValue)
        Login: \(SMAppService.mainApp.status.rawValue)
        Scope: all standard mouse side-button and discrete wheel events
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        notice = L10n.text("诊断信息已复制，不包含键盘输入或自定义快捷键内容。")
    }
}
