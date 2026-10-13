import XCTest
import IOKit.hid
@testable import Mus

final class MouseDeviceTests: XCTestCase {
    private func device(_ changes: [String: Any] = [:]) -> MouseDevice? {
        var properties: [String: Any] = [kIOHIDPrimaryUsagePageKey: 1, kIOHIDPrimaryUsageKey: 2,
            kIOHIDProductKey: "MX Anywhere 3S", kIOHIDManufacturerKey: "Logitech",
            kIOHIDVendorIDKey: 0x046d, kIOHIDTransportKey: "Bluetooth Low Energy"]
        properties.merge(changes) { _, new in new }
        return MouseDevice.make(id: 42, properties: properties)
    }
    override func tearDown() { L10n.language = .system; super.tearDown() }

    func testActualBluetoothMouseMetadata() throws {
        L10n.language = .english
        let mouse = try XCTUnwrap(device())
        XCTAssertEqual(mouse.brand, "Logitech")
        XCTAssertEqual(mouse.connection, "Bluetooth")
        XCTAssertTrue(mouse.isMXAnywhere3S)
        XCTAssertFalse(mouse.isReceiver)
    }

    func testRejectsKeyboardMouseCollectionsAndTrackpads() {
        XCTAssertNil(device([kIOHIDPrimaryUsageKey: 6, kIOHIDProductKey: "Keychron K3 Max"]))
        XCTAssertNil(device([kIOHIDProductKey: "Magic Trackpad"]))
        XCTAssertNil(device(["Built-In": true]))
        XCTAssertNil(device([kIOHIDPrimaryUsagePageKey: 12]))
    }

    func testBoltRequiresVerifiedUSBIdentityAndDoesNotImplyConnectedMouse() throws {
        L10n.language = .english
        let bolt = try XCTUnwrap(device([kIOHIDProductKey: "USB Receiver", kIOHIDProductIDKey: 0xc548, kIOHIDTransportKey: "USB"]))
        XCTAssertTrue(bolt.isBolt)
        XCTAssertTrue(bolt.isReceiver)
        XCTAssertEqual(bolt.connection, "Logi Bolt wireless receiver")
        XCTAssertEqual(bolt.title, "Logi Bolt Receiver")
        XCTAssertFalse(bolt.isMXAnywhere3S)
        XCTAssertFalse(try XCTUnwrap(device([kIOHIDProductIDKey: 0xc548])).isBolt)
        XCTAssertFalse(try XCTUnwrap(device([kIOHIDProductIDKey: 0xc548, kIOHIDVendorIDKey: 1, kIOHIDTransportKey: "USB"])).isBolt)
        let usb = try XCTUnwrap(device([kIOHIDProductKey: "USB Mouse", kIOHIDTransportKey: "USB"]))
        XCTAssertEqual(usb.connection, "USB (wired or receiver)")
    }

    func testUnknownMetadataAndReceiversNeverInventMouseModel() throws {
        L10n.language = .english
        let receiver = try XCTUnwrap(device([kIOHIDProductKey: "USB Receiver", kIOHIDTransportKey: "USB"]))
        XCTAssertTrue(receiver.isReceiver)
        XCTAssertFalse(receiver.isMXAnywhere3S)
        let unknown = try XCTUnwrap(device([kIOHIDProductKey: "", kIOHIDManufacturerKey: "", kIOHIDVendorIDKey: 0, kIOHIDTransportKey: ""]))
        XCTAssertEqual(unknown.brand, "Unknown brand")
        XCTAssertEqual(unknown.title, "Mouse (model unavailable)")
        XCTAssertEqual(unknown.connection, "Unknown connection")
        XCTAssertFalse(unknown.isMXAnywhere3S)
    }
}
