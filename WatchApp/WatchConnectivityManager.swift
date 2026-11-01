import Foundation
import WatchConnectivity
import WatchKit

/// Watch side of the phone link: receives the player profile, reports which wrist the
/// watch is on, and ships finished sessions to the phone.
final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published private(set) var profile: PlayerProfile?
    @Published private(set) var pendingTransfers = 0

    private static let profileDefaultsKey = "profile"

    private override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: Self.profileDefaultsKey) {
            profile = try? JSONDecoder.tennis.decode(PlayerProfile.self, from: data)
        }
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    /// From the user's Watch settings (Watch app › General › Watch Orientation).
    var currentPlacement: WatchPlacement {
        let device = WKInterfaceDevice.current()
        return WatchPlacement(
            wrist: device.wristLocation == .left ? .left : .right,
            crown: device.crownOrientation == .left ? .left : .right
        )
    }

    /// Queues every file of every finished session that isn't already on its way to the phone.
    /// Files are deleted from the watch once delivered, so this also retries failed transfers.
    func sendFinishedSessions() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let fm = FileManager.default
        let inFlight = Set(session.outstandingFileTransfers.map { $0.file.fileURL.resolvingSymlinksInPath().path })
        let directories = (try? fm.contentsOfDirectory(at: SessionFiles.rootDirectory, includingPropertiesForKeys: nil)) ?? []

        for directory in directories {
            guard let id = UUID(uuidString: directory.lastPathComponent),
                  fm.fileExists(atPath: directory.appendingPathComponent(SessionFiles.readyMarker).path)
            else { continue }  // still recording, or not ours

            let files = ((try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
                .filter { !$0.lastPathComponent.hasPrefix(".") }
                // meta.json last, so the phone usually has the CSVs by the time it lists the session.
                .sorted { ($0.lastPathComponent == SessionFiles.metadata ? 1 : 0) < ($1.lastPathComponent == SessionFiles.metadata ? 1 : 0) }

            if files.isEmpty {
                try? fm.removeItem(at: directory)
                continue
            }
            for file in files where !inFlight.contains(file.resolvingSymlinksInPath().path) {
                session.transferFile(file, metadata: [
                    SyncKey.sessionID: id.uuidString,
                    SyncKey.fileName: file.lastPathComponent,
                ])
            }
        }
        updatePendingCount()
    }

    private func sendPlacement() {
        guard let data = try? JSONEncoder.tennis.encode(currentPlacement) else { return }
        try? WCSession.default.updateApplicationContext([SyncKey.watchPlacement: data])
    }

    private func applyProfile(from context: [String: Any]) {
        guard let data = context[SyncKey.profile] as? Data,
              let profile = try? JSONDecoder.tennis.decode(PlayerProfile.self, from: data)
        else { return }
        UserDefaults.standard.set(data, forKey: Self.profileDefaultsKey)
        DispatchQueue.main.async { self.profile = profile }
    }

    private func updatePendingCount() {
        let count = WCSession.default.outstandingFileTransfers.count
        DispatchQueue.main.async { self.pendingTransfers = count }
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        guard state == .activated else { return }
        applyProfile(from: session.receivedApplicationContext)
        sendPlacement()
        sendFinishedSessions()
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        applyProfile(from: applicationContext)
    }

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        if let error {
            print("Transfer of \(fileTransfer.file.fileURL.lastPathComponent) failed: \(error)")
        } else {
            let url = fileTransfer.file.fileURL
            let fm = FileManager.default
            try? fm.removeItem(at: url)
            let directory = url.deletingLastPathComponent()
            let remaining = ((try? fm.contentsOfDirectory(atPath: directory.path)) ?? []).filter { !$0.hasPrefix(".") }
            if remaining.isEmpty { try? fm.removeItem(at: directory) }
        }
        updatePendingCount()
    }
}
