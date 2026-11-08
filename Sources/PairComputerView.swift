import SwiftUI

@MainActor
final class Pairing: ObservableObject {
    @Published var address = ""
    @Published var pin = ""
    @Published var failure: String?
    @Published var running = false
    @Published var paired = false
    private var process: Process?
    @Published private(set) var cancelled = false

    func start() {
        guard !running else { return }
        let host = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, !host.hasPrefix("-"), !host.contains(where: { $0.isWhitespace }) else {
            failure = "Enter a computer name or IP address."
            return
        }
        pin = String(format: "%04d", Int.random(in: 0...9999))
        failure = nil
        paired = false
        cancelled = false
        let child = Process()
        child.executableURL = URL(fileURLWithPath: LunarEngine.executable)
        child.arguments = ["pair", "--pin", pin, host]
        var environment = ProcessInfo.processInfo.environment
        environment["LUNAR_NATIVE_UI"] = "1"
        child.environment = environment
        let pipe = Pipe()
        child.standardOutput = pipe
        child.standardError = FileHandle.nullDevice
        do {
            try child.run()
            process = child
            running = true
            Task.detached { [weak self] in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                child.waitUntilExit()
                await self?.finish(data, code: child.terminationStatus)
            }
        } catch { failure = error.localizedDescription }
    }

    private func finish(_ data: Data, code: Int32) {
        running = false
        process = nil
        guard !cancelled else { return }
        let events = data.split(separator: 10).compactMap { try? JSONDecoder().decode(EngineEvent.self, from: Data($0)) }
        if code == 0 && events.contains(where: { $0.type == "paired" }) {
            paired = true
        } else {
            failure = events.last(where: { $0.type == "error" })?.message
                ?? "Pairing could not finish. Check the address and try again."
        }
    }

    func stopForQuit() async {
        cancel()
        guard let process else { return }
        await Task.detached { process.waitUntilExit() }.value
    }

    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        process?.terminate()
    }
}

struct PairComputerView: View {
    @ObservedObject var pairing: Pairing
    @FocusState private var addressFocused: Bool
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Add a computer", systemImage: "desktopcomputer.badge.plus")
                .font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
            Text("Connect to a computer that runs Sunshine.")
                .foregroundStyle(.secondary)
            TextField("Computer name or IP address", text: $pairing.address)
                .textFieldStyle(.roundedBorder).disabled(pairing.running)
                .accessibilityLabel("Computer name or IP address")
                .focused($addressFocused)
                .onSubmit { pairing.start() }
            if pairing.running {
                VStack(alignment: .leading, spacing: 12) {
                    Text(pairing.pin).font(.system(size: 36, weight: .medium, design: .monospaced))
                        .textSelection(.enabled).accessibilityLabel("Pairing PIN: \(pairing.pin.map(String.init).joined(separator: " "))")
                    Text("Enter this PIN in Sunshine on that computer.")
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Waiting for the computer…").foregroundStyle(.secondary)
                    }
                }
            }
            if let failure = pairing.failure {
                Label(failure, systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Cancel") { pairing.cancel(); if !pairing.running { dismiss() } }.keyboardShortcut(.cancelAction)
                Button(pairing.failure == nil ? "Pair Computer" : "Try Again") { pairing.start() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(pairing.running || pairing.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(28).frame(width: 420)
        .interactiveDismissDisabled(pairing.running)
        .onAppear { addressFocused = true }
        .onChange(of: pairing.paired) { _, paired in if paired { dismiss() } }
        .onChange(of: pairing.running) { _, running in
            if !running && pairing.cancelled { dismiss() }
        }
        .onDisappear { pairing.cancel() }
    }
}
