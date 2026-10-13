import Foundation
import CoreGraphics

public struct Shortcut: Codable, Equatable {
    public var keyCode: UInt16
    public var modifiers: UInt64
    public var label: String

    public init(keyCode: UInt16, modifiers: UInt64, label: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.label = label
    }
}

public enum ButtonAction: String, Codable, CaseIterable, Identifiable {
    case native, back, forward, copy, paste, undo, redo, closeTab, newTab, overview, desktop, desktopLeft, desktopRight, custom, disabled
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .native: return "保持原样"
        case .back: return "后退  ⌘["
        case .forward: return "前进  ⌘]"
        case .copy: return "复制  ⌘C"
        case .paste: return "粘贴  ⌘V"
        case .undo: return "撤销  ⌘Z"
        case .redo: return "重做  ⇧⌘Z"
        case .closeTab: return "关闭标签页  ⌘W"
        case .newTab: return "新建标签页  ⌘T"
        case .overview: return "调度中心  ⌃↑"
        case .desktop: return "显示桌面  F11"
        case .desktopLeft: return "切换到左侧桌面  ⌃←"
        case .desktopRight: return "切换到右侧桌面  ⌃→"
        case .custom: return "自定义快捷键…"
        case .disabled: return "停用此键"
        }
    }

    public var shortcut: Shortcut? {
        let command = CGEventFlags.maskCommand.rawValue
        let shift = CGEventFlags.maskShift.rawValue
        switch self {
        case .back: return Shortcut(keyCode: 33, modifiers: command, label: "⌘[")
        case .forward: return Shortcut(keyCode: 30, modifiers: command, label: "⌘]")
        case .copy: return Shortcut(keyCode: 8, modifiers: command, label: "⌘C")
        case .paste: return Shortcut(keyCode: 9, modifiers: command, label: "⌘V")
        case .undo: return Shortcut(keyCode: 6, modifiers: command, label: "⌘Z")
        case .redo: return Shortcut(keyCode: 6, modifiers: command | shift, label: "⇧⌘Z")
        case .closeTab: return Shortcut(keyCode: 13, modifiers: command, label: "⌘W")
        case .newTab: return Shortcut(keyCode: 17, modifiers: command, label: "⌘T")
        case .overview: return Shortcut(keyCode: 126, modifiers: CGEventFlags.maskControl.rawValue, label: "⌃↑")
        case .desktop: return Shortcut(keyCode: 103, modifiers: 0, label: "F11")
        case .desktopLeft: return Shortcut(keyCode: 123, modifiers: CGEventFlags.maskControl.rawValue, label: "⌃←")
        case .desktopRight: return Shortcut(keyCode: 124, modifiers: CGEventFlags.maskControl.rawValue, label: "⌃→")
        default: return nil
        }
    }
}

public struct ButtonBinding: Codable, Equatable {
    public var button: Int64
    public var action: ButtonAction
    public var custom: Shortcut?

    public init(button: Int64, action: ButtonAction, custom: Shortcut? = nil) {
        self.button = button
        self.action = action
        self.custom = custom
    }
    public var resolvedShortcut: Shortcut? { action == .custom ? custom : action.shortcut }
    public var consumesEvent: Bool { action == .disabled || resolvedShortcut != nil }
}

public struct MouseSettings: Codable, Equatable {
    public var enabled = true
    public var reverseVertical = false
    public var reverseHorizontal = false
    public var scroll = ScrollSettings()
    public var rear = ButtonBinding(button: 3, action: .back)
    public var front = ButtonBinding(button: 4, action: .forward)
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case enabled, reverseVertical, reverseHorizontal, scroll, rear, front
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try values.decode(Bool.self, forKey: .enabled)
        reverseVertical = try values.decode(Bool.self, forKey: .reverseVertical)
        reverseHorizontal = try values.decode(Bool.self, forKey: .reverseHorizontal)
        rear = try values.decode(ButtonBinding.self, forKey: .rear)
        front = try values.decode(ButtonBinding.self, forKey: .front)
        scroll = try values.decodeIfPresent(ScrollSettings.self, forKey: .scroll) ?? ScrollSettings()
    }

    public func binding(for button: Int64) -> ButtonBinding? {
        // Left, right and middle click can never be remapped by this app.
        guard button >= 3 else { return nil }
        if rear.button == button { return rear }
        if front.button == button { return front }
        return nil
    }

    public var isValid: Bool {
        let buttons = [rear.button, front.button]
        return scroll.isValid && buttons.allSatisfy { (3...31).contains($0) } && rear.button != front.button
            && [rear, front].allSatisfy { binding in
                guard let custom = binding.custom else { return true }
                let allowed = CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue
                    | CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskControl.rawValue
                return custom.keyCode <= 127 && custom.modifiers & ~allowed == 0
            }
    }
}

/// Software scroll tuning; does not change physical wheel resolution or DPI.
public struct ScrollSettings: Codable, Equatable {
    public var enabled = false
    public var smooth = true
    public var minimumStep: Double = 12
    public var speed: Double = 1
    public var duration: Double = 0.2
    public init() {}
    public var isValid: Bool {
        minimumStep.isFinite && (1...80).contains(minimumStep)
            && speed.isFinite && (0.25...3).contains(speed)
            && duration.isFinite && (0.08...0.6).contains(duration)
    }
}
