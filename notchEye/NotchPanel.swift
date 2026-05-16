//
//  NotchPanel.swift
//  notchEye
//
//  Created by Frank Lin on 2026/5/6.
//

import SwiftUI

final class NotchPanel: NSPanel {

    /// Screen-space rect of the popup for hit-testing.
    var popupFrame: NSRect = .zero

    /// When false (default), all mouse events pass through.
    var isInteractive: Bool = false

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        hasShadow = false
        backgroundColor = .clear
        isOpaque = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
    }
}

/// Custom content view that only accepts events within the popup frame.
class PopupHitView: NSView {
    weak var panel: NotchPanel?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let panel, panel.isInteractive, panel.popupFrame.contains(point) else { return nil }
        return super.hitTest(point)
    }
}
