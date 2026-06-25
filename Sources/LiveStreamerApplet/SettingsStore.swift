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
    static let configurationTextStorageKey = "configurationText"
    static let defaultConfigurationText = """
    start.name = Start Page
    start.type = web
    start.url = https://kaito-tokyo.github.io/live-streamer-applet/start.html

    shell.name = Shell
    shell.type = terminal
    shell.command = ["/bin/echo", "Console", "ready"]
    """

    var configurationText: String

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        configurationText =
            userDefaults.string(forKey: SettingsStore.configurationTextStorageKey)
            ?? SettingsStore.defaultConfigurationText
        self.userDefaults = userDefaults
    }

    func save() {
        userDefaults.set(configurationText, forKey: Self.configurationTextStorageKey)
    }
}
