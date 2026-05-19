import AppKit

@MainActor
@Observable
final class PanelProxy {
    var popupFrame: NSRect = .zero {
        didSet { panel?.popupFrame = popupFrame }
    }
    weak var panel: NotchPanel?
}
