import CoreGraphics

public enum EventDecision: Equatable {
    case pass
    case suppress
    case shortcut(Shortcut)
    case scroll(ScrollDelta)
}

/// Runs only on the event tap's run loop. Does no I/O or UI work.
public final class EventProcessor {
    public static let ownEventMarker: Int64 = 0x54494E594C4F4749
    public var settings: MouseSettings
    private var consumedButtons: Set<Int64> = []

    public init(settings: MouseSettings = MouseSettings()) { self.settings = settings }
    public func reset() { consumedButtons.removeAll() }

    public func process(type: CGEventType, event: CGEvent) -> EventDecision {
        if event.getIntegerValueField(.eventSourceUserData) == Self.ownEventMarker { return .pass }
        let button = event.getIntegerValueField(.mouseEventButtonNumber)

        // Finish an already-consumed press even when settings change while held.
        if type == .otherMouseUp, consumedButtons.remove(button) != nil { return .suppress }
        if type == .otherMouseDragged, consumedButtons.contains(button) { return .suppress }
        guard settings.enabled else { return .pass }

        if type == .scrollWheel {
            // Preserve touchpad / Magic Mouse continuous scrolling and momentum.
            guard event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0,
                  event.getIntegerValueField(.scrollWheelEventScrollPhase) == 0,
                  event.getIntegerValueField(.scrollWheelEventMomentumPhase) == 0 else { return .pass }
            // Preserve native zoom and other modifier-based scrolling.
            if settings.scroll.enabled && !event.flags.intersection([.maskControl, .maskCommand]).isEmpty { return .pass }
            if settings.scroll.enabled {
                return .scroll(ScrollDelta(
                    x: tunedDelta(event, point: .scrollWheelEventPointDeltaAxis2, fixed: .scrollWheelEventFixedPtDeltaAxis2,
                                  line: .scrollWheelEventDeltaAxis2) * (settings.reverseHorizontal ? -1 : 1),
                    y: tunedDelta(event, point: .scrollWheelEventPointDeltaAxis1, fixed: .scrollWheelEventFixedPtDeltaAxis1,
                                  line: .scrollWheelEventDeltaAxis1) * (settings.reverseVertical ? -1 : 1)))
            }
            if settings.reverseVertical {
                invert(event, fields: [.scrollWheelEventDeltaAxis1,
                                      .scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventPointDeltaAxis1])
            }
            if settings.reverseHorizontal {
                invert(event, fields: [.scrollWheelEventDeltaAxis2,
                                      .scrollWheelEventFixedPtDeltaAxis2, .scrollWheelEventPointDeltaAxis2])
            }
            return .pass
        }

        guard type == .otherMouseDown,
              let binding = settings.binding(for: button), binding.consumesEvent else { return .pass }
        guard consumedButtons.insert(button).inserted else { return .suppress }
        if let shortcut = binding.resolvedShortcut { return .shortcut(shortcut) }
        return .suppress
    }

    private func tunedDelta(_ event: CGEvent, point: CGEventField, fixed: CGEventField, line: CGEventField) -> Double {
        let pixels = Double(event.getIntegerValueField(point))
        let fractionalLines = event.getDoubleValueField(fixed)
        let lines = Double(event.getIntegerValueField(line))
        let value = pixels != 0 ? pixels : (fractionalLines != 0 ? fractionalLines : lines) * settings.scroll.minimumStep
        guard value.isFinite, value != 0 else { return 0 }
        let magnitude = min(2000, max(abs(value), settings.scroll.minimumStep) * settings.scroll.speed)
        return value < 0 ? -magnitude : magnitude
    }

    private func invert(_ event: CGEvent, fields: [CGEventField]) {
        // Setting line delta also rewrites the fixed/point deltas on macOS.
        // Snapshot first, then restore each inverted representation in order.
        let line = event.getIntegerValueField(fields[0])
        let fixed = event.getDoubleValueField(fields[1])
        let point = event.getIntegerValueField(fields[2])
        event.setIntegerValueField(fields[0], value: line == Int64.min ? Int64.max : -line)
        event.setDoubleValueField(fields[1], value: -fixed)
        event.setIntegerValueField(fields[2], value: point == Int64.min ? Int64.max : -point)
    }
}
