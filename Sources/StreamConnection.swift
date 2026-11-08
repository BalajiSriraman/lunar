import AppKit
import SwiftUI

struct EngineEvent: Decodable {
    let type: String
    let message: String
}

@MainActor
final class StreamConnection: ObservableObject {
    enum Phase { case connecting, connected, failed, ended, cancelling }
    @Published var phase: Phase = .connecting
    @Published var stage = "Connecting to computer…"
    @Published var failure: String?
    @Published var warning: String?
    @Published var running = false
    let appName: String
    let computerName: String
    private let arguments: [String]
    private var process: Process?
    private var buffer = Data()
    private var cancelled = false
    private var quitting = false

    init(appName: String, computerName: String, arguments: [String]) {
        self.appName = appName
        self.computerName = computerName
        self.arguments = arguments
    }

    func start() {
        guard !running else { return }
        phase = .connecting
        failure = nil
        warning = nil
        cancelled = false
        buffer.removeAll()
        stage = "Connecting to computer…"
        let executable = URL(fileURLWithPath: LunarEngine.executable)
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            failure = "The stream engine is missing. Build or install Lunar again."
            phase = .failed
            return
        }
        let child = Process()
        child.executableURL = executable
        child.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["LUNAR_NATIVE_UI"] = "1"
        child.environment = environment
        let output = Pipe()
        child.standardOutput = output
        child.standardError = FileHandle.nullDevice
        do {
            try child.run()
            process = child
            running = true
            Task.detached { [weak self] in
                let handle = output.fileHandleForReading
                while true {
                    let data = handle.availableData
                    guard !data.isEmpty else { break }
                    await self?.receive(data)
                }
                child.waitUntilExit()
                await self?.didExit(child.terminationStatus)
            }
        } catch {
            failure = error.localizedDescription
            phase = .failed
        }
    }

    private func receive(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 10) {
            let line = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            guard let event = try? JSONDecoder().decode(EngineEvent.self, from: line) else { continue }
            switch event.type {
            case "quit": NSApp.perform(#selector(NSApplication.terminate(_:)), with: nil, afterDelay: 0)
            case "progress": stage = event.message
            case "connected": phase = .connected
            case "warning": warning = event.message
            case "error": failure = event.message; phase = .failed
            default: break
            }
        }
    }

    private func didExit(_ code: Int32) {
        running = false
        process = nil
        if cancelled { phase = .ended }
        else if failure != nil { phase = .failed }
        else if code != 0 {
            failure = "The stream engine stopped (code \(code)). Check the computer connection and try again."
            phase = .failed
        } else { phase = .ended }
        if !quitting { NSApp.activate(ignoringOtherApps: true) }
    }

    func stopForQuit() async {
        quitting = true
        cancel()
        guard let process else { return }
        await Task.detached { process.waitUntilExit() }.value
    }

    func cancel() {
        guard !cancelled, let process, process.isRunning else { return }
        cancelled = true
        phase = .cancelling
        process.terminate()
    }
}

struct ConnectionView: View {
    @ObservedObject var connection: StreamConnection
    let dismiss: () -> Void

    private var title: String {
        switch connection.phase {
        case .connecting: "Connecting to \(connection.computerName)"
        case .connected: "Connected to \(connection.computerName)"
        case .failed: "Could not start the stream"
        case .ended: "Connection closed"
        case .cancelling: "Closing connection…"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 22) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.tint)
                        .frame(width: 108, height: 108)
                        .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 26))
                    if connection.phase == .failed {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 27)).symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .orange)
                            .offset(x: 7, y: 5)
                    }
                }
                VStack(spacing: 8) {
                    Text(title).font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                        .multilineTextAlignment(.center)
                    Text(connection.appName).font(.body).foregroundStyle(.secondary)
                }
                if connection.phase == .connecting || connection.phase == .cancelling {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text(connection.phase == .cancelling ? "Waiting for the connection to close…" : connection.stage)
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
                if let failure = connection.failure, connection.phase == .failed {
                    Text(failure).font(.callout).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).textSelection(.enabled)
                        .padding(16).frame(maxWidth: 460)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }
                if let warning = connection.warning, connection.phase != .failed {
                    Label(warning, systemImage: "info.circle").font(.caption)
                        .foregroundStyle(.secondary).frame(maxWidth: 460)
                }
                HStack(spacing: 12) {
                    if connection.phase == .failed || connection.phase == .ended {
                        Button("Back to Library", action: dismiss).disabled(connection.running)
                        if connection.phase == .failed {
                            Button("Try Again") { connection.start() }
                                .buttonStyle(.borderedProminent).disabled(connection.running)
                        }
                    } else {
                        Button(connection.phase == .connected ? "Disconnect" : "Cancel") { connection.cancel() }
                            .disabled(connection.phase == .cancelling)
                    }
                }.controlSize(.large)
            }
            .padding(40)
            .frame(maxWidth: 600)
            Spacer()
            Label("End a stream with Control + Option + Shift + Q.", systemImage: "keyboard")
                .font(.caption).foregroundStyle(.secondary).padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}
