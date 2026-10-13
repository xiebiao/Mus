import XCTest
import CoreGraphics
@testable import MouseCore

final class EventProcessorTests: XCTestCase {
    private func mouse(_ type: CGEventType, button: Int64 = 3) -> CGEvent {
        let event = CGEvent(source: nil)!
        event.type = type
        event.setIntegerValueField(.mouseEventButtonNumber, value: button)
        return event
    }

    private func scroll(continuous: Bool = false, phase: Int64 = 0, momentum: Int64 = 0) -> CGEvent {
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2,
                            wheel1: 3, wheel2: -2, wheel3: 0)!
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: continuous ? 1 : 0)
        event.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase)
        event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentum)
        return event
    }

    func testSideButtonTriggersOnceAndConsumesPairedEvents() {
        let processor = EventProcessor()
        XCTAssertEqual(processor.process(type: .otherMouseDown, event: mouse(.otherMouseDown)), .shortcut(ButtonAction.back.shortcut!))
        XCTAssertEqual(processor.process(type: .otherMouseDown, event: mouse(.otherMouseDown)), .suppress)
        XCTAssertEqual(processor.process(type: .otherMouseDragged, event: mouse(.otherMouseDragged)), .suppress)
        XCTAssertEqual(processor.process(type: .otherMouseUp, event: mouse(.otherMouseUp)), .suppress)
        XCTAssertEqual(processor.process(type: .otherMouseUp, event: mouse(.otherMouseUp)), .pass)
    }

    func testTwoHeldButtonsDoNotShareState() {
        let processor = EventProcessor()
        _ = processor.process(type: .otherMouseDown, event: mouse(.otherMouseDown, button: 3))
        XCTAssertEqual(processor.process(type: .otherMouseDown, event: mouse(.otherMouseDown, button: 4)), .shortcut(ButtonAction.forward.shortcut!))
        XCTAssertEqual(processor.process(type: .otherMouseUp, event: mouse(.otherMouseUp, button: 3)), .suppress)
        XCTAssertEqual(processor.process(type: .otherMouseUp, event: mouse(.otherMouseUp, button: 4)), .suppress)
    }

    func testPausingWhileHeldStillConsumesReleaseButPassesNextPress() {
        let processor = EventProcessor()
        _ = processor.process(type: .otherMouseDown, event: mouse(.otherMouseDown))
        processor.settings.enabled = false
        XCTAssertEqual(processor.process(type: .otherMouseUp, event: mouse(.otherMouseUp)), .suppress)
        XCTAssertEqual(processor.process(type: .otherMouseDown, event: mouse(.otherMouseDown)), .pass)
        XCTAssertEqual(processor.process(type: .otherMouseUp, event: mouse(.otherMouseUp)), .pass)
    }

    func testChangingBindingWhileHeldStillConsumesOldRelease() {
        let processor = EventProcessor()
        _ = processor.process(type: .otherMouseDown, event: mouse(.otherMouseDown))
        processor.settings.rear = ButtonBinding(button: 6, action: .paste)
        XCTAssertEqual(processor.process(type: .otherMouseUp, event: mouse(.otherMouseUp, button: 3)), .suppress)
        XCTAssertEqual(processor.process(type: .otherMouseDown, event: mouse(.otherMouseDown, button: 6)), .shortcut(ButtonAction.paste.shortcut!))
    }

    func testUnmappedOrPrimaryButtonsPassThrough() {
        let processor = EventProcessor()
        for button: Int64 in [0, 1, 2, 5, 9] {
            for type in [CGEventType.otherMouseDown, .otherMouseUp, .otherMouseDragged] {
                XCTAssertEqual(processor.process(type: type, event: mouse(type, button: button)), .pass)
            }
        }
        processor.settings.rear.button = 0
        XCTAssertEqual(processor.process(type: .otherMouseDown, event: mouse(.otherMouseDown, button: 0)), .pass)
    }

    func testNativeAndUnrecordedCustomBindingsAreNotSwallowed() {
        let processor = EventProcessor()
        for action in [ButtonAction.native, .custom] {
            processor.settings.rear.action = action
            XCTAssertEqual(processor.process(type: .otherMouseDown, event: mouse(.otherMouseDown)), .pass)
            XCTAssertEqual(processor.process(type: .otherMouseUp, event: mouse(.otherMouseUp)), .pass)
        }
    }

    func testDisabledButtonSwallowsDownDragAndUp() {
        let processor = EventProcessor()
        processor.settings.rear.action = .disabled
        for type in [CGEventType.otherMouseDown, .otherMouseDragged, .otherMouseUp] {
            XCTAssertEqual(processor.process(type: type, event: mouse(type)), .suppress)
        }
    }

    func testCustomShortcutAndGeneratedEventBypass() {
        let processor = EventProcessor()
        let shortcut = Shortcut(keyCode: 40, modifiers: CGEventFlags.maskCommand.rawValue, label: "⌘K")
        processor.settings.rear = ButtonBinding(button: 3, action: .custom, custom: shortcut)
        let event = mouse(.otherMouseDown)
        event.setIntegerValueField(.eventSourceUserData, value: EventProcessor.ownEventMarker)
        XCTAssertEqual(processor.process(type: .otherMouseDown, event: event), .pass)
        XCTAssertEqual(processor.process(type: .otherMouseDown, event: mouse(.otherMouseDown)), .shortcut(shortcut))
    }

    func testVerticalAndHorizontalCanBeChangedIndependently() {
        let processor = EventProcessor()
        processor.settings.reverseVertical = true
        let event = scroll()
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 30)
        _ = processor.process(type: .scrollWheel, event: event)
        XCTAssertEqual(event.getIntegerValueField(.scrollWheelEventDeltaAxis1), -3)
        XCTAssertEqual(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1), -30)
        XCTAssertEqual(event.getIntegerValueField(.scrollWheelEventDeltaAxis2), -2)
        processor.settings.reverseVertical = false
        processor.settings.reverseHorizontal = true
        let horizontal = scroll()
        _ = processor.process(type: .scrollWheel, event: horizontal)
        XCTAssertEqual(horizontal.getIntegerValueField(.scrollWheelEventDeltaAxis1), 3)
        XCTAssertEqual(horizontal.getIntegerValueField(.scrollWheelEventDeltaAxis2), 2)
    }

    func testFractionalHighResolutionDeltasArePreserved() {
        let processor = EventProcessor()
        processor.settings.reverseVertical = true
        let event = scroll()
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 1.25)
        _ = processor.process(type: .scrollWheel, event: event)
        XCTAssertEqual(event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1), -1.25, accuracy: 0.0001)
    }

    func testTrackpadAndMomentumAreNeverInverted() {
        let processor = EventProcessor()
        processor.settings.reverseVertical = true
        processor.settings.reverseHorizontal = true
        for event in [scroll(continuous: true), scroll(phase: 1), scroll(momentum: 1)] {
            _ = processor.process(type: .scrollWheel, event: event)
            XCTAssertEqual(event.getIntegerValueField(.scrollWheelEventDeltaAxis1), 3)
            XCTAssertEqual(event.getIntegerValueField(.scrollWheelEventDeltaAxis2), -2)
        }
    }

    func testPausedScrollAndOwnScrollAreUntouched() {
        let processor = EventProcessor()
        processor.settings.reverseVertical = true
        processor.settings.enabled = false
        let event = scroll()
        _ = processor.process(type: .scrollWheel, event: event)
        XCTAssertEqual(event.getIntegerValueField(.scrollWheelEventDeltaAxis1), 3)
        processor.settings.enabled = true
        event.setIntegerValueField(.eventSourceUserData, value: EventProcessor.ownEventMarker)
        _ = processor.process(type: .scrollWheel, event: event)
        XCTAssertEqual(event.getIntegerValueField(.scrollWheelEventDeltaAxis1), 3)
    }

    func testResetClearsHeldStateAfterWake() {
        let processor = EventProcessor()
        _ = processor.process(type: .otherMouseDown, event: mouse(.otherMouseDown))
        processor.reset()
        XCTAssertEqual(processor.process(type: .otherMouseDown, event: mouse(.otherMouseDown)), .shortcut(ButtonAction.back.shortcut!))
    }

    func testSettingsRoundTripIncludingLearnedButtonsAndCustomShortcut() throws {
        var settings = MouseSettings()
        settings.rear = ButtonBinding(button: 6, action: .custom,
            custom: Shortcut(keyCode: 40, modifiers: CGEventFlags.maskCommand.rawValue, label: "⌘K"))
        settings.reverseHorizontal = true
        settings.enabled = false
        let restored = try JSONDecoder().decode(MouseSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(restored, settings)
        XCTAssertTrue(restored.isValid)
    }

    func testInvalidSettingsAreRejected() {
        var settings = MouseSettings()
        settings.front.button = settings.rear.button
        XCTAssertFalse(settings.isValid)
        settings.front.button = 4
        settings.rear.button = 0
        XCTAssertFalse(settings.isValid)
        settings.rear.button = 3
        settings.rear.custom = Shortcut(keyCode: 255, modifiers: 0, label: "invalid")
        XCTAssertFalse(settings.isValid)
        settings.rear.custom = Shortcut(keyCode: 40, modifiers: UInt64.max, label: "invalid")
        XCTAssertFalse(settings.isValid)
    }

    func testDesktopSwitchBindingsPersistAndSendControlArrowOncePerPress() throws {
        var settings = MouseSettings()
        settings.rear.action = .desktopLeft
        settings.front.action = .desktopRight
        let restored = try JSONDecoder().decode(MouseSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(restored, settings)
        let processor = EventProcessor()
        processor.settings = restored
        for (button, code, label): (Int64, UInt16, String) in [(3, 123, "⌃←"), (4, 124, "⌃→")] {
            let expected = Shortcut(keyCode: code, modifiers: CGEventFlags.maskControl.rawValue, label: label)
            XCTAssertEqual(processor.process(type: .otherMouseDown, event: mouse(.otherMouseDown, button: button)), .shortcut(expected))
            XCTAssertEqual(processor.process(type: .otherMouseDown, event: mouse(.otherMouseDown, button: button)), .suppress)
            XCTAssertEqual(processor.process(type: .otherMouseUp, event: mouse(.otherMouseUp, button: button)), .suppress)
        }
    }
}
