import AppKit
import JostleCore

struct ResizeIndicatorSegment: Equatable {
    let start: Point
    let end: Point
}

enum ResizeIndicatorGeometry {
    static func segments(
        for section: ResizeSection,
        in size: Size,
        length: Double = 36,
        inset: Double = 8,
        cornerClearance: Double = 8
    ) -> [ResizeIndicatorSegment] {
        guard section != .none, size.width > 0, size.height > 0 else { return [] }

        let left = min(max(0, inset), size.width / 2)
        let right = max(left, size.width - left)
        let bottom = min(max(0, inset), size.height / 2)
        let top = max(bottom, size.height - bottom)
        let horizontalSpan = max(0, right - left)
        let verticalSpan = max(0, top - bottom)
        let horizontalLength = min(max(0, length), horizontalSpan)
        let verticalLength = min(max(0, length), verticalSpan)
        let horizontalClearance = min(max(0, cornerClearance), horizontalSpan)
        let verticalClearance = min(max(0, cornerClearance), verticalSpan)
        let cornerHorizontalLength = min(horizontalLength, horizontalSpan - horizontalClearance)
        let cornerVerticalLength = min(verticalLength, verticalSpan - verticalClearance)
        var result: [ResizeIndicatorSegment] = []

        switch (section.horizontalEdge, section.verticalEdge) {
        case let (horizontal, vertical) where horizontal != .none && vertical != .none:
            let x = horizontal == .left ? left : right
            let y = vertical == .top ? top : bottom
            let horizontalStartX = horizontal == .left
                ? x + horizontalClearance
                : x - horizontalClearance
            let horizontalEndX = horizontal == .left
                ? horizontalStartX + cornerHorizontalLength
                : horizontalStartX - cornerHorizontalLength
            let verticalStartY = vertical == .top
                ? y - verticalClearance
                : y + verticalClearance
            let verticalEndY = vertical == .top
                ? verticalStartY - cornerVerticalLength
                : verticalStartY + cornerVerticalLength
            result.append(ResizeIndicatorSegment(
                start: Point(x: horizontalStartX, y: y),
                end: Point(x: horizontalEndX, y: y)
            ))
            result.append(ResizeIndicatorSegment(
                start: Point(x: x, y: verticalStartY),
                end: Point(x: x, y: verticalEndY)
            ))

        case let (horizontal, .none) where horizontal != .none:
            let x = horizontal == .left ? left : right
            let centerY = size.height / 2
            result.append(ResizeIndicatorSegment(
                start: Point(x: x, y: centerY - verticalLength / 2),
                end: Point(x: x, y: centerY + verticalLength / 2)
            ))

        case let (.none, vertical) where vertical != .none:
            let y = vertical == .top ? top : bottom
            let centerX = size.width / 2
            result.append(ResizeIndicatorSegment(
                start: Point(x: centerX - horizontalLength / 2, y: y),
                end: Point(x: centerX + horizontalLength / 2, y: y)
            ))

        default:
            break
        }
        return result
    }
}

final class ResizeFeedbackController {
    private var panel: NSPanel?
    private var feedbackView: ResizeFeedbackView?

    func show(frame: Frame, section: ResizeSection) {
        guard section != .none,
              let primaryMaximumY = NSScreen.screens.first?.frame.maxY else {
            hide()
            return
        }
        let cocoaFrame = ScreenGeometryProvider.cocoaFrame(
            from: frame,
            primaryMaximumY: primaryMaximumY
        )
        let panel = panel ?? makePanel(frame: cocoaFrame)
        self.panel = panel
        feedbackView?.section = section
        panel.setFrame(cocoaFrame, display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel(frame: NSRect) -> NSPanel {
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]

        let feedbackView = ResizeFeedbackView(frame: NSRect(origin: .zero, size: frame.size))
        feedbackView.autoresizingMask = [.width, .height]
        panel.contentView = feedbackView
        self.feedbackView = feedbackView
        return panel
    }
}

private final class ResizeFeedbackView: NSView {
    var section = ResizeSection.none {
        didSet { needsDisplay = true }
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let segments = ResizeIndicatorGeometry.segments(
            for: section,
            in: Size(width: bounds.width, height: bounds.height)
        )
        guard !segments.isEmpty else { return }

        let path = NSBezierPath()
        path.lineWidth = 4
        path.lineCapStyle = .round
        for segment in segments {
            path.move(to: NSPoint(x: segment.start.x, y: segment.start.y))
            path.line(to: NSPoint(x: segment.end.x, y: segment.end.y))
        }
        NSColor.controlAccentColor.withAlphaComponent(0.95).setStroke()
        path.stroke()
    }
}
