import SwiftUI
import AppKit

struct RemoteApp: Identifiable, Hashable {
    let id: String
    let name: String
}

struct Computer: Identifiable, Hashable {
    let id: String
    let name: String
    let address: String
    let apps: [RemoteApp]
}

enum LunarEngine {
    static var executable: String {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/Lunar Stream.app/Contents/MacOS/Moonlight").path
    }

    static func computers() -> [Computer] {
        let values = UserDefaults.standard.persistentDomain(forName: EngineSettings.domain) ?? [:]
        let count = values["hosts.size"] as? Int ?? 0
        guard count > 0 else { return [] }
        return (1...count).compactMap { index in
            let key = "hosts.\(index)."
            guard let name = values[key + "hostname"] as? String,
                  let uuid = values[key + "uuid"] as? String,
                  let certificate = values[key + "srvcert"] as? Data,
                  !certificate.isEmpty else { return nil }
            let address = ["manualaddress", "localaddress", "remoteaddress"]
                .compactMap { values[key + $0] as? String }.first { !$0.isEmpty } ?? name
            let appCount = values[key + "apps.size"] as? Int ?? 0
            let apps: [RemoteApp] = appCount > 0 ? (1...appCount).compactMap { appIndex in
                let prefix = key + "apps.\(appIndex)."
                guard let title = values[prefix + "name"] as? String,
                      let id = values[prefix + "id"] as? Int,
                      values[prefix + "hidden"] as? Bool != true else { return nil }
                return RemoteApp(id: String(id), name: title)
            } : []
            return Computer(id: uuid, name: name, address: address, apps: apps)
        }
    }

    @MainActor
    static func run(_ arguments: [String], process: Process) async throws -> (Int32, String) {
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["LUNAR_NATIVE_UI"] = "1"
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        return await Task.detached {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, String(decoding: data, as: UTF8.self))
        }.value
    }

    // Moonlight quotes app names and escapes embedded quotes as two quotes.
    static func parseApps(_ output: String) -> [RemoteApp] {
        output.components(separatedBy: .newlines).compactMap { line in
            var fields: [String] = []
            var field = ""
            var quoted = false
            var index = line.startIndex
            while index < line.endIndex {
                let char = line[index]
                let next = line.index(after: index)
                if char == "\"" {
                    if quoted && next < line.endIndex && line[next] == "\"" {
                        field.append("\"")
                        index = line.index(after: next)
                        continue
                    }
                    quoted.toggle()
                } else if char == "," && !quoted {
                    fields.append(field.trimmingCharacters(in: .whitespaces))
                    field = ""
                } else { field.append(char) }
                index = next
            }
            fields.append(field.trimmingCharacters(in: .whitespaces))
            guard fields.count >= 6, Int(fields[1]) != nil, fields[4] != "true" else { return nil }
            return RemoteApp(id: fields[1], name: fields[0])
        }
    }
}

@MainActor
final class Library: ObservableObject {
    @Published var computers: [Computer] = []
    @Published var pairing = false
    @Published var showSetup = false
    let pairingConnection = Pairing()
    private var listingProcess: Process?
    @Published private(set) var quitting = false
    private var configured = false
    @Published var selected: String?
    @Published var apps: [RemoteApp] = []
    @Published var busy = false
    @Published var connection: StreamConnection?
    var streaming: Bool { connection != nil }
    @Published var checked = false
    @Published var notice: String?
    @Published var search = ""

    var computer: Computer? { computers.first { $0.id == selected } }
    var filteredApps: [RemoteApp] {
        apps.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
    }

    init() {
        do { try EngineSettings.prepare(); configured = true }
        catch { notice = error.localizedDescription }
        computers = LunarEngine.computers()
        selected = computers.first?.id
        apps = computers.first?.apps ?? []
    }

    func refresh() async {
        guard configured, !quitting, !busy, !pairing, !streaming, let computer else { return }
        busy = true
        checked = false
        notice = nil
        defer { busy = false }
        do {
            let child = Process()
            listingProcess = child
            defer { listingProcess = nil }
            let (code, output) = try await LunarEngine.run(["list", "--csv", computer.address], process: child)
            guard selected == computer.id else { return }
            guard code == 0 else {
                notice = "Cannot reach this computer. Check its connection or pair it again in Lunar."
                return
            }
            apps = LunarEngine.parseApps(output)
            checked = true
        } catch { notice = error.localizedDescription }
    }

