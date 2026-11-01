import CoreMotion
import Foundation

/// Records raw motion to CSV for the length of a workout.
///
/// Uses CMBatchedSensorManager (800 Hz accelerometer, 200 Hz device motion) where supported,
/// otherwise falls back to 100 Hz device motion from CMMotionManager. The batched manager only
/// delivers data while an HKWorkoutSession is running, so call `start()` once it is.
final class SensorRecorder: @unchecked Sendable {
    struct Summary {
        let source: SensorSource
        let accelerometerHz: Double?
        let deviceMotionHz: Double
        let accelerometerSamples: Int
        let deviceMotionSamples: Int
        let files: [String]
    }

    static let fallbackMotionHz = 100.0

    let directory: URL
    let source: SensorSource

    /// CMLogItem timestamps are seconds since boot; adding this converts them to Unix time.
    private let bootEpoch = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime

    private var batchedManager: CMBatchedSensorManager?
    private let motionManager = CMMotionManager()
    private let motionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()
    private var tasks: [Task<Void, Never>] = []
    private let accelWriter: CSVWriter?
    private let motionWriter: CSVWriter
    private var started = false

    init(directory: URL) throws {
        self.directory = directory
        source = CMBatchedSensorManager.isAccelerometerSupported && CMBatchedSensorManager.isDeviceMotionSupported
            ? .batched : .motionManager

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        motionWriter = try CSVWriter(
            url: directory.appendingPathComponent(SessionFiles.deviceMotion),
            header: SessionFiles.deviceMotionHeader
        )
        accelWriter = source == .batched
            ? try CSVWriter(url: directory.appendingPathComponent(SessionFiles.accelerometer),
                            header: SessionFiles.accelerometerHeader)
            : nil
    }

    func start() {
        guard !started else { return }
        started = true
        let bootEpoch = bootEpoch
        let motionWriter = motionWriter

        switch source {
        case .batched:
            let manager = CMBatchedSensorManager()
            batchedManager = manager
            if let accelWriter {
                tasks.append(Task.detached(priority: .userInitiated) {
                    do {
                        for try await batch in manager.accelerometerUpdates() {
                            for sample in batch {
                                let a = sample.acceleration
                                accelWriter.appendRow(time: bootEpoch + sample.timestamp, [a.x, a.y, a.z])
                            }
                        }
                    } catch {
                        print("SensorRecorder: accelerometer stream ended: \(error)")
                    }
                })
            }
            tasks.append(Task.detached(priority: .userInitiated) {
                do {
                    for try await batch in manager.deviceMotionUpdates() {
                        for motion in batch {
                            Self.write(motion, to: motionWriter, bootEpoch: bootEpoch)
                        }
                    }
                } catch {
                    print("SensorRecorder: device motion stream ended: \(error)")
                }
            })

        case .motionManager:
            motionManager.deviceMotionUpdateInterval = 1 / Self.fallbackMotionHz
            motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: motionQueue) { motion, _ in
                guard let motion else { return }
                Self.write(motion, to: motionWriter, bootEpoch: bootEpoch)
            }
        }
    }

    /// Stops the sensors, flushes and closes the files.
    func stop() async -> Summary {
        var accelerometerHz: Double?
        var deviceMotionHz = Self.fallbackMotionHz

        switch source {
        case .batched:
            if let batchedManager {
                accelerometerHz = Double(batchedManager.accelerometerDataFrequency)
                deviceMotionHz = Double(batchedManager.deviceMotionDataFrequency)
                batchedManager.stopAccelerometerUpdates()
                batchedManager.stopDeviceMotionUpdates()
            }
            tasks.forEach { $0.cancel() }
            for task in tasks { await task.value }
            tasks = []
        case .motionManager:
            motionManager.stopDeviceMotionUpdates()
            motionQueue.waitUntilAllOperationsAreFinished()
        }

        accelWriter?.close()
        motionWriter.close()

        var files = [SessionFiles.deviceMotion]
        if accelWriter != nil { files.append(SessionFiles.accelerometer) }

        return Summary(
            source: source,
            accelerometerHz: accelerometerHz,
            deviceMotionHz: deviceMotionHz,
            accelerometerSamples: accelWriter?.rowCount ?? 0,
            deviceMotionSamples: motionWriter.rowCount,
            files: files
        )
    }

    private static func write(_ motion: CMDeviceMotion, to writer: CSVWriter, bootEpoch: TimeInterval) {
        let ua = motion.userAcceleration
        let g = motion.gravity
        let r = motion.rotationRate
        let q = motion.attitude.quaternion
        writer.appendRow(time: bootEpoch + motion.timestamp,
                         [ua.x, ua.y, ua.z, g.x, g.y, g.z, r.x, r.y, r.z, q.w, q.x, q.y, q.z])
    }
}
