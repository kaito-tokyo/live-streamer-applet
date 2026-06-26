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

    @State private var draftConfigurationText = SettingsStore.defaultConfigurationText

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preset Configuration")
                .font(.headline)

            TextEditor(text: $draftConfigurationText)
                .font(.system(.body, design: .monospaced))
                .textEditorStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
                .frame(minWidth: 520, minHeight: 320)
        }
        .scenePadding()
        .onAppear {
            draftConfigurationText = settingsStore.configurationText
        }
        .onChange(of: draftConfigurationText) {
            save()
        }
    }

    private func save() {
        guard draftConfigurationText != settingsStore.configurationText else {
            return
        }

        settingsStore.configurationText = draftConfigurationText
        settingsStore.save()
    }
}
