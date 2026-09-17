import AppKit
import JostleCore

struct ScreenGeometry: Equatable {
    let frame: Frame
    let visibleFrame: Frame
}

struct ScreenGeometryProvider {
    func geometry(containing point: Point) -> ScreenGeometry? {
        guard let primaryMaximumY = NSScreen.screens.first?.frame.maxY else { return nil }
        return NSScreen.screens.lazy
            .map { screen in
                ScreenGeometry(
                    frame: Self.accessibilityFrame(
                        from: screen.frame,
                        primaryMaximumY: primaryMaximumY
                    ),
                    visibleFrame: Self.accessibilityFrame(
                        from: screen.visibleFrame,
                        primaryMaximumY: primaryMaximumY
                    )
                )
            }
            .first { geometry in
                point.x >= geometry.frame.origin.x
                    && point.x <= geometry.frame.origin.x + geometry.frame.size.width
                    && point.y >= geometry.frame.origin.y
                    && point.y <= geometry.frame.origin.y + geometry.frame.size.height
            }
    }

    static func accessibilityFrame(from cocoaFrame: NSRect, primaryMaximumY: Double) -> Frame {
        Frame(
            x: cocoaFrame.minX,
            y: primaryMaximumY - cocoaFrame.maxY,
            width: cocoaFrame.width,
            height: cocoaFrame.height
        )
    }

    static func cocoaFrame(from frame: Frame, primaryMaximumY: Double) -> NSRect {
        NSRect(
            x: frame.origin.x,
            y: primaryMaximumY - frame.origin.y - frame.size.height,
            width: frame.size.width,
            height: frame.size.height
        )
    }
}
