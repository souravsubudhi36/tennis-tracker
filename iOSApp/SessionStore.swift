import Foundation

@MainActor
final class SessionStore: ObservableObject {
    struct Entry: Identifiable {
        let metadata: SessionMetadata
        let directory: URL
        let receivedFiles: [String]

        var id: UUID { metadata.id }
        var missingFiles: [String] { metadata.files.filter { !receivedFiles.contains($0) } }
        var fileURLs: [URL] { receivedFiles.map { directory.appendingPathComponent($0) } }
    }

    @Published private(set) var sessions: [Entry] = []

    init() {
        reload()
    }

    func reload() {
        let fm = FileManager.default
        let directories = (try? fm.contentsOfDirectory(at: SessionFiles.rootDirectory, includingPropertiesForKeys: nil)) ?? []
        sessions = directories.compactMap { directory -> Entry? in
            // Sessions show up once meta.json has arrived.
            guard let data = try? Data(contentsOf: directory.appendingPathComponent(SessionFiles.metadata)),
                  let metadata = try? JSONDecoder.tennis.decode(SessionMetadata.self, from: data)
            else { return nil }
            let files = ((try? fm.contentsOfDirectory(atPath: directory.path)) ?? [])
                .filter { !$0.hasPrefix(".") }
                .sorted()
            return Entry(metadata: metadata, directory: directory, receivedFiles: files)
        }
        .sorted { $0.metadata.startDate > $1.metadata.startDate }
    }

    func delete(_ entry: Entry) {
        try? FileManager.default.removeItem(at: entry.directory)
        reload()
    }

    /// Called from the WatchConnectivity queue.
    nonisolated static func importFile(at source: URL, sessionID: UUID, fileName: String) throws {
        let fm = FileManager.default
        let directory = SessionFiles.directory(for: sessionID)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        // lastPathComponent guards against a name that tries to escape the session folder.
        let destination = directory.appendingPathComponent(URL(fileURLWithPath: fileName).lastPathComponent)
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.moveItem(at: source, to: destination)
    }
}
