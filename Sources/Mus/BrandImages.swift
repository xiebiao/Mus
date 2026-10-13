import AppKit

/// Use the user-selected mouse silhouette consistently across app surfaces.
enum BrandImages {
    static let logo: NSImage = {
        guard let url = AppResources.bundle.url(forResource: "MusLogo", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return NSImage(size: NSSize(width: 32, height: 32))
        }
        image.isTemplate = true
        image.accessibilityDescription = "Mus"
        return image
    }()

    static let menuBar: NSImage = {
        let image = logo.copy() as! NSImage
        image.size = NSSize(width: 22, height: 22)
        image.isTemplate = true
        return image
    }()
}
