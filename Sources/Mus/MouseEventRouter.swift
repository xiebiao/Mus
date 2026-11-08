import CoreGraphics
import IOKit
import MouseCore

/// The sender in a Quartz mouse event can be the HID event service below
/// the IOHIDDevice returned by discovery. Never route via the UI selection.
final class MouseEventRouter {
    private var processors: [UInt64: EventProcessor] = [:]
    private var senders: [UInt64: UInt64] = [:]
    private var unknown: Set<UInt64> = []

    func configure(_ devices: [UInt64: MouseSettings]) {
        if Set(devices.keys) != Set(processors.keys) {
            senders.removeAll()
            unknown.removeAll()
        }
        processors = processors.filter { devices[$0.key] != nil }
        for (id, settings) in devices {
            if let processor = processors[id] { processor.settings = settings }
            else { processors[id] = EventProcessor(settings: settings) }
        }
    }

    func reset() {
        for processor in processors.values { processor.reset() }
        senders.removeAll()
        unknown.removeAll()
    }

    func source(of event: CGEvent) -> (id: UInt64, processor: EventProcessor)? {
        // Quartz field 87 is the HID sender's IORegistry ID (undocumented).
        // A zero, synthetic, or unrecognized sender keeps its native behavior.
        let sender = UInt64(bitPattern: event.getIntegerValueField(CGEventField(rawValue: 87)!))
        guard sender != 0 else { return nil }
        if let processor = processors[sender] { return (sender, processor) }
        if let id = senders[sender], let processor = processors[id] { return (id, processor) }
        guard !unknown.contains(sender) else { return nil }

        var entry = IOServiceGetMatchingService(kIOMainPortDefault, IORegistryEntryIDMatching(sender))
        while entry != 0 {
            var id: UInt64 = 0
            IORegistryEntryGetRegistryEntryID(entry, &id)
            if let processor = processors[id] {
                IOObjectRelease(entry)
                senders[sender] = id
                return (id, processor)
            }
            var parent: io_registry_entry_t = 0
            IORegistryEntryGetParentEntry(entry, kIOServicePlane, &parent)
            IOObjectRelease(entry)
            entry = parent
        }
        unknown.insert(sender)
        return nil
    }
}
