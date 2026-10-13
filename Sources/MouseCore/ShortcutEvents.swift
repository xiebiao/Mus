import CoreGraphics

/// Creates a complete key press without posting events to the desktop.
public enum ShortcutEvents {
    public static func make(for shortcut: Shortcut) -> [CGEvent]? {
        let source = CGEventSource(stateID: .privateState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: false) else { return nil }
        for event in [down, up] {
            // CGEvent adds keypad/Fn identity flags for arrows and function keys.
            // Replacing all flags with the shortcut modifiers strips that identity,
            // so system shortcuts such as Control-arrow may not be recognized.
            let keyIdentity = event.flags.intersection([.maskNumericPad, .maskSecondaryFn])
            event.flags = keyIdentity.union(CGEventFlags(rawValue: shortcut.modifiers))
            event.setIntegerValueField(.eventSourceUserData, value: EventProcessor.ownEventMarker)
        }
        return [down, up]
    }
}
