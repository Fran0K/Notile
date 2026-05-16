//
//  notchEyeApp.swift
//  notchEye
//
//  Created by Frank Lin on 2026/5/6.
//

import SwiftUI

@main
struct notechApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("notech", image: "MenuIcon") {
            Button("立即测试") {
                NotificationCenter.default.post(name: .notechTriggerNow, object: nil)
            }
            SettingsLink {
                Text("设置...")
            }
            Divider()
            Button("退出 notech") {
                NSApp.terminate(nil)
            }
        }

        Settings {
            SettingsView()
        }
    }
}
