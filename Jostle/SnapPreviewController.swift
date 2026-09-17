import AppKit
import JostleCore

final class SnapPreviewController {
    private var panel: NSPanel?

    func show(frame: Frame) {
        guard let primaryMaximumY = NSScreen.screens.first?.frame.maxY else { return }
        let cocoaFrame = ScreenGeometryProvider.cocoaFrame(
            from: frame,
            primaryMaximumY: primaryMaximumY
        )
        let panel = panel ?? makePanel(frame: cocoaFrame)
        self.panel = panel
        updateAppearance(of: panel)
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

        let contentView = NSView(frame: NSRect(origin: .zero, size: frame.size))
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 10
        contentView.layer?.borderWidth = 2
        panel.contentView = contentView
        return panel
    }

    private func updateAppearance(of panel: NSPanel) {
        panel.contentView?.layer?.backgroundColor = NSColor.controlAccentColor
            .withAlphaComponent(0.18)
            .cgColor
        panel.contentView?.layer?.borderColor = NSColor.controlAccentColor
            .withAlphaComponent(0.75)
            .cgColor
    }
}