    func connect(_ app: RemoteApp) {
        guard configured, !quitting, !streaming, !busy, !pairing, let computer else { return }
        let defaults = UserDefaults.standard
        let resolution = defaults.string(forKey: "resolution") ?? "Inherited"
        let fps = defaults.string(forKey: "fps") ?? "Inherited"
        let mode = defaults.string(forKey: "displayMode") ?? "Inherited"
        var arguments = ["stream"]
        if resolution != "Inherited" { arguments += ["--resolution", resolution] }
        if fps != "Inherited" { arguments += ["--fps", fps] }
        if mode != "Inherited" { arguments += ["--display-mode", mode] }
        arguments += [computer.address, app.name]
        let stream = StreamConnection(appName: app.name, computerName: computer.name, arguments: arguments)
        connection = stream
        stream.start()
    }

    func requestQuit() {
        quitting = true
        pairingConnection.cancel()
        if showSetup { showSetup = false }
        else { NSApp.perform(#selector(NSApplication.terminate(_:)), with: nil, afterDelay: 0) }
    }

    func shutdown() async {
        quitting = true
        connection?.cancel()
        pairingConnection.cancel()
        let listing = listingProcess
        if let listing, listing.isRunning { listing.terminate() }
        await connection?.stopForQuit()
        await pairingConnection.stopForQuit()
        if let listing { await Task.detached { listing.waitUntilExit() }.value }
    }


}

@main
struct Lunar: App {
    @StateObject private var library = Library()
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            LibraryView().environmentObject(library)
                .frame(minWidth: 760, minHeight: 500)
                .onAppear { appDelegate.library = library }
        }
        .defaultSize(width: 1040, height: 680)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit Lunar") { library.requestQuit() }.keyboardShortcut("q")
            }
            CommandGroup(replacing: .newItem) {
                Button("Add Computer…") { library.showSetup = true }
                    .keyboardShortcut("n")
                    .disabled(library.busy || library.pairing || library.streaming)
            }
            CommandGroup(after: .newItem) {
                Button("Refresh Computers") { Task { await library.refresh() } }
                    .keyboardShortcut("r")
                    .disabled(library.busy || library.pairing || library.streaming)
            }
        }
        Settings { StreamSettings().frame(width: 440) }
    }
}

struct LibraryView: View {
    @EnvironmentObject private var library: Library

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $library.selected) {
                    Section("Computers") {
                        ForEach(library.computers) { computer in
                            Label(computer.name, systemImage: "desktopcomputer")
                                .padding(.vertical, 5).tag(computer.id)
                        }
                    }
                }
                .listStyle(.sidebar).disabled(library.pairing || library.streaming)
                Divider()
                HStack {
                    Image(systemName: "moonphase.waning.crescent.inverse").font(.title2)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lunar").font(.headline)
                        Text("Your computers, closer.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    SettingsLink { Image(systemName: "gearshape") }
                        .buttonStyle(.plain).help("Stream settings").accessibilityLabel("Stream settings")
                }.padding(16)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 235, max: 300)
        } detail: {
            if let connection = library.connection {
                ConnectionView(connection: connection) { library.connection = nil }
                    .navigationTitle(connection.appName)
            } else {
            if let computer = library.computer {
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        HStack(alignment: .top, spacing: 18) {
                            Image(systemName: "desktopcomputer")
                                .font(.system(size: 31, weight: .light))
                                .frame(width: 66, height: 66)
                                .background(.tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 7) {
                                Text(computer.name).font(.system(size: 28, weight: .semibold)).accessibilityAddTraits(.isHeader)
                                Text(computer.address).font(.callout).foregroundStyle(.secondary)
                                Label(library.busy ? "Checking connection…" : library.checked ? "Available" : "Saved computer",
                                      systemImage: library.checked ? "checkmark.circle.fill" : "network")
                                    .font(.caption).foregroundStyle(library.checked ? Color.green : .secondary)
                            }
                            Spacer()
                        }

                        if let notice = library.notice {
                            Label(notice, systemImage: "exclamationmark.triangle")
                                .font(.callout).foregroundStyle(.secondary)
                                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Applications").font(.headline).accessibilityAddTraits(.isHeader)
                                Text("\(library.filteredApps.count)").font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            if library.filteredApps.isEmpty {
                                ContentUnavailableView(library.search.isEmpty ? "No applications" : "No results",
                                                       systemImage: library.search.isEmpty ? "app.dashed" : "magnifyingglass",
                                                       description: Text(library.search.isEmpty ? "Refresh the connection or check the host in LunarEngine." : "Try another app name."))
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 245, maximum: 350))], alignment: .leading, spacing: 18) {
                                    ForEach(library.filteredApps) { app in
                                        AppCard(app: app, computer: computer)
                                    }
                                }
                            }
                        }
                        Spacer(minLength: 30)
                        HStack(spacing: 7) {
                            Image(systemName: "keyboard")
                            Text("End a stream with Control + Option + Shift + Q.")
                        }.font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .navigationTitle("Library")
            } else {
                ContentUnavailableView {
                    Label("Add your first computer", systemImage: "desktopcomputer")
                } description: {
                    Text("Add the address of a computer that runs Sunshine.")
                } actions: {
                    Button("Add Computer…") { library.showSetup = true }
                        .buttonStyle(.borderedProminent)
                    Button("Reload Computers") {
                        library.computers = LunarEngine.computers()
                        library.selected = library.computers.first?.id
                    }
                }
            }
        }
        }
        .searchable(text: $library.search, placement: .toolbar, prompt: "Find an application")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    library.computers = LunarEngine.computers()
                    Task { await library.refresh() }
                } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Refresh applications")
                    .help("Refresh applications (⌘R)").disabled(library.busy || library.pairing || library.streaming)
                Button { library.showSetup = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add a computer")
                    .help("Add a computer").disabled(library.busy || library.pairing || library.streaming)
            }
        }
        .task(id: library.selected) {
            library.apps = library.computer?.apps ?? []
            library.checked = false
            await library.refresh()
        }
        .onChange(of: library.showSetup) { _, shown in library.pairing = shown }
        .sheet(isPresented: $library.showSetup, onDismiss: {
            if library.quitting { NSApp.perform(#selector(NSApplication.terminate(_:)), with: nil, afterDelay: 0); return }
            library.pairing = false
            library.computers = LunarEngine.computers()
            if library.selected == nil { library.selected = library.computers.first?.id }
            Task { await library.refresh() }
        }) {
            PairComputerView(pairing: library.pairingConnection) {
                library.showSetup = false
            }
        }
    }
}

