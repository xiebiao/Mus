import AppKit
import ApplicationServices
import MouseCore

final class EventTapService {
    let processor = EventProcessor()
    private let scrolling = ScrollService()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var capturedButtons: Set<Int64> = []
    var learning = false
    var onButton: ((Int64) -> Void)?
    var onStatus: ((String) -> Void)?
    var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

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
        processor.reset()
        capturedButtons.removeAll()
        learning = false
    }

    func updateSettings(_ settings: MouseSettings) {
        scrolling.cancel()
        processor.settings = settings
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
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
        let button = event.getIntegerValueField(.mouseEventButtonNumber)
        if type == .otherMouseUp, capturedButtons.remove(button) != nil { return nil }
        if type == .otherMouseDragged, capturedButtons.contains(button) { return nil }
        if learning, type == .otherMouseDown, (3...31).contains(button) {
            learning = false
            capturedButtons.insert(button)
            DispatchQueue.main.async { [weak self] in self?.onButton?(button) }
            return nil
        }
        switch processor.process(type: type, event: event) {
        case .pass: return Unmanaged.passUnretained(event)
        case .suppress: return nil
        case .shortcut(let shortcut):
            send(shortcut)
            return nil
        case .scroll(let delta):
            scrolling.accept(delta, event: event, settings: processor.settings.scroll)
            return nil
        }
    }

    private func send(_ shortcut: Shortcut) {
        guard let events = ShortcutEvents.make(for: shortcut) else { return }
        for event in events {
            event.post(tap: .cgSessionEventTap)
        }
    }
}
