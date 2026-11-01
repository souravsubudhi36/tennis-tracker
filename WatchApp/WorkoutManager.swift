import Foundation
import HealthKit
import WatchKit

/// Runs the HealthKit tennis workout (which keeps the app alive with the wrist down)
/// and the sensor recording that goes with it.
@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    enum State: Equatable { case idle, starting, running, ending }

    @Published private(set) var state: State = .idle
    @Published private(set) var startDate: Date?
    @Published private(set) var heartRate: Double?
    @Published private(set) var activeEnergy: Double?
    @Published private(set) var lastSession: SessionMetadata?
    @Published var errorMessage: String?

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var recorder: SensorRecorder?
    private var averageHeartRate: Double?
    private var pending: (id: UUID, indoor: Bool, profile: PlayerProfile?, placement: WatchPlacement)?

    func start(indoor: Bool, profile: PlayerProfile?, placement: WatchPlacement) async {
        guard state == .idle else { return }
        state = .starting
        errorMessage = nil
        heartRate = nil
        activeEnergy = nil
        averageHeartRate = nil

        let id = UUID()
        do {
            try await requestAuthorization()

            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .tennis
            configuration.locationType = indoor ? .indoor : .outdoor

            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self

            recorder = try SensorRecorder(directory: SessionFiles.directory(for: id))
            pending = (id, indoor, profile, placement)
            workoutSession = session
            self.builder = builder

            let start = Date()
            startDate = start
            // The recorder starts when the session reports .running (see delegate).
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)
        } catch {
            errorMessage = "Couldn't start: \(error.localizedDescription)"
            if let recorder { _ = await recorder.stop() }
            workoutSession?.end()
            try? FileManager.default.removeItem(at: SessionFiles.directory(for: id))
            reset()
        }
    }

    func end() {
        guard state == .running || state == .starting else { return }
        state = .ending
        workoutSession?.end()
    }

    private func requestAuthorization() async throws {
        let share: Set<HKSampleType> = [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned)]
        let read: Set<HKObjectType> = [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]
        try await healthStore.requestAuthorization(toShare: share, read: read)
    }

    private func finish(at endDate: Date) async {
        guard let recorder, let pending, let startDate else {
            reset()
            return
        }
        let summary = await recorder.stop()

        do {
            try await builder?.endCollection(at: endDate)
            _ = try await builder?.finishWorkout()
        } catch {
            // The motion recording is still good even if Health didn't save the workout.
            errorMessage = "Workout not saved to Health: \(error.localizedDescription)"
        }

        let device = WKInterfaceDevice.current()
        let metadata = SessionMetadata(
            id: pending.id,
            startDate: startDate,
            endDate: endDate,
            indoor: pending.indoor,
            profile: pending.profile,
            placement: pending.placement,
            sensorSource: summary.source,
            accelerometerHz: summary.accelerometerHz,
            deviceMotionHz: summary.deviceMotionHz,
            accelerometerSamples: summary.accelerometerSamples,
            deviceMotionSamples: summary.deviceMotionSamples,
            averageHeartRate: averageHeartRate,
            activeEnergyKcal: activeEnergy,
            watchModel: Self.hardwareModel,
            watchOSVersion: device.systemVersion,
            files: summary.files + [SessionFiles.metadata]
        )

        do {
            let data = try JSONEncoder.tennis.encode(metadata)
            try data.write(to: recorder.directory.appendingPathComponent(SessionFiles.metadata))
            FileManager.default.createFile(
                atPath: recorder.directory.appendingPathComponent(SessionFiles.readyMarker).path, contents: nil)
            WatchConnectivityManager.shared.sendFinishedSessions()
            lastSession = metadata
        } catch {
            errorMessage = "Couldn't save session: \(error.localizedDescription)"
        }
        reset()
    }

    private func reset() {
        state = .idle
        workoutSession = nil
        builder = nil
        recorder = nil
        pending = nil
        startDate = nil
    }

    private static var hardwareModel: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { buffer in
            String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState,
                                    date: Date) {
        Task { @MainActor in
            switch toState {
            case .running:
                self.recorder?.start()
                if self.state == .starting { self.state = .running }
            case .ended:
                await self.finish(at: date)
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
            self.end()
        }
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let heartRateStats = workoutBuilder.statistics(for: HKQuantityType(.heartRate))
        let current = heartRateStats?.mostRecentQuantity()?.doubleValue(for: bpm)
        let average = heartRateStats?.averageQuantity()?.doubleValue(for: bpm)
        let energy = workoutBuilder.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie())

        Task { @MainActor in
            if let current { self.heartRate = current }
            if let average { self.averageHeartRate = average }
            if let energy { self.activeEnergy = energy }
        }
    }
}
