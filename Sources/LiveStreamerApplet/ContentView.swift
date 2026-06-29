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

import AppKit
import Darwin
import Foundation
import SwiftUI

private struct PresetConfiguration {
    let presets: [AppletPreset]

    static func parse(_ configurationText: String) throws -> PresetConfiguration {
        var presets: [AppletPreset] = []
        var presetIDs = Set<String>()
        var currentPresetID: String?
        var currentPresetLines: [String] = []
        var foundSection = false

        func finishCurrentPreset() throws {
            guard let currentPresetID else {
                return
            }

            let configurationText = currentPresetLines.joined(separator: "\n")
            guard !configurationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw PresetValidationError.emptyPreset(currentPresetID)
            }

            presets.append(AppletPreset(id: currentPresetID, configurationText: configurationText))
        }

        for (lineIndex, rawLine) in configurationText.split(
            separator: "\n", omittingEmptySubsequences: false
        ).enumerated() {
            let rawLineString = String(rawLine)
            let line = rawLineString.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("[") {
                guard line.hasSuffix("]") else {
                    throw PresetValidationError.invalidSection(lineIndex + 1)
                }

                try finishCurrentPreset()
                currentPresetID = nil
                currentPresetLines = []
                foundSection = true

                if line.hasPrefix("[[") && line.hasSuffix("]]") {
                    continue
                }

                let sectionID = String(line.dropFirst().dropLast()).trimmingCharacters(
                    in: .whitespaces)
                guard !sectionID.isEmpty, !sectionID.contains("[") && !sectionID.contains("]")
                else {
                    throw PresetValidationError.invalidSection(lineIndex + 1)
                }
                guard !presetIDs.contains(sectionID) else {
                    throw PresetValidationError.duplicatePreset(sectionID)
                }

                presetIDs.insert(sectionID)
                currentPresetID = sectionID
                continue
            }

            if foundSection {
                currentPresetLines.append(rawLineString)
            }
        }

        try finishCurrentPreset()

        if !foundSection {
            let trimmedConfigurationText = configurationText.trimmingCharacters(
                in: .whitespacesAndNewlines)
            guard !trimmedConfigurationText.isEmpty else {
                throw PresetValidationError.emptyPresets
            }
            return PresetConfiguration(presets: [
                AppletPreset(id: "default", configurationText: configurationText)
            ])
        }

        guard !presets.isEmpty else {
            throw PresetValidationError.emptyPresets
        }

        return PresetConfiguration(presets: presets)
    }
}

private struct AppletPreset: Identifiable {
    let id: String
    let configurationText: String

    var displayName: String {
        id
            .split(whereSeparator: { $0 == "-" || $0 == "_" || $0 == "." })
            .map { word in
                guard let firstCharacter = word.first else {
                    return ""
                }
                return firstCharacter.uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }
}

private struct AppletConfiguration {
    let applets: [AppletSpec]

    static func parse(_ configurationText: String) throws -> AppletConfiguration {
        var records: [String: [String: String]] = [:]
        var orderedIDs: [String] = []
        var orderedIDSet: Set<String> = []

        for (lineIndex, rawLine) in configurationText.split(
            separator: "\n", omittingEmptySubsequences: false
        ).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            guard !line.isEmpty, !line.hasPrefix("#"), !line.hasPrefix(";") else {
                continue
            }

            guard let separatorIndex = line.firstIndex(of: "=") else {
                throw ValidationError.invalidLine(lineIndex + 1)
            }

            let left = line[..<separatorIndex].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: separatorIndex)...].trimmingCharacters(
                in: .whitespaces)
            let keyPath = left.split(separator: ".", omittingEmptySubsequences: false)

            guard keyPath.count == 2, !keyPath[0].isEmpty, !keyPath[1].isEmpty else {
                throw ValidationError.invalidKey(String(left), lineIndex + 1)
            }

            let id = String(keyPath[0])
            let key = String(keyPath[1]).lowercased()

            records[id, default: [:]][key] = String(value)

