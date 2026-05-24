// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

//
// Sources/StreamerAppletYT/SettingsView.swift
// StreamerAppletYT
//
// Version: 0.1.0
// Date: 2026-05-24
//

import SwiftUI

struct SettingsView: View {
    @Binding var settingsStore: SettingsStore

    @State private var draftURL = SettingsStore.defaultURLString

    var body: some View {
        Form {
            TextField("URL", text: $draftURL)
        }
        .scenePadding()
        .frame(width: 320)
        .onAppear {
            draftURL = settingsStore.urlString
        }
        .onDisappear(perform: save)
    }

    private func save() {
        guard draftURL != settingsStore.urlString else {
            return
        }

        settingsStore.urlString = draftURL
        settingsStore.save()
    }
}
