import AppKit
import ApplicationServices
import MouseCore

final class EventTapService {
    private let router = MouseEventRouter()
    private var scrollingDevice: UInt64?
    private let scrolling = ScrollService()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var capturedButtons: [UInt64: Set<Int64>] = [:]
    var learningDevice: UInt64?
    var onButton: ((UInt64, Int64) -> Void)?
    var onStatus: ((String) -> Void)?
    var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    private let postShortcut: (Shortcut) -> Void

    init(postShortcut: @escaping (Shortcut) -> Void = EventTapService.send) {
        self.postShortcut = postShortcut
    }

    func start() -> Bool {
        if let tap, CFMachPortIsValid(tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
            return isRunning
        }
        stop()
        guard AXIsProcessTrusted() else { return false }
        let mask = [CGEventType.otherMouseDown, .otherMouseUp, .otherMouseDragged, .scrollWheel,
                    .leftMouseDown, .rightMouseDown, .mouseMoved, .leftMouseDragged, .rightMouseDragged]
            .reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                return Unmanaged<EventTapService>.fromOpaque(context).takeUnretainedValue()
                    .handle(type: type, event: event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        tap = newTap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        return isRunning
    }

    func stop() {
        scrolling.cancel()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil
        tap = nil
        router.reset()
        scrollingDevice = nil
        capturedButtons.removeAll()
        learningDevice = nil
    }

    func updateSettings(_ settings: [UInt64: MouseSettings]) {
        scrolling.cancel()
        router.configure(settings)
        capturedButtons = capturedButtons.filter { settings[$0.key] != nil }
    }

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            scrolling.cancel()
            if let tap, AXIsProcessTrusted() { CGEvent.tapEnable(tap: tap, enable: true) }
            // Publish outside the callback to keep the input path short.
            DispatchQueue.main.async { [weak self] in self?.onStatus?(L10n.text("事件监听已恢复；若操作无效，请检查权限。")) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == EventProcessor.ownEventMarker {
            return Unmanaged.passUnretained(event)
        }
        if [.leftMouseDown, .rightMouseDown, .otherMouseDown, .mouseMoved,
            .leftMouseDragged, .rightMouseDragged, .otherMouseDragged].contains(type)
            || (type == .scrollWheel && (event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
                || event.getIntegerValueField(.scrollWheelEventScrollPhase) != 0
                || event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
                || !event.flags.intersection([.maskControl, .maskCommand]).isEmpty)) {
            scrolling.cancel()
        }
        guard type == .otherMouseDown || type == .otherMouseUp || type == .otherMouseDragged || type == .scrollWheel,
              let (id, processor) = router.source(of: event) else {
            if type == .scrollWheel { scrolling.cancel() }
            return Unmanaged.passUnretained(event)
        }
        if type == .scrollWheel, scrollingDevice != id {
            scrolling.cancel()
            scrollingDevice = id
        }
        let button = event.getIntegerValueField(.mouseEventButtonNumber)
        if type == .otherMouseUp, capturedButtons[id]?.remove(button) != nil { return nil }
        if type == .otherMouseDragged, capturedButtons[id]?.contains(button) == true { return nil }
        if learningDevice == id, type == .otherMouseDown, (3...31).contains(button) {
            learningDevice = nil
            capturedButtons[id, default: []].insert(button)
            onButton?(id, button)
            return nil
        }
        switch processor.process(type: type, event: event) {
        case .pass: return Unmanaged.passUnretained(event)
        case .suppress: return nil
        case .shortcut(let shortcut):
            postShortcut(shortcut)
            return nil
        case .scroll(let delta):
            scrolling.accept(delta, event: event, settings: processor.settings.scroll)
            return nil
        }
    }

    private static func send(_ shortcut: Shortcut) {
        guard let events = ShortcutEvents.make(for: shortcut) else { return }
        for event in events {
            event.post(tap: .cgSessionEventTap)
        }
    }
}
