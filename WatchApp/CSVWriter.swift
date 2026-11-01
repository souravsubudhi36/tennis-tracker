import Foundation

/// Buffered CSV writer. Not thread-safe: each writer must be fed from a single task or queue.
final class CSVWriter {
    private let handle: FileHandle
    private var buffer = Data()
    private let flushThreshold = 64 * 1024
    private(set) var rowCount = 0

    init(url: URL, header: String) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try FileHandle(forWritingTo: url)
        buffer.append(contentsOf: (header + "\n").utf8)
    }

    func appendRow(time: Double, _ values: [Double]) {
        var line = String(format: "%.6f", time)
        for value in values {
            line += String(format: ",%.5f", value)
        }
        line += "\n"
        buffer.append(contentsOf: line.utf8)
        rowCount += 1
        if buffer.count >= flushThreshold { flush() }
    }

    func close() {
        flush()
        try? handle.close()
    }

    private func flush() {
        guard !buffer.isEmpty else { return }
        do {
            try handle.write(contentsOf: buffer)
        } catch {
            print("CSVWriter: write failed: \(error)")
        }
        buffer.removeAll(keepingCapacity: true)
    }
}
