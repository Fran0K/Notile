//
//  NotchPanel.swift
//  notchEye
//
//  Created by Frank Lin on 2026/5/6.
//

import SwiftUI

/// NSPanel 一种窗口类型是辅助窗口/浮动窗口/工具窗口

final class NotchPanel: NSPanel {

    /// Screen-space rect of the popup for hit-testing.
    var popupFrame: NSRect = .zero

    /// When false (default), all mouse events pass through.
    var isInteractive: Bool = false
    
    /// init panel
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            //.nonactivatingPanel保持原窗口的焦点
            // .borderless去掉边框
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

/// Custom content view that only accepts events when panel is interactive.
/// Panel is popup-sized, so all events within its bounds are valid.
class PopupHitView: NSView {
    weak var panel: NotchPanel?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let panel, panel.isInteractive else { return nil }
        return super.hitTest(point)
    }
}
