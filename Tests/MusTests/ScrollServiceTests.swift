import AppKit
import XCTest
import MouseCore
@testable import Mus

final class ScrollServiceTests: XCTestCase {
    func testTimerStopsAtEndAndCancelNeverPostsPendingMotion() {
        var now: TimeInterval = 0
        var events: [CGEvent] = []
        let service = ScrollService(clock: { now }, frontmostPID: { 1 }, postEvent: { events.append($0) })
        let event = CGEvent(source: nil)!
        service.accept(ScrollDelta(y: 20), event: event, settings: ScrollSettings())
        XCTAssertTrue(service.isAnimating)
        now = 0.2; service.tick()
        XCTAssertFalse(service.isAnimating)
        XCTAssertEqual(events.map { $0.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) }, [20])
        service.accept(ScrollDelta(y: 20), event: event, settings: ScrollSettings())
        service.cancel()
        now = 0.4; service.tick()
        XCTAssertFalse(service.isAnimating)
        XCTAssertEqual(events.count, 1)
    }
    func testSwitchingAppsAndStalledRunLoopDiscardPendingMotion() {
        var now: TimeInterval = 0
        var pid: pid_t = 1
        var count = 0
        let service = ScrollService(clock: { now }, frontmostPID: { pid }, postEvent: { _ in count += 1 })
        let event = CGEvent(source: nil)!
        service.accept(ScrollDelta(y: 20), event: event, settings: ScrollSettings())
        pid = 2; now = 0.02; service.tick()
        XCTAssertFalse(service.isAnimating)
        XCTAssertEqual(count, 0)
        service.accept(ScrollDelta(y: 20), event: event, settings: ScrollSettings())
        now = 1; service.tick()
        XCTAssertFalse(service.isAnimating)
        XCTAssertEqual(count, 0)
    }
    func testImmediateModeKeepsFractionalPixelsWithoutStartingTimer() {
        var total: Int64 = 0
        let service = ScrollService(frontmostPID: { 1 }, postEvent: { total += $0.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) })
        var settings = ScrollSettings(); settings.smooth = false
        for _ in 0..<100 { service.accept(ScrollDelta(y: 0.3), event: CGEvent(source: nil)!, settings: settings) }
        XCTAssertFalse(service.isAnimating)
        XCTAssertEqual(total, 30)
    }
    func testNewInputAfterStallStartsFreshMotion() {
        var now: TimeInterval = 0
        var total: Int64 = 0
        let service = ScrollService(clock: { now }, frontmostPID: { 1 }, postEvent: { total += $0.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) })
        let event = CGEvent(source: nil)!
        service.accept(ScrollDelta(y: 100), event: event, settings: ScrollSettings())
        now = 1
        service.accept(ScrollDelta(y: 10), event: event, settings: ScrollSettings())
        now = 1.21; service.tick()
        XCTAssertEqual(total, 10)
        XCTAssertFalse(service.isAnimating)
    }
}
