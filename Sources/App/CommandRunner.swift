import Foundation

struct CommandOutput {
    var status: Int32 = 0
    var stdout = ""
    var stderr = ""
}
struct CommandRunner {
    let readMouse: () throws -> MouseReading
    let readScrolling: () -> NaturalScrollingState
    let migrate: () -> Void
    let runGUI: (Bool, Bool) -> Int32
    func run(_ arguments: [String]) -> CommandOutput {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if arguments.contains("--scroll-status") {
                return CommandOutput(stdout: String(decoding: try encoder.encode(readScrolling()), as: UTF8.self))
            }
            if arguments.contains("--read-json") {
                encoder.dateEncodingStrategy = .iso8601
                return CommandOutput(stdout: String(decoding: try encoder.encode(readMouse()), as: UTF8.self))
            }
            let inspection = arguments.contains("--check-ui")
            if !inspection { migrate() }
            return CommandOutput(status: runGUI(inspection, arguments.contains("--settings")))
        } catch {
            return CommandOutput(status: 1, stderr: String(describing: error))
        }
    }
}
