import CoreGraphics
import IOKit.hid
import XCTest
import MouseCore
@testable import Mus

final class DeviceProfileTests: XCTestCase {
    private let suite = "local.mus.tests.profiles." + UUID().uuidString
    private var defaults: UserDefaults { UserDefaults(suiteName: suite)! }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        L10n.language = .system
        super.tearDown()
    }

    private func mouse(_ id: UInt64, serial: String) throws -> MouseDevice {
        try XCTUnwrap(MouseDevice.make(id: id, properties: [
            kIOHIDPrimaryUsagePageKey: 1, kIOHIDPrimaryUsageKey: 2,
            kIOHIDProductKey: "MX Anywhere 3S", kIOHIDVendorIDKey: 0x046d,
            kIOHIDTransportKey: "Bluetooth", kIOHIDSerialNumberKey: serial
        ]))
    }

    private func event(_ sender: UInt64, button: Int64 = 3) throws -> CGEvent {
        let event = try XCTUnwrap(CGEvent(mouseEventSource: nil, mouseType: .otherMouseDown,
                                          mouseCursorPosition: .zero, mouseButton: .center))
        event.setIntegerValueField(CGEventField(rawValue: 87)!, value: Int64(bitPattern: sender))
        event.setIntegerValueField(.mouseEventButtonNumber, value: button)
        return event
    }

    func testSameButtonUsesSendingMouseWhileBothButtonsAreHeld() throws {
        var sent: [Shortcut] = []
        let service = EventTapService { sent.append($0) }
        let model = AppModel(defaults: defaults, service: service)
        let first = try mouse(11, serial: "first"), second = try mouse(22, serial: "second")
        model.updateDevices([first, second])
        model.selectMouse(first.id)
        model.settings.rear.action = .copy
        model.settings.reverseVertical = true
        model.selectMouse(second.id)
        model.settings.rear.action = .paste
        let a = try event(first.id), b = try event(second.id)
        XCTAssertTrue(service.handle(type: .otherMouseDown, event: a) == nil)
        XCTAssertTrue(service.handle(type: .otherMouseDown, event: b) == nil)
        XCTAssertTrue(service.handle(type: .otherMouseDown, event: a) == nil)
        XCTAssertEqual(sent, [ButtonAction.copy.shortcut!, ButtonAction.paste.shortcut!])
        XCTAssertTrue(service.handle(type: .otherMouseUp, event: b) == nil)
        XCTAssertTrue(service.handle(type: .otherMouseUp, event: a) == nil)
        for unknownID: UInt64 in [0, 99] {
            XCTAssertTrue(service.handle(type: .otherMouseDown, event: try event(unknownID)) != nil)
        }

        for (sender, expected) in [(first.id, Int64(-2)), (second.id, Int64(2))] {
            let input = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1,
                                              wheel1: 2, wheel2: 0, wheel3: 0))
            input.setIntegerValueField(CGEventField(rawValue: 87)!, value: Int64(bitPattern: sender))
            XCTAssertTrue(service.handle(type: .scrollWheel, event: input) != nil)
            XCTAssertEqual(input.getIntegerValueField(.scrollWheelEventDeltaAxis1), expected)
        }

        model.settings.enabled = false
        model.togglePauseAll()
        XCTAssertTrue(service.handle(type: .otherMouseDown, event: a) != nil)
        model.togglePauseAll()
        XCTAssertTrue(service.handle(type: .otherMouseDown, event: b) != nil)
        XCTAssertTrue(service.handle(type: .otherMouseDown, event: a) == nil)
        XCTAssertEqual(sent.last, ButtonAction.copy.shortcut)
        XCTAssertEqual(sent.count, 3)
    }

    func testSelectionProfilesAndIDsSurviveRelaunchAndReconnect() throws {
        let model = AppModel(defaults: defaults)
        let a = try mouse(11, serial: "first"), b = try mouse(22, serial: "second")
        model.updateDevices([a, b])
        XCTAssertNotEqual(model.displayID(a), model.displayID(b))
        model.settings.rear.action = .paste
        model.selectMouse(b.id)
        model.settings.rear.action = .undo
        model.settings.scroll.speed = 0.75
        let restored = AppModel(defaults: defaults)
        let newA = try mouse(33, serial: "first"), newB = try mouse(44, serial: "second")
        restored.updateDevices([newB, newA])
        XCTAssertEqual(restored.selectedID, newB.id)
        XCTAssertEqual(restored.displayID(newB), model.displayID(b))
        XCTAssertEqual(restored.settings.rear.action, .undo)
        XCTAssertEqual(restored.settings.scroll.speed, 0.75)
        restored.updateDevices([newA])
        XCTAssertEqual(restored.selectedID, newA.id)
        XCTAssertEqual(restored.settings.rear.action, .paste)
        XCTAssertEqual(restored.settings.scroll.speed, 1)
        restored.updateDevices([])
        XCTAssertNil(restored.selectedID)
    }

    func testDuplicateHardwareIDsStayIndependentAndDoNotRestoreToAnotherMouse() throws {
        let model = AppModel(defaults: defaults)
        let first = try mouse(11, serial: "duplicate"), second = try mouse(22, serial: "duplicate")
        model.updateDevices([first])
        model.settings.rear.action = .paste
        model.updateDevices([first, second])
        XCTAssertNotEqual(model.displayID(first), model.displayID(second))
        XCTAssertEqual(model.settings.rear.action, .paste)
        model.selectMouse(second.id)
        XCTAssertEqual(model.settings.rear.action, .back)
        model.settings.rear.action = .undo
        model.selectMouse(first.id)
        XCTAssertEqual(model.settings.rear.action, .paste)
        let restored = AppModel(defaults: defaults)
        restored.updateDevices([try mouse(33, serial: "duplicate")])
        XCTAssertEqual(restored.settings.rear.action, .back)
    }

    func testLearningAcceptsOnlySelectedMouseAndConsumesItsMatchingRelease() throws {
        var sent: [Shortcut] = []
        let service = EventTapService { sent.append($0) }
        let model = AppModel(defaults: defaults, service: service)
        let a = try mouse(11, serial: "first"), b = try mouse(22, serial: "second")
        model.updateDevices([a, b])
        model.running = true
        model.learn(rear: true)
        XCTAssertTrue(service.handle(type: .otherMouseDown, event: try event(b.id)) == nil)
        XCTAssertEqual(sent, [ButtonAction.back.shortcut!])
        XCTAssertNotNil(model.learningRear)
        XCTAssertTrue(service.handle(type: .otherMouseDown, event: try event(a.id, button: 6)) == nil)
        XCTAssertEqual(model.settings.rear.button, 6)
        model.selectMouse(b.id)
        XCTAssertEqual(model.settings.rear.button, 3)
        XCTAssertTrue(service.handle(type: .otherMouseUp, event: try event(a.id, button: 6)) == nil)
    }
}
