// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

//
// Sources/StreamerAppletYT/ContentView.swift
// StreamerAppletYT
//
// Version: 0.1.0
// Date: 2026-05-24
//

import SwiftUI

struct ContentView: View {
    let settingsStore: SettingsStore

    private var resolvedURL: URL? {
        URL(string: settingsStore.urlString)
    }

    var body: some View {
        StreamerAppletYTWebView(url: resolvedURL)
    }
}
