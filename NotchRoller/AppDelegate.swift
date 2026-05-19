//
//  AppDelegate.swift
//  notchEye
//
//  Created by Frank Lin on 2026/5/6.
//

import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    static weak var shared: AppDelegate?

    let timerManager = TimerManager()
    let panelProxy = PanelProxy()
    var panel: NotchPanel?

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let screen = NSScreen.screens.first?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let panelSize = NSSize(width: screen.width, height: screen.height)
        let panel = NotchPanel(contentRect: NSRect(origin: .zero, size: panelSize))
        let containerView = PopupHitView(frame: NSRect(origin: .zero, size: panelSize))
        containerView.panel = panel
        let hostingView = NSHostingView(rootView: NotchView(timerManager: timerManager, panelProxy: panelProxy))
        hostingView.frame = containerView.bounds
        hostingView.autoresizingMask = [.width, .height]
        containerView.addSubview(hostingView)
        panel.contentView = containerView

        // Keep panel invisible on launch — no hijacking
        panel.alphaValue = 0
        self.panel = panel
        panelProxy.panel = panel

        positionPanel()
        panel.orderFrontRegardless()

        timerManager.start()

        // Expand: show panel and enable interaction
        NotificationCenter.default.addObserver(
            forName: .notchRollerDidExpand,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let panel = self?.panel else { return }
                panel.isInteractive = true
                panel.ignoresMouseEvents = false
                panel.alphaValue = 1
            }
        }
        // Collapse: disable interaction, fade out after animation
        NotificationCenter.default.addObserver(
            forName: .notchRollerDidCollapse,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let panel = self?.panel else { return }
                panel.isInteractive = false
                panel.ignoresMouseEvents = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    panel.alphaValue = 0
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.positionPanel()
            }
        }
    }

    func positionPanel() {
        guard let screen = NSScreen.screens.first else { return }
        let panelSize = NSSize(width: screen.frame.width, height: screen.frame.height)
        let x = screen.frame.midX - panelSize.width / 2
        let y = screen.frame.maxY - panelSize.height
        panel?.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: panelSize), display: true)
    }
}

