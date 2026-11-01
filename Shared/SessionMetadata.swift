import Foundation

enum SensorSource: String, Codable {
    /// CMBatchedSensorManager: 800 Hz accelerometer + 200 Hz device motion (Series 8+, Ultra).
    case batched
    /// CMMotionManager fallback: 100 Hz device motion only.
    case motionManager
}

/// Written by the watch as meta.json next to the CSV files of a session.
struct SessionMetadata: Codable, Identifiable {
    var schemaVersion = 1
    let id: UUID
    var startDate: Date
    var endDate: Date
    var indoor: Bool

    /// nil if the player hadn't set up a profile on the phone yet.
    var profile: PlayerProfile?
    var placement: WatchPlacement

    var sensorSource: SensorSource
    var accelerometerHz: Double?
    var deviceMotionHz: Double
    var accelerometerSamples: Int
    var deviceMotionSamples: Int

    var averageHeartRate: Double?
    var activeEnergyKcal: Double?

    var watchModel: String
    var watchOSVersion: String

    /// Every file that belongs to this session, including meta.json.
    var files: [String]

    var duration: TimeInterval { endDate.timeIntervalSince(startDate) }
}

enum SessionFiles {
    static let metadata = "meta.json"
    static let accelerometer = "accel.csv"
    static let deviceMotion = "motion.csv"
    /// Watch only: marks a finished session whose files may be sent to the phone.
    static let readyMarker = ".ready"

    static let accelerometerHeader = "t,ax,ay,az"
    static let deviceMotionHeader = "t,user_ax,user_ay,user_az,grav_x,grav_y,grav_z,rot_x,rot_y,rot_z,q_w,q_x,q_y,q_z"

    static var rootDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sessions", isDirectory: true)
    }

    static func directory(for id: UUID) -> URL {
        rootDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
    }
}

/// Keys shared by both sides of WatchConnectivity.
enum SyncKey {
    /// Phone → watch application context: JSON-encoded PlayerProfile.
    static let profile = "profile"
    /// Watch → phone application context: JSON-encoded WatchPlacement.
    static let watchPlacement = "watchPlacement"
    /// transferFile metadata.
    static let sessionID = "sessionID"
    static let fileName = "fileName"
}

extension JSONEncoder {
    static var tennis: JSONEncoder {
        let encoder = JSONEncoder()
        // Seconds since 1970 keeps sub-second precision, which matters for syncing with video.
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var tennis: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}
