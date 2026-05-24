// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

//
// Sources/StreamerAppletYT/StreamerAppletYTWebView.swift
// StreamerAppletYT
//
// Version: 0.1.0
// Date: 2026-05-24
//

import SwiftUI
import WebKit

struct StreamerAppletYTWebView: NSViewRepresentable {
    let url: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let webViewConfiguration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: webViewConfiguration)
        context.coordinator.loadedURL = url
        if let url {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedURL != url else {
            return
        }

        context.coordinator.loadedURL = url
        if let url {
            webView.load(URLRequest(url: url))
        }
    }

    final class Coordinator {
        var loadedURL: URL?
    }
}
