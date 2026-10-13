import CoreGraphics
import XCTest
@testable import MouseCore

final class ShortcutEventsTests: XCTestCase {
    func testControlArrowsPreserveNativeArrowFlagsOnDownAndUp() throws {
        for code: UInt16 in [123, 124, 125, 126] {
            let shortcut = Shortcut(keyCode: code, modifiers: CGEventFlags.maskControl.rawValue, label: "Control arrow")
            let events = try XCTUnwrap(ShortcutEvents.make(for: shortcut))
            XCTAssertEqual(events.map(\.type), [.keyDown, .keyUp])
            for event in events {
                XCTAssertEqual(event.getIntegerValueField(.keyboardEventKeycode), Int64(code))
                XCTAssertTrue(event.flags.contains(.maskControl))
                XCTAssertTrue(event.flags.contains(.maskNumericPad), "Arrow key identity must survive modifier assignment")
                XCTAssertTrue(event.flags.contains(.maskSecondaryFn), "Arrow key identity must survive modifier assignment")
                XCTAssertEqual(event.getIntegerValueField(.eventSourceUserData), EventProcessor.ownEventMarker)
            }
        }
    }

    func testLetterShortcutDoesNotAcquireArrowFlags() throws {
        let events = try XCTUnwrap(ShortcutEvents.make(for: ButtonAction.copy.shortcut!))
        for event in events {
            XCTAssertEqual(event.getIntegerValueField(.keyboardEventKeycode), 8)
            XCTAssertEqual(event.flags.intersection([.maskCommand, .maskControl, .maskShift, .maskAlternate]), .maskCommand)
            XCTAssertFalse(event.flags.contains(.maskNumericPad))
            XCTAssertFalse(event.flags.contains(.maskSecondaryFn))
        }
    }

    func testFunctionKeyRetainsSystemAssignedIdentityFlags() throws {
        let shortcut = ButtonAction.desktop.shortcut!
        let original = try XCTUnwrap(CGEvent(keyboardEventSource: CGEventSource(stateID: .privateState), virtualKey: shortcut.keyCode, keyDown: true))
        let identityFlags: CGEventFlags = [.maskNumericPad, .maskSecondaryFn]
        for event in try XCTUnwrap(ShortcutEvents.make(for: shortcut)) {
            XCTAssertEqual(event.flags.intersection(identityFlags), original.flags.intersection(identityFlags))
        }
    }
}
