import XCTest
import CoreGraphics
@testable import MouseCore

final class ScrollTests: XCTestCase {
    private func wheel(x: Int32 = 0, y: Int32 = 1) -> CGEvent {
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: y, wheel2: x, wheel3: 0)!
        // Some devices supply only line deltas; exercise that fallback deterministically.
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: 0)
        return event
    }
    private func processor() -> EventProcessor {
        let processor = EventProcessor()
        processor.settings.scroll.enabled = true
        processor.settings.scroll.minimumStep = 12
        processor.settings.scroll.speed = 0.5
        return processor
    }

    func testTuningAppliesDistanceSpeedAndPerAxisDirectionOnce() {
        let p = processor()
        p.settings.reverseVertical = true
        XCTAssertEqual(p.process(type: .scrollWheel, event: wheel(x: -2, y: 1)), .scroll(ScrollDelta(x: -12, y: -6)))
        p.settings.reverseHorizontal = true
        XCTAssertEqual(p.process(type: .scrollWheel, event: wheel(x: -2, y: 1)), .scroll(ScrollDelta(x: 12, y: -6)))
    }
    func testPointDeltasTakePriorityAndMinimumStepDoesNotInventZeroAxis() {
        let p = processor()
        let event = wheel()
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 40)
        XCTAssertEqual(p.process(type: .scrollWheel, event: event), .scroll(ScrollDelta(y: 20)))
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 2)
        XCTAssertEqual(p.process(type: .scrollWheel, event: event), .scroll(ScrollDelta(y: 6)))
    }
    func testContinuousMomentumZoomAndOwnEventsAreUntouched() {
        let p = processor()
        p.settings.reverseVertical = true
        for field in [CGEventField.scrollWheelEventIsContinuous, .scrollWheelEventScrollPhase, .scrollWheelEventMomentumPhase] {
            let e = wheel()
            e.setIntegerValueField(field, value: 1)
            XCTAssertEqual(p.process(type: .scrollWheel, event: e), .pass)
            XCTAssertEqual(e.getIntegerValueField(.scrollWheelEventDeltaAxis1), 1)
        }
        for flag in [CGEventFlags.maskControl, .maskCommand] {
            let e = wheel(); e.flags = flag
            XCTAssertEqual(p.process(type: .scrollWheel, event: e), .pass)
            XCTAssertEqual(e.getIntegerValueField(.scrollWheelEventDeltaAxis1), 1)
        }
        let e = wheel()
        e.setIntegerValueField(.eventSourceUserData, value: EventProcessor.ownEventMarker)
        XCTAssertEqual(p.process(type: .scrollWheel, event: e), .pass)
        p.settings.enabled = false
        XCTAssertEqual(p.process(type: .scrollWheel, event: wheel()), .pass)
    }
    func testSmoothDistanceIsConservedAtDifferentFrameRates() {
        for hz in [30.0, 60.0, 120.0] {
            var motion = ScrollMotion()
            motion.add(ScrollDelta(x: -21, y: 73), duration: 0.2)
            var total = ScrollDelta()
            for _ in 0..<100 {
                let frame = motion.advance(by: 1 / hz)
                total.x += frame.x; total.y += frame.y
            }
            XCTAssertEqual(total, ScrollDelta(x: -21, y: 73))
            XCTAssertFalse(motion.isActive)
        }
    }
    func testSmallInputsAccumulateWithoutLossInImmediateAndSmoothModes() {
        for frames in [1, 20] {
            var motion = ScrollMotion()
            var total: Double = 0
            for _ in 0..<100 {
                motion.add(ScrollDelta(y: 0.3), duration: 0.2)
                for _ in 0...frames { total += motion.advance(by: 0.2 / Double(frames)).y }
            }
            XCTAssertEqual(total, 30)
        }
    }
    func testDirectionChangeDiscardsOldTailOnlyOnReversedAxis() {
        var motion = ScrollMotion()
        motion.add(ScrollDelta(x: 10, y: 100), duration: 0.2)
        motion.add(ScrollDelta(y: -8), duration: 0.2)
        XCTAssertEqual(motion.advance(by: 0.2), ScrollDelta(x: 10, y: -8))
        XCTAssertFalse(motion.isActive)
    }
    func testAppendingInputPreservesAlreadyEmittedDistance() {
        var motion = ScrollMotion()
        motion.add(ScrollDelta(y: 80), duration: 0.2)
        let first = motion.advance(by: 0.05).y
        motion.add(ScrollDelta(y: 20), duration: 0.2)
        XCTAssertEqual(first + motion.advance(by: 0.2).y, 100)
    }
    func testResetDropsPendingMotionAndFraction() {
        var motion = ScrollMotion()
        motion.add(ScrollDelta(y: 100), duration: 0.2)
        _ = motion.advance(by: 0.01)
        motion.reset()
        XCTAssertFalse(motion.isActive)
        XCTAssertTrue(motion.advance(by: 1).isZero)
    }
    func testGeneratedScrollPreservesContextAndBypassesProcessor() throws {
        let event = try XCTUnwrap(ScrollEvents.make(delta: ScrollDelta(x: -4, y: 9), flags: .maskShift, location: CGPoint(x: 100, y: 200)))
        XCTAssertEqual(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1), 9)
        XCTAssertEqual(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2), -4)
        XCTAssertEqual(event.getIntegerValueField(.scrollWheelEventIsContinuous), 1)
        XCTAssertEqual(event.flags, .maskShift)
        XCTAssertEqual(event.location, CGPoint(x: 100, y: 200))
        XCTAssertEqual(processor().process(type: .scrollWheel, event: event), .pass)
    }
    func testOldSettingsMigrateWithoutChangingSideButtonsOrDirection() throws {
        let json = #"{"enabled":true,"reverseVertical":true,"reverseHorizontal":false,"front":{"button":4,"action":"desktopLeft"},"rear":{"button":3,"action":"desktopRight"}}"#
        let settings = try JSONDecoder().decode(MouseSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.scroll, ScrollSettings())
        XCTAssertFalse(settings.scroll.enabled)
        XCTAssertEqual(settings.front.action, .desktopLeft)
        XCTAssertEqual(settings.rear.action, .desktopRight)
        XCTAssertTrue(settings.reverseVertical)
        XCTAssertTrue(settings.isValid)
        XCTAssertEqual(try JSONDecoder().decode(MouseSettings.self, from: JSONEncoder().encode(settings)), settings)
    }
    func testRejectsInvalidTuningValuesAndBoundsMotion() {
        var settings = MouseSettings()
        settings.scroll.speed = .nan; XCTAssertFalse(settings.isValid)
        settings.scroll.speed = 1; settings.scroll.duration = 0; XCTAssertFalse(settings.isValid)
        settings.scroll.duration = 0.2; settings.scroll.minimumStep = 81; XCTAssertFalse(settings.isValid)
        var motion = ScrollMotion()
        motion.add(ScrollDelta(y: .infinity), duration: 0.2)
        XCTAssertFalse(motion.isActive)
        motion.add(ScrollDelta(y: 1e9), duration: 0.2)
        XCTAssertEqual(motion.advance(by: 1).y, 4000)
    }
}
