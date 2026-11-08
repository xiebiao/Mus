import SwiftUI

enum SettingsPalette {
    static let primary = adaptive(0x5753A4, 0xC5C0FF)
    static let onPrimary = adaptive(0xFFFFFF, 0x29236D)
    static let primaryContainer = adaptive(0xE5DFFF, 0x413B87)
    static let onPrimaryContainer = adaptive(0x28225F, 0xE5DFFF)
    static let secondaryContainer = adaptive(0xE5E3F2, 0x474458)
    static let surface = adaptive(0xFBF9FD, 0x141318)
    static let surfaceLow = adaptive(0xF4F2F8, 0x1D1B22)
    static let surfaceContainer = adaptive(0xEDEAF3, 0x26242D)
    static let onSurface = adaptive(0x1D1B24, 0xE6E1EC)
    static let onSurfaceVariant = adaptive(0x4A4758, 0xCBC5D6)
    static let outlineVariant = adaptive(0xCAC5D4, 0x494553)

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
                           green: CGFloat((rgb >> 8) & 255) / 255,
                           blue: CGFloat(rgb & 255) / 255, alpha: 1)
        })
    }
}

enum MaterialSymbol: String, CaseIterable {
    case tune, mouse, undo, redo, info, close
    case permissions = "verified_user"
    case connected = "check_circle"
    case hand = "pan_tool"

    private static let images: [Self: NSImage] = Dictionary(uniqueKeysWithValues: allCases.compactMap { symbol in
        guard let url = AppResources.bundle.url(forResource: "material-" + symbol.rawValue, withExtension: "svg"),
              let image = NSImage(contentsOf: url) else { return nil }
        return (symbol, image)
    })

    func icon(_ size: CGFloat) -> some View {
        Image(nsImage: Self.images[self] ?? NSImage(systemSymbolName: "questionmark", accessibilityDescription: nil)!)
            .renderingMode(.template).resizable().scaledToFit()
            .frame(width: size, height: size).accessibilityHidden(true)
    }

    func label(_ title: String, size: CGFloat = 18) -> some View {
        Label { Text(title) } icon: { icon(size) }
    }
}
