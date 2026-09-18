import AppKit
import JostleCore

enum StatusIconRenderer {
    enum CenterState: Equatable {
        case none
        case awake
        case paused
        case attention
    }

    struct Presentation {
        let image: NSImage
        let iconTintColor: NSColor?
        let overlaySymbolName: String?
        let overlayTintColor: NSColor?
        let shouldDim: Bool
    }

    static func presentation(
        baseImage: NSImage,
        applicationName: String,
        windowGesturesAvailable: Bool,
        centerState: CenterState,
        dimWhenInactive: Bool,
        indicatorStyle: KeepAwakeIndicatorStyle
    ) -> Presentation {
        let embeddedSymbolName: String? = switch centerState {
        case .none, .attention:
            nil
        case .paused:
            "moon.zzz.fill"
        case .awake:
            switch indicatorStyle {
            case .coloredGreen, .coloredBlue:
                "cup.and.heat.waves.fill"
            case .normal, .badgeGreen, .badgeBlue:
                nil
            }
        }

        let image = renderTemplate(
            baseImage: baseImage,
            embeddedSymbolName: embeddedSymbolName
        )
        image.accessibilityDescription = accessibilityDescription(
            applicationName: applicationName,
            centerState: centerState
        )

        let iconTintColor: NSColor? = switch (centerState, indicatorStyle) {
        case (.awake, .coloredGreen): .systemGreen
        case (.awake, .coloredBlue): .systemBlue
        default: nil
        }

        let overlay: (String, NSColor)? = switch centerState {
        case .none, .paused:
            nil
        case .attention:
            ("exclamationmark", AppBrand.accentColor)
        case .awake:
            switch indicatorStyle {
            case .normal:
                ("cup.and.heat.waves.fill", AppBrand.accentColor)
            case .badgeGreen:
                ("cup.and.heat.waves.fill", .systemGreen)
            case .badgeBlue:
                ("cup.and.heat.waves.fill", .systemBlue)
            case .coloredGreen, .coloredBlue:
                nil
            }
        }

        let keepAwakeVisible = centerState == .awake || centerState == .paused
        return Presentation(
            image: image,
            iconTintColor: iconTintColor,
            overlaySymbolName: overlay?.0,
            overlayTintColor: overlay?.1,
            shouldDim: !keepAwakeVisible && (!windowGesturesAvailable || dimWhenInactive)
        )
    }

    private static func renderTemplate(
        baseImage: NSImage,
        embeddedSymbolName: String?
    ) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            baseImage.draw(
                in: NSRect(x: 1, y: 1, width: 16, height: 16),
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.high]
            )

            if let embeddedSymbolName,
               let symbol = NSImage(
                   systemSymbolName: embeddedSymbolName,
                   accessibilityDescription: nil
               )?.withSymbolConfiguration(
                   NSImage.SymbolConfiguration(pointSize: 7.5, weight: .semibold)
               ) {
                symbol.draw(
                    in: NSRect(x: 5, y: 5, width: 8, height: 8),
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1,
                    respectFlipped: true,
                    hints: [.interpolation: NSImageInterpolation.high]
                )
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func accessibilityDescription(
        applicationName: String,
        centerState: CenterState
    ) -> String {
        switch centerState {
        case .none:
            applicationName
        case .awake:
            "\(applicationName), keeping Mac awake"
        case .paused:
            "\(applicationName), Keep Awake paused while locked"
        case .attention:
            "\(applicationName), Keep Awake needs attention"
        }
    }
}
