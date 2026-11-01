import Foundation
import WatchConnectivity

/// Phone side of the watch link: pushes the player profile to the watch, learns which wrist
/// the watch is on, and files incoming session recordings.
final class PhoneConnectivity: NSObject, WCSessionDelegate {
    static let shared = PhoneConnectivity()

    /// Called on the main queue.
    var onPlacement: ((WatchPlacement) -> Void)?
    /// Called on the main queue after a session file has been stored.
    var onFileReceived: (() -> Void)?

    private var latestProfile: PlayerProfile?

    func activate(profile: PlayerProfile?) {
        latestProfile = profile
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(profile: PlayerProfile) {
        latestProfile = profile
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated,
              let data = try? JSONEncoder.tennis.encode(profile)
        else { return }
        do {
            try session.updateApplicationContext([SyncKey.profile: data])
        } catch {
            print("Couldn't send profile to watch: \(error)")
        }
    }

    private func applyPlacement(from context: [String: Any]) {
        guard let data = context[SyncKey.watchPlacement] as? Data,
              let placement = try? JSONDecoder.tennis.decode(WatchPlacement.self, from: data)
        else { return }
        DispatchQueue.main.async { self.onPlacement?(placement) }
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        guard state == .activated else { return }
        applyPlacement(from: session.receivedApplicationContext)
        if let latestProfile { send(profile: latestProfile) }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        applyPlacement(from: applicationContext)
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // The system deletes file.fileURL when this method returns, so move it synchronously.
        guard let idString = file.metadata?[SyncKey.sessionID] as? String,
              let id = UUID(uuidString: idString),
              let name = file.metadata?[SyncKey.fileName] as? String
        else { return }
        do {
            try SessionStore.importFile(at: file.fileURL, sessionID: id, fileName: name)
        } catch {
            print("Couldn't store \(name): \(error)")
        }
        DispatchQueue.main.async { self.onFileReceived?() }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // The user switched to another watch; reconnect to it.
        WCSession.default.activate()
    }
}
