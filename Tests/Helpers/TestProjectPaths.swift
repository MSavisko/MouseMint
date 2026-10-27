import Foundation

enum TestProjectPaths {
    static var root: URL {
        var folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while folder.path != "/" {
            if FileManager.default.fileExists(atPath: folder.appendingPathComponent("Project.swift").path) { return folder }
            folder.deleteLastPathComponent()
        }
        preconditionFailure("Cannot locate the test project's root")
    }
}
