import AppKit
import QuartzCore
import MouseCore

/// Main-run-loop only. The frame timer exists only while a wheel burst is moving.
final class ScrollService {
    private var motion = ScrollMotion()
    private var timer: Timer?
    private var lastFrame: TimeInterval = 0
    private var flags: CGEventFlags = []
    private var location = CGPoint.zero
    private var targetPID: pid_t?
    private let clock: () -> TimeInterval
    private let frontmostPID: () -> pid_t?
    private let postEvent: (CGEvent) -> Void
    var isAnimating: Bool { timer != nil }

    init(clock: @escaping () -> TimeInterval = CACurrentMediaTime,
         frontmostPID: @escaping () -> pid_t? = { NSWorkspace.shared.frontmostApplication?.processIdentifier },
         postEvent: @escaping (CGEvent) -> Void = { $0.post(tap: .cgSessionEventTap) }) {
        self.clock = clock
        self.frontmostPID = frontmostPID
        self.postEvent = postEvent
    }
    deinit { timer?.invalidate() }

    func accept(_ delta: ScrollDelta, event: CGEvent, settings: ScrollSettings) {
        let pid = frontmostPID()
        if flags != event.flags || targetPID != pid { cancel() }
        if settings.smooth, timer != nil { tick() }
        flags = event.flags
        location = event.location
        targetPID = pid
        if settings.smooth {
            motion.add(delta, duration: settings.duration)
            guard motion.isActive, timer == nil else { return }
            lastFrame = clock()
            let newTimer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in self?.tick() }
            newTimer.tolerance = 0.002
            timer = newTimer
            RunLoop.main.add(newTimer, forMode: .common)
        } else {
            motion.add(delta, duration: 1)
            post(motion.advance(by: 1))
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        motion.reset()
        targetPID = nil
    }

    func tick() {
        guard timer != nil else { return }
        guard targetPID == frontmostPID() else { cancel(); return }
        let now = clock()
        // A stalled run loop should not deliver a large delayed jump.
        guard now - lastFrame < 0.25 else { cancel(); return }
        let delta = motion.advance(by: now - lastFrame)
        lastFrame = now
        post(delta)
        if !motion.isActive { timer?.invalidate(); timer = nil }
    }

    private func post(_ delta: ScrollDelta) {
        if let event = ScrollEvents.make(delta: delta, flags: flags, location: location) { postEvent(event) }
    }
}