struct AppCard: View {
    @EnvironmentObject private var library: Library
    let app: RemoteApp
    let computer: Computer
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button { library.connect(app) } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    LinearGradient(colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle().stroke(Color.accentColor.opacity(0.08), lineWidth: 1).frame(width: 210, height: 210).offset(x: 90, y: -45)
                    Circle().stroke(Color.accentColor.opacity(0.08), lineWidth: 1).frame(width: 150, height: 150).offset(x: 90, y: -45)
                    Image(systemName: "display").font(.system(size: 61, weight: .ultraLight))
                        .foregroundStyle(Color.accentColor)
                }.frame(height: 165).clipped()
                VStack(alignment: .leading, spacing: 13) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name).font(.headline).foregroundStyle(.primary)
                        Text(computer.name).font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        Label(library.streaming ? "Stream in progress" : "Connect", systemImage: "play.fill")
                            .font(.callout.weight(.medium))
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
                    }.foregroundStyle(.tint)
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(hovered ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.09)))
            .shadow(color: .black.opacity(hovered ? 0.07 : 0.025), radius: 8, y: 3)
            .offset(y: hovered && !reduceMotion ? -2 : 0)
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain).disabled(library.streaming || library.busy || library.pairing)
        .onHover { hovered = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: hovered)
        .help("Stream \(app.name)")
        .accessibilityLabel("Connect to \(app.name) on \(computer.name)")
        .accessibilityHint("Opens a stream from this computer.")
    }
}

struct StreamSettings: View {
    @AppStorage("resolution") private var resolution = "Inherited"
    @AppStorage("fps") private var fps = "Inherited"
    @AppStorage("displayMode") private var displayMode = "Inherited"

    var body: some View {
        Form {
            Section {
                Picker("Resolution", selection: $resolution) {
                    Text("Saved setting").tag("Inherited")
                    Text("1080p").tag("1920x1080")
                    Text("1440p").tag("2560x1440")
                    Text("4K").tag("3840x2160")
                }
                Picker("Frame rate", selection: $fps) {
                    Text("Saved setting").tag("Inherited")
                    Text("60 fps").tag("60")
                    Text("90 fps").tag("90")
                    Text("120 fps").tag("120")
                }
                Picker("Display", selection: $displayMode) {
                    Text("Saved setting").tag("Inherited")
                    Text("Full screen").tag("fullscreen")
                    Text("Borderless").tag("borderless")
                    Text("Window").tag("windowed")
                }
            } header: { Text("Streaming") } footer: {
                Text("Changes apply to the next stream. Other options use settings saved in Lunar.")
            }
            Section {
                LabeledContent("Streaming engine", value: "Based on Moonlight · Included")
            }
        }.formStyle(.grouped).padding(8)
    }
}
