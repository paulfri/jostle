import AppKit
import JostleCore

enum StatusIconRenderer {
    static let canvasSize = NSSize(width: 16, height: 16)
    static let frameLineWidth: CGFloat = 1.5
    static let frameCenterlineBounds = NSRect(x: 0.75, y: 0.75, width: 14.5, height: 14.5)
    static let centerSymbolSize = NSSize(width: 12, height: 12)
    static let centerSymbolPointSize: CGFloat = 11

    static func centerSymbolFrame(in imageRect: NSRect) -> NSRect {
        NSRect(
            x: imageRect.midX - centerSymbolSize.width / 2,
            y: imageRect.midY - centerSymbolSize.height / 2,
            width: centerSymbolSize.width,
            height: centerSymbolSize.height
        )
    }

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
                "cup.and.heat.waves"
            case .normal, .badgeGreen, .badgeBlue:
                nil
            }
        }

        let image = renderTemplate(embeddedSymbolName: embeddedSymbolName)
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
                ("cup.and.heat.waves", .labelColor)
            case .badgeGreen:
                ("cup.and.heat.waves", .systemGreen)
            case .badgeBlue:
                ("cup.and.heat.waves", .systemBlue)
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

    private static func renderTemplate(embeddedSymbolName: String?) -> NSImage {
        let image = NSImage(size: canvasSize, flipped: false) { _ in
            drawFrame()

            if let embeddedSymbolName,
               let symbol = NSImage(
                   systemSymbolName: embeddedSymbolName,
                   accessibilityDescription: nil
               )?.withSymbolConfiguration(
                   NSImage.SymbolConfiguration(
                       pointSize: centerSymbolPointSize,
                       weight: .semibold
                   )
               ) {
                symbol.draw(
                    in: NSRect(x: 2, y: 2, width: 12, height: 12),
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

    private static func drawFrame() {
        let bounds = frameCenterlineBounds
        let cornerLength: CGFloat = 3.5
        let path = NSBezierPath()

        path.move(to: NSPoint(x: bounds.minX, y: bounds.minY + cornerLength))
        path.line(to: NSPoint(x: bounds.minX, y: bounds.minY))
        path.line(to: NSPoint(x: bounds.minX + cornerLength, y: bounds.minY))

        path.move(to: NSPoint(x: bounds.maxX - cornerLength, y: bounds.minY))
        path.line(to: NSPoint(x: bounds.maxX, y: bounds.minY))
        path.line(to: NSPoint(x: bounds.maxX, y: bounds.minY + cornerLength))

        path.move(to: NSPoint(x: bounds.maxX, y: bounds.maxY - cornerLength))
        path.line(to: NSPoint(x: bounds.maxX, y: bounds.maxY))
        path.line(to: NSPoint(x: bounds.maxX - cornerLength, y: bounds.maxY))

        path.move(to: NSPoint(x: bounds.minX + cornerLength, y: bounds.maxY))
        path.line(to: NSPoint(x: bounds.minX, y: bounds.maxY))
        path.line(to: NSPoint(x: bounds.minX, y: bounds.maxY - cornerLength))

        path.lineWidth = frameLineWidth
        path.lineCapStyle = .square
        path.lineJoinStyle = .miter
        NSColor.black.setStroke()
        path.stroke()
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
