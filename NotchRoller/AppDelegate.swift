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
    //创建核心对象
    let timerManager = TimerManager()
    let panelProxy = PanelProxy()
    var panel: NotchPanel?

    override init() {
        super.init()
        Self.shared = self
    }
    
    //相当于main函数
    func applicationDidFinishLaunching(_ notification: Notification) {
        //不现实application图标
        NSApp.setActivationPolicy(.accessory)

        let screen = ScreenResolver.resolveTargetScreen()?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
//        let targetScreen = NSScreen.main ?? NSScreen.screens.first
        // 创建一个 0×0 的窗口
        let zeroFrame = NSRect(x: screen.midX, y: screen.maxY, width: 0, height: 0)
        // 创建 NotchPanel
        let panel = NotchPanel(contentRect: zeroFrame)
        let containerView = PopupHitView(frame: zeroFrame)
        containerView.panel = panel
        let hostingView = NSHostingView(rootView: NotchViewLocaleWrapper(timerManager: timerManager, panelProxy: panelProxy))
        hostingView.frame = containerView.bounds
        hostingView.autoresizingMask = [.width, .height]
        containerView.addSubview(hostingView)
        panel.contentView = containerView

        // Keep panel invisible on launch — no hijacking
        panel.alphaValue = 0
        self.panel = panel
        panelProxy.panel = panel

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
                guard let self, let panel = self.panel else { return }
                panel.isInteractive = false
                panel.ignoresMouseEvents = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    panel.alphaValue = 0
                    self.panelProxy.collapsePanel()
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.panelProxy.applyFrame()
                if !self.timerManager.isExpanded {
                    self.panelProxy.collapsePanel()
                }
            }
        }
    }
}

// MARK: - Locale-aware wrapper for NSHostingView

struct NotchViewLocaleWrapper: View {
    let timerManager: TimerManager
    let panelProxy: PanelProxy
    @AppStorage("appLanguage") var appLanguage: AppLanguage = .system

    var body: some View {
        NotchView(timerManager: timerManager, panelProxy: panelProxy)
            .environment(\.locale, appLanguage.locale)
    }
}

