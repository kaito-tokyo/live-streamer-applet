// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

//
// Sources/StreamerAppletYT/StreamerAppletYTApp.swift
// StreamerAppletYT
//
// Version: 0.1.0
// Date: 2026-05-24
//

import SwiftUI

@main
struct LiveStreamerAppletYTApp: App {
    @State private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup("Live Streamer Applet YT") {
            ContentView(settingsStore: settingsStore)
        }
        .defaultSize(width: 960, height: 540)

        Settings {
            SettingsView(settingsStore: $settingsStore)
        }
    }
}