            if key == "name", !orderedIDSet.contains(id) {
                orderedIDs.append(id)
                orderedIDSet.insert(id)
            }
        }

        guard !orderedIDs.isEmpty else {
            throw ValidationError.emptyApplets
        }

        let applets = try orderedIDs.map { id in
            let fields = records[id, default: [:]]
            guard let name = fields["name"], !name.isEmpty else {
                throw ValidationError.missingName(id)
            }
            guard let typeString = fields["type"], !typeString.isEmpty else {
                throw ValidationError.missingType(id)
            }
            guard let type = AppletType(rawValue: typeString.lowercased()) else {
                throw ValidationError.unknownType(typeString, id)
            }

            switch type {
            case .web:
                guard
                    let urlString = fields["url"],
                    !urlString.isEmpty,
                    let url = URL(string: urlString)
                else {
                    throw ValidationError.missingWebURL(id)
                }

                return AppletSpec(
                    id: id, name: name, type: type, url: url, command: [], currentDirectory: nil)
            case .terminal:
                let command = try parseCommand(
                    fields["command"] ?? "[\"/usr/bin/true\"]", appletID: id)
                return AppletSpec(
                    id: id,
                    name: name,
                    type: type,
                    url: nil,
                    command: command,
                    currentDirectory: fields["currentdirectory"] ?? fields["cwd"]
                )
            }
        }

        return AppletConfiguration(applets: applets)
    }
}

private struct AppletSpec {
    let id: String
    let name: String
    let type: AppletType
    let url: URL?
    let command: [String]
    let currentDirectory: String?
}

private enum AppletType: String {
    case web
    case terminal
}

private enum ValidationError: LocalizedError {
    case emptyApplets
    case invalidLine(Int)
    case invalidKey(String, Int)
    case missingName(String)
    case missingType(String)
    case missingWebURL(String)
    case unknownType(String, String)
    case invalidCommand(String)

    var errorDescription: String? {
        switch self {
        case .emptyApplets:
            "Configuration must contain at least one applet name."
        case .invalidLine(let lineNumber):
            "Line \(lineNumber) must use key = value syntax."
        case .invalidKey(let key, let lineNumber):
            "Line \(lineNumber) has invalid key '\(key)'. Use id.key = value."
        case .missingName(let id):
            "Applet '\(id)' must contain a name."
        case .missingType(let id):
            "Applet '\(id)' must contain a type."
        case .missingWebURL(let id):
            "Web applet '\(id)' must contain a valid url."
        case .unknownType(let type, let id):
            "Applet '\(id)' has unknown type '\(type)'."
        case .invalidCommand(let id):
            "Applet '\(id)' command must be a non-empty string array, for example [\"/bin/echo\", \"hello\"]."
        }
    }
}

private enum PresetValidationError: LocalizedError {
    case emptyPresets
    case emptyPreset(String)
    case duplicatePreset(String)
    case invalidSection(Int)

    var errorDescription: String? {
        switch self {
        case .emptyPresets:
            "Configuration must contain at least one preset section."
        case .emptyPreset(let id):
            "Preset '\(id)' must contain at least one applet."
        case .duplicatePreset(let id):
            "Preset '\(id)' is defined more than once."
        case .invalidSection(let lineNumber):
            "Line \(lineNumber) has an invalid section header."
        }
    }
}

private func parseCommand(_ text: String, appletID: String) throws -> [String] {
    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let data = trimmedText.data(using: .utf8) else {
        throw ValidationError.invalidCommand(appletID)
    }

    do {
        let command = try JSONDecoder().decode([String].self, from: data)
        guard let executable = command.first, !executable.isEmpty else {
            throw ValidationError.invalidCommand(appletID)
        }
        return command
    } catch {
        throw ValidationError.invalidCommand(appletID)
    }
}

struct ContentView: View {
    let settingsStore: SettingsStore
    @State private var selectedPresetID: String?

    var body: some View {
        switch Result(catching: { try PresetConfiguration.parse(settingsStore.configurationText) })
        {
        case .success(let presetConfiguration):
            PresetContentView(
                presetConfiguration: presetConfiguration,
                selectedPresetID: $selectedPresetID
            )
        case .failure(let error):
            ConfigurationErrorView(error: error)
        }
    }
}

private struct PresetContentView: View {
    let presetConfiguration: PresetConfiguration
    @Binding var selectedPresetID: String?

    var body: some View {
        if presetConfiguration.presets.count == 1, let preset = presetConfiguration.presets.first {
            AppletPresetView(preset: preset)
        } else if let selectedPreset {
            AppletPresetView(preset: selectedPreset)
        } else {
            PresetSelectionView(presets: presetConfiguration.presets) { preset in
                selectedPresetID = preset.id
            }
        }
    }

