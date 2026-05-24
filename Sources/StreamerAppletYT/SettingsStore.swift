// SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
//
// SPDX-License-Identifier: Apache-2.0

//
// Sources/StreamerAppletYT/SettingsStore.swift
// StreamerAppletYT
//
// Version: 0.1.0
// Date: 2026-05-24
//

import Foundation

struct SettingsStore {
    static let urlStorageKey = "url"
    static let defaultURLString = "https://kaito-tokyo.github.io/live-streamer-applet/start.html"

    var urlString: String

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        urlString =
            userDefaults.string(forKey: SettingsStore.urlStorageKey)
            ?? SettingsStore.defaultURLString
        self.userDefaults = userDefaults
    }

    func save() {
        userDefaults.set(urlString, forKey: Self.urlStorageKey)
    }
}
