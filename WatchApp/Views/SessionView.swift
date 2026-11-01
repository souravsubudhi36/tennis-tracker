import SwiftUI

struct SessionView: View {
    @EnvironmentObject private var workout: WorkoutManager
    @State private var confirmingEnd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(elapsed(at: context.date))
                    .font(.system(.title, design: .rounded).monospacedDigit())
                    .foregroundStyle(.yellow)
            }

            Label(workout.heartRate.map { "\(Int($0)) bpm" } ?? "-- bpm", systemImage: "heart.fill")
                .foregroundStyle(.red)
            Label(workout.activeEnergy.map { "\(Int($0)) kcal" } ?? "-- kcal", systemImage: "flame.fill")
                .foregroundStyle(.orange)

            Label(statusText, systemImage: "waveform")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Button(role: .destructive) {
                confirmingEnd = true
            } label: {
                Text(workout.state == .ending ? "Saving…" : "End")
                    .frame(maxWidth: .infinity)
            }
            .disabled(workout.state != .running)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog("End this session?", isPresented: $confirmingEnd) {
            Button("End session", role: .destructive) { workout.end() }
        }
    }

    private var statusText: String {
        switch workout.state {
        case .starting: "Starting…"
        case .ending: "Saving recording…"
        default: "Recording motion"
        }
    }

    private func elapsed(at date: Date) -> String {
        let seconds = workout.startDate.map { max(0, date.timeIntervalSince($0)) } ?? 0
        return Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond))
    }
}
