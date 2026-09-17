import AppKit

struct ApplicationIconProvider {
    private static let cache = NSCache<NSString, NSImage>()
    private static let displaySize = NSSize(width: 32, height: 32)

    static func icon(applicationKey: String, displayName: String) -> NSImage? {
        let cacheKey = applicationKey as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        let workspace = NSWorkspace.shared
        let applicationURL = workspace.urlForApplication(withBundleIdentifier: applicationKey)
            ?? workspace.runningApplications.first(where: {
                $0.bundleIdentifier == applicationKey || $0.localizedName == displayName
            })?.bundleURL
        guard let applicationURL,
              let icon = workspace.icon(forFile: applicationURL.path).copy() as? NSImage else {
            return nil
        }

        // Preserve the icon's Retina representations while assigning its logical display size.
        icon.size = displaySize
        icon.isTemplate = false
        cache.setObject(icon, forKey: cacheKey)
        return icon
    }
}
