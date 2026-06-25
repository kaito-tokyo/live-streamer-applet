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

import AppKit
import SwiftUI

struct SettingsView: View {
    @Binding var settingsStore: SettingsStore

    @State private var draftConfigurationText = SettingsStore.defaultConfigurationText

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Applet Configuration")
                .font(.headline)

            PlainConfigurationTextView(text: $draftConfigurationText)
                .frame(minWidth: 520, minHeight: 320)
        }
        .scenePadding()
        .onAppear {
            draftConfigurationText = settingsStore.configurationText
        }
        .onDisappear(perform: save)
    }

    private func save() {
        guard draftConfigurationText != settingsStore.configurationText else {
            return
        }

        settingsStore.configurationText = draftConfigurationText
        settingsStore.save()
    }
}

private struct PlainConfigurationTextView: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = false

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView, textView.string != text else {
            return
        }

        textView.string = text
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        weak var textView: NSTextView?

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            text = textView.string
        }
    }
}
