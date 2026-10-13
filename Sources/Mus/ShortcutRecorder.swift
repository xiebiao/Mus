import AppKit
import SwiftUI
import MouseCore

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: Shortcut?

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.onRecord = { shortcut = $0 }
        return button
    }

    func updateNSView(_ button: RecorderButton, context: Context) {
        button.savedTitle = shortcut?.label ?? L10n.text("录制快捷键")
        button.onRecord = { shortcut = $0 }
        if !button.recording { button.title = button.savedTitle }
    }
}

final class RecorderButton: NSButton {
    var savedTitle = L10n.text("录制快捷键")
    var recording = false
    var onRecord: ((Shortcut) -> Void)?
    override var acceptsFirstResponder: Bool { true }

    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        title = savedTitle
        target = self
        action = #selector(beginRecording)
        setAccessibilityLabel(L10n.text("录制自定义快捷键，按 Escape 取消"))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func beginRecording() {
        recording = true
        title = L10n.text("按下组合键 · Esc 取消")
        window?.makeFirstResponder(self)
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        title = savedTitle
        return super.resignFirstResponder()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording, window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
        record(event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        if recording { record(event) } else { super.keyDown(with: event) }
    }

    private func record(_ event: NSEvent) {
        if event.keyCode == 53 {
            recording = false
            title = savedTitle
            return
        }
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let named: [UInt16: String] = [36: "↩", 48: "⇥", 49: L10n.text("空格"), 51: "⌫", 117: "⌦",
            123: "←", 124: "→", 125: "↓", 126: "↑", 122: "F1", 120: "F2", 99: "F3", 118: "F4",
            96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"]
        let functionKeys: Set<UInt16> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]
        guard !flags.intersection([.command, .control, .option]).isEmpty || functionKeys.contains(event.keyCode) else {
            title = L10n.text("请包含 ⌘ / ⌃ / ⌥，或使用 F1–F12")
            return
        }
        let key = named[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? L10n.format("键 %d", Int(event.keyCode))
        var label = ""
        var cgFlags: CGEventFlags = []
        if flags.contains(.control) { label += "⌃"; cgFlags.insert(.maskControl) }
        if flags.contains(.option) { label += "⌥"; cgFlags.insert(.maskAlternate) }
        if flags.contains(.shift) { label += "⇧"; cgFlags.insert(.maskShift) }
        if flags.contains(.command) { label += "⌘"; cgFlags.insert(.maskCommand) }
        label += key
        savedTitle = label
        title = label
        recording = false
        onRecord?(Shortcut(keyCode: event.keyCode, modifiers: cgFlags.rawValue, label: label))
    }
}
