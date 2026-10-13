import CoreGraphics

public struct ScrollDelta: Equatable {
    public var x: Double
    public var y: Double
    public init(x: Double = 0, y: Double = 0) { self.x = x; self.y = y }
    public var isZero: Bool { x == 0 && y == 0 }
}

/// Finite ease-out motion, driven by elapsed time rather than the display rate.
/// Pixel remainders survive between frames and bursts so slow scrolling is not lost.
public struct ScrollMotion {
    private var remaining = ScrollDelta()
    private var fraction = ScrollDelta()
    private var direction = ScrollDelta()
    private var elapsed: Double = 0
    private var duration: Double = 0.2
    public var isActive: Bool { !remaining.isZero }
    public init() {}
    public mutating func reset() { self = ScrollMotion() }

    public mutating func add(_ delta: ScrollDelta, duration: Double) {
        guard !delta.isZero, delta.x.isFinite, delta.y.isFinite, duration.isFinite, duration > 0 else { return }
        if delta.x * direction.x < 0 { remaining.x = 0; fraction.x = 0 }
        if delta.y * direction.y < 0 { remaining.y = 0; fraction.y = 0 }
        if delta.x != 0 { direction.x = delta.x }
        if delta.y != 0 { direction.y = delta.y }
        remaining.x = max(-4000, min(4000, remaining.x + delta.x))
        remaining.y = max(-4000, min(4000, remaining.y + delta.y))
        elapsed = 0
        self.duration = duration
    }

    public mutating func advance(by seconds: Double) -> ScrollDelta {
        guard isActive, seconds.isFinite, seconds > 0 else { return ScrollDelta() }
        let oldT = min(1, elapsed / duration)
        elapsed = min(duration, elapsed + seconds)
        let newT = elapsed / duration
        let oldTail = (1 - oldT) * (1 - oldT) * (1 - oldT)
        let newTail = (1 - newT) * (1 - newT) * (1 - newT)
        let ratio = oldTail > 0 ? newTail / oldTail : 0
        let next = ScrollDelta(x: remaining.x * ratio, y: remaining.y * ratio)
        fraction.x += remaining.x - next.x
        fraction.y += remaining.y - next.y
        remaining = next
        let pixels = ScrollDelta(x: fraction.x.rounded(), y: fraction.y.rounded())
        fraction.x -= pixels.x
        fraction.y -= pixels.y
        return pixels
    }
}

public enum ScrollEvents {
    public static func make(delta: ScrollDelta, flags: CGEventFlags, location: CGPoint) -> CGEvent? {
        guard delta.x.isFinite, delta.y.isFinite, !delta.isZero,
              abs(delta.x) <= 4000, abs(delta.y) <= 4000,
              let event = CGEvent(scrollWheelEvent2Source: CGEventSource(stateID: .privateState), units: .pixel,
                                  wheelCount: 2, wheel1: Int32(delta.y.rounded()), wheel2: Int32(delta.x.rounded()), wheel3: 0) else { return nil }
        event.flags = flags
        event.location = location
        event.setIntegerValueField(.eventSourceUserData, value: EventProcessor.ownEventMarker)
        return event
    }
}
