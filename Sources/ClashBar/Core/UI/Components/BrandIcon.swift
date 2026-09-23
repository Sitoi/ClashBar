import AppKit

@MainActor
enum BrandIcon {
    static let image: NSImage? = loadIcon(named: "BrandLogo", fallbackFileName: "logo.png")
    static let runImage: NSImage? = loadIcon(named: "BrandRun", fallbackFileName: "icon-run.png")
    static let sleepImage: NSImage? = loadIcon(named: "BrandSleep", fallbackFileName: "icon-sleep.png")
    static let tunImage: NSImage? = loadIcon(named: "BrandTun", fallbackFileName: "icon-tun.png")

    private static func loadIcon(named name: String, fallbackFileName: String) -> NSImage? {
        for bundle in AppResourceBundleLocator.candidateBundles() {
            if let image = bundle.image(forResource: NSImage.Name(name)) {
                return image
            }
        }

        if let image = NSImage(named: NSImage.Name(name)) {
            return image
        }

        let candidateRelativePaths = [
            "Assets.xcassets/\(name).imageset/\(fallbackFileName)",
            "Resources/Assets.xcassets/\(name).imageset/\(fallbackFileName)",
            fallbackFileName,
        ]

        for root in AppResourceBundleLocator.candidateResourceRoots() {
            for relativePath in candidateRelativePaths {
                let url = root.appendingPathComponent(relativePath, isDirectory: false)
                if let image = NSImage(contentsOf: url) {
                    return image
                }
            }
        }

        for bundle in AppResourceBundleLocator.candidateBundles() {
            for relativePath in candidateRelativePaths {
                let url = bundle.bundleURL.appendingPathComponent(relativePath, isDirectory: false)
                if let image = NSImage(contentsOf: url) {
                    return image
                }
            }
        }

        return nil
    }
}
