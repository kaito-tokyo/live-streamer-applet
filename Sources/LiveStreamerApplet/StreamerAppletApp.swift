// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

//
// Sources/StreamerApplet/StreamerAppletApp.swift
// StreamerApplet
//
// Version: 0.1.0
// Date: 2026-05-24
//

import SwiftUI

@main
struct LiveStreamerAppletApp: App {
    @State private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup("Live Streamer Applet") {
            ContentView(settingsStore: settingsStore)
        }
        .defaultSize(width: 960, height: 540)

        Settings {
            SettingsView(settingsStore: $settingsStore)
        }
    }
}
