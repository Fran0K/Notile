//
//  notchEyeApp.swift
//  notchEye
//
//  Created by Frank Lin on 2026/5/6.
//

import SwiftUI


//这里才算是程序入口
@main
struct NotchRollerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .system

    var body: some Scene {
        MenuBarExtra("NotchRoller", image: "MenuIcon") {
            SettingsLink {
                Text("menuBar.settings")
            }
            Divider()
            Button("menuBar.quit") {
                NSApp.terminate(nil)
            }
        }
        .environment(\.locale, appLanguage.locale)

        Settings {
            SettingsView()
                .environment(\.locale, appLanguage.locale)
        }
    }
}
