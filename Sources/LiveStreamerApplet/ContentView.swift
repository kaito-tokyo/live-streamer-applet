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

import Foundation
import AppKit
import SwiftUI
import Darwin

private struct AppletConfiguration {
    let applets: [AppletSpec]

    static func parse(_ configurationText: String) throws -> AppletConfiguration {
        var records: [String: [String: String]] = [:]
        var orderedIDs: [String] = []
        var orderedIDSet: Set<String> = []

        for (lineIndex, rawLine) in configurationText.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            guard !line.isEmpty, !line.hasPrefix("#"), !line.hasPrefix(";") else {
                continue
            }

            guard let separatorIndex = line.firstIndex(of: "=") else {
                throw ValidationError.invalidLine(lineIndex + 1)
            }

            let left = line[..<separatorIndex].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: separatorIndex)...].trimmingCharacters(in: .whitespaces)
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

                return AppletSpec(id: id, name: name, type: type, url: url, command: [], currentDirectory: nil)
            case .terminal:
                let command = try parseCommand(fields["command"] ?? "[\"/usr/bin/true\"]", appletID: id)
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
        case let .invalidLine(lineNumber):
            "Line \(lineNumber) must use key = value syntax."
        case let .invalidKey(key, lineNumber):
            "Line \(lineNumber) has invalid key '\(key)'. Use id.key = value."
        case let .missingName(id):
            "Applet '\(id)' must contain a name."
        case let .missingType(id):
            "Applet '\(id)' must contain a type."
        case let .missingWebURL(id):
            "Web applet '\(id)' must contain a valid url."
        case let .unknownType(type, id):
            "Applet '\(id)' has unknown type '\(type)'."
        case let .invalidCommand(id):
            "Applet '\(id)' command must be a non-empty string array, for example [\"/bin/echo\", \"hello\"]."
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

    var body: some View {
        switch Result(catching: { try AppletConfiguration.parse(settingsStore.configurationText) }) {
        case let .success(configuration):
            AppletStackView(configuration: configuration)
        case let .failure(error):
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
            append(text: "Failed to start process: \(error.localizedDescription)\n", color: .systemRed)
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
        let values = parameters.isEmpty ? [0] : parameters.split(separator: ";").compactMap { Int($0) }
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

    return output
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