    private var selectedPreset: AppletPreset? {
        guard let selectedPresetID else {
            return nil
        }
        return presetConfiguration.presets.first { $0.id == selectedPresetID }
    }
}

private struct PresetSelectionView: View {
    let presets: [AppletPreset]
    let onSelect: (AppletPreset) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Preset")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(presets) { preset in
                    Button {
                        onSelect(preset)
                    } label: {
                        HStack {
                            Text(preset.displayName)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .frame(maxWidth: 360)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct AppletPresetView: View {
    let preset: AppletPreset

    var body: some View {
        switch Result(catching: { try AppletConfiguration.parse(preset.configurationText) }) {
        case .success(let configuration):
            AppletStackView(configuration: configuration)
        case .failure(let error):
            ConfigurationErrorView(error: error)
        }
    }
}

private struct AppletStackView: View {
    let configuration: AppletConfiguration

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(configuration.applets.enumerated()), id: \.offset) { _, applet in
                AppletView(applet: applet)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AppletView: View {
    let applet: AppletSpec

    var body: some View {
        switch applet.type {
        case .web:
            if let url = applet.url {
                StreamerAppletWebView(url: url)
            } else {
                ConfigurationErrorView(error: ValidationError.missingWebURL(applet.id))
            }
        case .terminal:
            TerminalAppletView(
                command: applet.command,
                currentDirectory: applet.currentDirectory
            )
        }
    }
}

private struct TerminalAppletView: NSViewRepresentable {
    let command: [String]
    let currentDirectory: String?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SimpleConsoleView {
        let terminalView = SimpleConsoleView(frame: .zero)
        terminalView.start(command: command, currentDirectory: currentDirectory)
        context.coordinator.startedCommand = command
        context.coordinator.currentDirectory = currentDirectory
        return terminalView
    }

    func updateNSView(_ terminalView: SimpleConsoleView, context: Context) {
        guard
            context.coordinator.startedCommand != command
                || context.coordinator.currentDirectory != currentDirectory
        else {
            return
        }

        terminalView.terminate()
        terminalView.start(command: command, currentDirectory: currentDirectory)
        context.coordinator.startedCommand = command
        context.coordinator.currentDirectory = currentDirectory
    }

    static func dismantleNSView(_ terminalView: SimpleConsoleView, coordinator: Coordinator) {
        terminalView.terminate()
        coordinator.startedCommand = nil
        coordinator.currentDirectory = nil
    }

    final class Coordinator {
        var startedCommand: [String]?
        var currentDirectory: String?
    }
}

private final class SimpleConsoleView: NSScrollView {
    private let textView = NSTextView()
    private var process: Process?
    private var standardOutputPipe: Pipe?
    private var standardErrorPipe: Pipe?
    private var activeColor = NSColor.labelColor

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        drawsBackground = true
        backgroundColor = .textBackgroundColor
        hasVerticalScroller = true
        hasHorizontalScroller = true
        autohidesScrollers = true
        borderType = .noBorder

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.usesFontPanel = false
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = false
        documentView = textView
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func start(command: [String], currentDirectory: String?) {
        terminate()
        activeColor = .labelColor

        let executable = command.first ?? "/usr/bin/true"
        let arguments = Array(command.dropFirst())

        let displayCommand = command.joined(separator: " ")
        append(text: "$ \(displayCommand)\n", color: .secondaryLabelColor)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let currentDirectory, !currentDirectory.isEmpty {
            process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
        }

        let standardOutputPipe = Pipe()
        let standardErrorPipe = Pipe()
        process.standardOutput = standardOutputPipe
        process.standardError = standardErrorPipe

        standardOutputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            DispatchQueue.main.async {
                self?.append(data: data, fallbackColor: .labelColor)
            }
        }
        standardErrorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            DispatchQueue.main.async {
                self?.append(data: data, fallbackColor: .systemRed)
            }
        }
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.append(
                    text: "\n[process exited with status \(process.terminationStatus)]\n",
                    color: .secondaryLabelColor
                )
            }
        }

        do {
            try process.run()
            self.process = process
            self.standardOutputPipe = standardOutputPipe
            self.standardErrorPipe = standardErrorPipe
        } catch {
            append(
                text: "Failed to start process: \(error.localizedDescription)\n", color: .systemRed)
        }
    }

