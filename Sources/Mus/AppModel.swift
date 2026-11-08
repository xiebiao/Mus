import AppKit
import ApplicationServices
import Observation
import ServiceManagement
import MouseCore

enum MonitoringStatus: String {
    case waitingForPermission = "等待辅助功能权限"
    case stopped = "监听尚未启动"
    case running = "正在运行"
    case paused = "已暂停"

    var title: String { L10n.text(rawValue) }
}

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
    private var legacySettings: MouseSettings
    private var profiles: [String: MouseSettings] = [:]
    private var ambiguousKeys: Set<String>
    private(set) var mice: [MouseDevice] = []
    private(set) var selectedID: UInt64?
    private var preferredKey: String?
    private(set) var allPaused: Bool

    var selectedMouse: MouseDevice? { mice.first { $0.id == selectedID } }

    private func profileKey(_ mouse: MouseDevice) -> String {
        if let key = mouse.persistentKey, !ambiguousKeys.contains(key) { return key }
        return "session-" + String(mouse.id, radix: 16)
    }

    func displayID(_ mouse: MouseDevice) -> String {
        let key = profileKey(mouse)
        if key.hasPrefix("session-") { return "S-" + String(mouse.id, radix: 16).uppercased() }
        var length = 6
        while length < key.count && mice.contains(where: { $0.id != mouse.id && profileKey($0).prefix(length) == key.prefix(length) }) {
            length += 1
        }
        return key.prefix(length).uppercased()
    }

    var settings: MouseSettings {
        get { selectedMouse.flatMap { profiles[profileKey($0)] } ?? legacySettings }
        set {
            guard newValue.isValid else { return }
            if let mouse = selectedMouse {
                let key = profileKey(mouse)
                profiles[key] = newValue
                if !key.hasPrefix("session-") {
                    defaults.set(try? JSONEncoder().encode(newValue), forKey: "mouse.profile." + key)
                }
            } else {
                // Legacy imports and callers without a selected device edit the initial template.
                legacySettings = newValue
                defaults.set(try? JSONEncoder().encode(newValue), forKey: "mouseSettings.v1")
            }
            if !newValue.enabled { cancelLearning() }
            configureDevices()
            onChange?()
        }
    }

    func selectMouse(_ id: UInt64) {
        guard let mouse = mice.first(where: { $0.id == id && !$0.isReceiver }) else { return }
        if selectedID != id { cancelLearning(); learnedButton = nil; notice = nil }
        selectedID = id
        preferredKey = profileKey(mouse)
        if mouse.persistentKey == preferredKey { defaults.set(preferredKey, forKey: "selectedMouseProfile") }
    }

    func updateDevices(_ devices: [MouseDevice]) {
        let configurable = devices.filter { !$0.isReceiver }
        let groups = Dictionary(grouping: configurable.compactMap(\.persistentKey), by: { $0 })
        let collisions = groups.filter { $0.value.count > 1 }.keys
        if !ambiguousKeys.isSuperset(of: collisions) {
            for mouse in mice {
                let key = profileKey(mouse)
                if collisions.contains(key), configurable.contains(where: { $0.id == mouse.id }) {
                    profiles["session-" + String(mouse.id, radix: 16)] = profiles[key]
                }
            }
            ambiguousKeys.formUnion(collisions)
            defaults.set(Array(ambiguousKeys), forKey: "ambiguousMouseProfiles")
        }
        mice = devices
        for mouse in configurable {
            let key = profileKey(mouse)
            if profiles[key] == nil, let data = defaults.data(forKey: "mouse.profile." + key),
               let saved = try? JSONDecoder().decode(MouseSettings.self, from: data), saved.isValid {
                profiles[key] = saved
            }
        }
        let next = configurable.first { profileKey($0) == preferredKey } ??
            configurable.first { $0.id == selectedID } ?? configurable.first
        if next?.id != selectedID { cancelLearning(); learnedButton = nil; notice = nil }
        selectedID = next?.id
        configureDevices()
        onChange?()
    }

    private func configureDevices() {
        var effective: [UInt64: MouseSettings] = [:]
        for mouse in mice where !mouse.isReceiver {
            var value = profiles[profileKey(mouse)] ?? legacySettings
            if allPaused { value.enabled = false }
            effective[mouse.id] = value
        }
        service.updateSettings(effective)
    }

    func togglePauseAll() {
        cancelLearning()
        allPaused.toggle()
        defaults.set(allPaused, forKey: "allMicePaused")
        configureDevices()
        onChange?()
    }
    @ObservationIgnored private let deviceMonitor = MouseDeviceMonitor()
    private(set) var hasPermission = false
    private(set) var waitingForPermission = false
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
    @ObservationIgnored private let service: EventTapService
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var learningTimer: Timer?

    @ObservationIgnored private var permissionTimer: Timer?

    var monitoringStatus: MonitoringStatus {
        if !hasPermission { return .waitingForPermission }
        if !running { return .stopped }
        return allPaused ? .paused : .running
    }

    init(defaults: UserDefaults = .standard, legacyDefaults: [UserDefaults]? = nil, service: EventTapService = EventTapService()) {
        self.service = service
        self.defaults = defaults
        allPaused = defaults.bool(forKey: "allMicePaused")
        preferredKey = defaults.string(forKey: "selectedMouseProfile")
        ambiguousKeys = Set(defaults.stringArray(forKey: "ambiguousMouseProfiles") ?? [])
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
            legacySettings = saved
        } else {
            legacySettings = MouseSettings()
            if defaults.data(forKey: "mouseSettings.v1") != nil {
                notice = L10n.text("保存的设置无法读取，已使用默认值。")
            }
        }
        service.onButton = { [weak self] id, button in
            guard self?.selectedID == id else { return }
            self?.learned(button)
        }
        service.onStatus = { [weak self] message in
            self?.notice = message
            self?.running = self?.service.isRunning ?? false
            self?.onChange?()
        }
    }

    func refresh() {
        deviceMonitor.onChange = { [weak self] devices in
            if self?.mice != devices { self?.updateDevices(devices) }
        }
        deviceMonitor.start()
        updatePermission(AXIsProcessTrusted())
        loginEnabled = SMAppService.mainApp.status == .enabled
        loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
        onChange?()
    }

    private func updatePermission(_ granted: Bool) {
        hasPermission = granted
        if granted {
            stopPermissionChecks()
            waitingForPermission = false
            running = service.start()
            return
        }

        service.stop()
        running = false
        cancelLearning()
        guard permissionTimer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if AXIsProcessTrusted() {
                self.updatePermission(true)
                self.onChange?()
            }
        }
        timer.tolerance = 0.2
        permissionTimer = timer
    }

    private func stopPermissionChecks() {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    func openPermissionSettings() {
        if AXIsProcessTrusted() {
            updatePermission(true)
            onChange?()
            return
        }
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        waitingForPermission = NSWorkspace.shared.open(url)
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
        guard selectedID != nil, !allPaused, settings.enabled else { return }
        guard running else { notice = L10n.text("请先授予辅助功能权限并启动监听。"); return }
        cancelLearning()
        learningRear = rear
        service.learningDevice = selectedID
        learningTimer = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { [weak self] _ in
            self?.cancelLearning()
            self?.notice = L10n.text("未收到侧键事件。请确认鼠标已连接，并退出其他鼠标映射工具。")
        }
    }

    func cancelLearning() {
        learningTimer?.invalidate()
        learningTimer = nil
        learningRear = nil
        service.learningDevice = nil
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

    func suspend() { stopPermissionChecks(); deviceMonitor.stop(); cancelLearning(); service.stop(); running = false; onChange?() }
    func resetSettings() {
        guard selectedMouse != nil else { return }
        cancelLearning()
        settings = MouseSettings()
        notice = L10n.text("已恢复默认设置。")
    }

    func copyDiagnostics() {
        let report = """
        Mus \(AppResources.version)
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
        Scope: per-device side buttons and discrete wheel events
        Device ID: \(selectedMouse.map(displayID) ?? "—")
        All paused: \(allPaused)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        notice = L10n.text("诊断信息已复制，不包含键盘输入或自定义快捷键内容。")
    }
}
