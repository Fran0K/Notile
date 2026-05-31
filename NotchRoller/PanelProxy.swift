import AppKit

@MainActor
@Observable
final class PanelProxy {
    var popupFrame: NSRect = .zero {
        didSet { panel?.popupFrame = popupFrame }
    }
    weak var panel: NotchPanel?

    /// Resize and reposition the panel to match popupFrame (with drag buffer).
    func applyFrame() {
        guard let panel else { return }
        var frame = popupFrame
        let buffer: CGFloat = 100
        frame.origin.y -= buffer  // keep top edge fixed, extend downward
        frame.size.height += buffer
        panel.setFrame(frame, display: true)
    }

    /// Shrink panel to zero size at the top-center of the screen (collapsed state).
    func collapsePanel() {
        guard let panel, let screen = NSScreen.screens.first else { return }
        let sf = screen.frame
        let zeroFrame = NSRect(x: sf.midX, y: sf.maxY, width: 0, height: 0)
        panel.setFrame(zeroFrame, display: true)
    }
}