    func terminate() {
        standardOutputPipe?.fileHandleForReading.readabilityHandler = nil
        standardErrorPipe?.fileHandleForReading.readabilityHandler = nil

        if let process, process.isRunning {
            let rootPID = process.processIdentifier
            terminateProcessTree(rootPID: rootPID, signal: SIGTERM)
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.8) {
                terminateProcessTree(rootPID: rootPID, signal: SIGKILL)
            }
        }

        process = nil
        standardOutputPipe = nil
        standardErrorPipe = nil
    }

    private func append(data: Data, fallbackColor: NSColor) {
        guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else {
            return
        }

        appendANSIText(text, fallbackColor: fallbackColor)
    }

    private func appendANSIText(_ text: String, fallbackColor: NSColor) {
        var index = text.startIndex
        var currentRun = ""
        activeColor = fallbackColor

        func flushRun() {
            guard !currentRun.isEmpty else {
                return
            }
            append(text: currentRun, color: activeColor)
            currentRun.removeAll(keepingCapacity: true)
        }

        while index < text.endIndex {
            if text[index] == "\u{001B}" {
                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex, text[nextIndex] == "[" {
                    var sequenceEnd = text.index(after: nextIndex)
                    while sequenceEnd < text.endIndex, text[sequenceEnd] != "m" {
                        sequenceEnd = text.index(after: sequenceEnd)
                    }

                    if sequenceEnd < text.endIndex {
                        flushRun()
                        let parameters = text[text.index(after: nextIndex)..<sequenceEnd]
                        applySGR(parameters: String(parameters), fallbackColor: fallbackColor)
                        index = text.index(after: sequenceEnd)
                        continue
                    }
                }
            }

            currentRun.append(text[index])
            index = text.index(after: index)
        }

        flushRun()
    }

    private func applySGR(parameters: String, fallbackColor: NSColor) {
        let values =
            parameters.isEmpty ? [0] : parameters.split(separator: ";").compactMap { Int($0) }
        for value in values {
            switch value {
            case 0, 39:
                activeColor = fallbackColor
            case 30:
                activeColor = .black
            case 31:
                activeColor = .systemRed
            case 32:
                activeColor = .systemGreen
            case 33:
                activeColor = .systemYellow
            case 34:
                activeColor = .systemBlue
            case 35:
                activeColor = .systemPurple
            case 36:
                activeColor = .systemCyan
            case 37:
                activeColor = .white
            case 90:
                activeColor = .systemGray
            case 91:
                activeColor = .systemRed
            case 92:
                activeColor = .systemGreen
            case 93:
                activeColor = .systemYellow
            case 94:
                activeColor = .systemBlue
            case 95:
                activeColor = .systemPurple
            case 96:
                activeColor = .systemCyan
            case 97:
                activeColor = .white
            default:
                break
            }
        }
    }

    private func append(text: String, color: NSColor) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                .foregroundColor: color,
            ]
            let attributedString = NSAttributedString(string: text, attributes: attributes)
            textView.textStorage?.append(attributedString)
            textView.scrollRangeToVisible(NSRange(location: textView.string.count, length: 0))
        }
    }
}

private func terminateProcessTree(rootPID: pid_t, signal: Int32) {
    let descendantPIDs = collectDescendantPIDs(of: rootPID)
    for pid in descendantPIDs.reversed() {
        kill(pid, signal)
    }
    kill(rootPID, signal)
}

private func collectDescendantPIDs(of parentPID: pid_t) -> [pid_t] {
    let childPIDs = directChildPIDs(of: parentPID)
    return childPIDs.flatMap { collectDescendantPIDs(of: $0) } + childPIDs
}

private func directChildPIDs(of parentPID: pid_t) -> [pid_t] {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    process.arguments = ["-P", String(parentPID)]
    process.standardOutput = pipe
    process.standardError = Pipe()

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return []
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else {
        return []
    }

    return
        output
        .split(whereSeparator: \.isNewline)
        .compactMap { pid_t($0.trimmingCharacters(in: .whitespaces)) }
}

private struct ConfigurationErrorView: View {
    let error: Error

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Invalid applet configuration")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.body)
                .textSelection(.enabled)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
