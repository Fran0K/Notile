//
//  notchEyeApp.swift
//  notchEye
//
//  Created by Frank Lin on 2026/5/6.
//

import SwiftUI

@main
struct NotchRollerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("NotchRoller", image: "MenuIcon") {
            SettingsLink {
                Text("设置")
            }
            Divider()
            Button("退出 NotchRoller") {
                NSApp.terminate(nil)
            }
        }

        Settings {
            SettingsView()
        }
    }
}
