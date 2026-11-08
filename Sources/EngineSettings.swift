import Foundation

enum EngineSettings {
    static let domain = "com.balaji.lunar.engine"

    static func prepare() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: LunarEngine.executable)
        process.arguments = ["--version"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "Lunar", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "Lunar could not load its computer settings. Check your home folder permissions."])
        }
    }
}
