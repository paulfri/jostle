import AppKit

/// Build-profile branding and naming that intentionally keeps local Debug builds
/// distinct from publicly distributed Release builds.
enum AppBrand {
    static let applicationName: String = {
        let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        return value.flatMap { $0.isEmpty ? nil : $0 } ?? "Jostle"
    }()

    static let accentColor: NSColor = {
#if JOSTLE_DEVELOPMENT
        // HSV hue complement of Jostle gold (#F5B75D), preserving saturation/value.
        return NSColor(
            srgbRed: 93.0 / 255.0,
            green: 155.0 / 255.0,
            blue: 245.0 / 255.0,
            alpha: 1
        )
#else
        return NSColor(
            srgbRed: 245.0 / 255.0,
            green: 183.0 / 255.0,
            blue: 93.0 / 255.0,
            alpha: 1
        )
#endif
    }()
}
