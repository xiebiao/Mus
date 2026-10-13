import Foundation
import IOKit.hid

struct MouseDevice: Equatable, Identifiable {
    let id: UInt64
    let product: String
    let manufacturer: String
    let vendorID: Int
    let productID: Int
    let transport: String

    // Some keyboards advertise a mouse collection for macros. Do not present them as mice.
    static func make(id: UInt64, properties: [String: Any]) -> MouseDevice? {
        let name = (properties[kIOHIDProductKey] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = name.lowercased()
        guard (properties[kIOHIDPrimaryUsagePageKey] as? NSNumber)?.intValue == 1,
              (properties[kIOHIDPrimaryUsageKey] as? NSNumber)?.intValue == 2,
              !lower.contains("trackpad"), !lower.contains("touchpad"),
              (properties["Built-In"] as? NSNumber)?.boolValue != true else { return nil }
        return MouseDevice(id: id, product: name,
                           manufacturer: (properties[kIOHIDManufacturerKey] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                           vendorID: (properties[kIOHIDVendorIDKey] as? NSNumber)?.intValue ?? 0,
                           productID: (properties[kIOHIDProductIDKey] as? NSNumber)?.intValue ?? 0,
                           transport: properties[kIOHIDTransportKey] as? String ?? "")
    }

    var brand: String {
        if manufacturer.lowercased().contains("logitech") || vendorID == 0x046d { return L10n.text("Logitech（罗技）") }
        if !manufacturer.isEmpty { return manufacturer }
        return L10n.text("未知品牌")
    }
    // USB identity documented at https://github.com/pwr-Solaar/Solaar/blob/master/docs/devices.md
    var isBolt: Bool { vendorID == 0x046d && productID == 0xc548 && transport.lowercased() == "usb" }
    var isReceiver: Bool {
        let name = product.lowercased()
        return isBolt || name.contains("receiver") || name.contains("接收器")
    }
    var isMXAnywhere3S: Bool { !isReceiver && vendorID == 0x046d && product.lowercased() == "mx anywhere 3s" }
    var title: String { isBolt ? "Logi Bolt Receiver" : product.isEmpty ? L10n.text("未上报型号的鼠标") : product }
    var connection: String {
        if transport.lowercased().contains("bluetooth") { return L10n.text("蓝牙") }
        if isBolt { return L10n.text("Logi Bolt 无线接收器") }
        if transport.lowercased() == "usb" {
            return L10n.text(isReceiver ? "USB 无线接收器" : "USB（有线或接收器）")
        }
        return transport.isEmpty ? L10n.text("连接方式未知") : transport
    }
}

/// Passive device discovery only: no device open, input reports, serial numbers, or Bluetooth addresses.
final class MouseDeviceMonitor {
    var onChange: (([MouseDevice]) -> Void)?
    private var manager: IOHIDManager?

    func start() {
        guard manager == nil else { refresh(); return }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(0))
        self.manager = manager
        let context = Unmanaged.passUnretained(self).toOpaque()
        let changed: IOHIDDeviceCallback = { context, _, _, _ in
            guard let context else { return }
            let monitor = Unmanaged<MouseDeviceMonitor>.fromOpaque(context).takeUnretainedValue()
            // Copy the manager's set after it has applied the matching/removal notification.
            DispatchQueue.main.async { [weak monitor] in monitor?.refresh() }
        }
        IOHIDManagerRegisterDeviceMatchingCallback(manager, changed, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, changed, context)
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDDeviceUsagePageKey: 1, kIOHIDDeviceUsageKey: 2] as CFDictionary)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        refresh()
    }

    func refresh() {
        guard let manager else { return }
        let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []).compactMap { device -> MouseDevice? in
            var properties: [String: Any] = [:]
            for key in [kIOHIDProductKey, kIOHIDManufacturerKey, kIOHIDVendorIDKey, kIOHIDProductIDKey, kIOHIDTransportKey,
                        kIOHIDPrimaryUsagePageKey, kIOHIDPrimaryUsageKey, "Built-In"] {
                properties[key] = IOHIDDeviceGetProperty(device, key as CFString)
            }
            var id: UInt64 = 0
            guard IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &id) == KERN_SUCCESS else { return nil }
            return MouseDevice.make(id: id, properties: properties)
        }.sorted { ($0.product, $0.id) < ($1.product, $1.id) }
        onChange?(devices)
    }

    func stop() {
        guard let manager else { return }
        IOHIDManagerRegisterDeviceMatchingCallback(manager, nil, nil)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, nil, nil)
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        self.manager = nil
    }
    deinit { stop() }
}
