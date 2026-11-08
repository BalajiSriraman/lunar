import AppKit

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    weak var library: Library?
    private var quitting = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let library else { return .terminateNow }
        guard !quitting else { return .terminateLater }
        quitting = true
        Task {
            await library.shutdown()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
