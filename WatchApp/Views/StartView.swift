import SwiftUI

struct StartView: View {
    @EnvironmentObject private var workout: WorkoutManager
    @EnvironmentObject private var connectivity: WatchConnectivityManager

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ProfileSummary(profile: connectivity.profile, placement: connectivity.currentPlacement)

                Button {
                    start(indoor: false)
                } label: {
                    Label("Outdoor court", systemImage: "sun.max.fill")
                }
                .tint(.green)

                Button {
                    start(indoor: true)
                } label: {
                    Label("Indoor court", systemImage: "building.2.fill")
                }
                .tint(.blue)

                if let error = workout.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if let last = workout.lastSession {
                    LastSessionSummary(session: last, pendingTransfers: connectivity.pendingTransfers)
                }
            }
        }
        .navigationTitle("Tennis")
    }

    private func start(indoor: Bool) {
        Task {
            await workout.start(indoor: indoor,
                                profile: connectivity.profile,
                                placement: connectivity.currentPlacement)
        }
    }
}

private struct ProfileSummary: View {
    let profile: PlayerProfile?
    let placement: WatchPlacement

    var body: some View {
        if let profile {
            let quality = profile.expectedQuality(with: placement)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(profile.playingHand.label)-handed · \(profile.backhand.label) BH")
                    .font(.footnote)
                Text("Watch on \(placement.wrist.label.lowercased()) wrist · \(quality.label) accuracy")
                    .font(.caption2)
                    .foregroundStyle(quality == .high ? .green : .orange)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("Set up your profile in the iPhone app so we know your forehand side.")
                .font(.footnote)
                .foregroundStyle(.orange)
        }
    }
}

private struct LastSessionSummary: View {
    let session: SessionMetadata
    let pendingTransfers: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Last session")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(Duration.seconds(session.duration).formatted(.time(pattern: .hourMinuteSecond)))
                .font(.headline.monospacedDigit())
            Text(pendingTransfers > 0 ? "Sending to iPhone (\(pendingTransfers) files left)" : "Sent to iPhone")
                .font(.caption2)
                .foregroundStyle(pendingTransfers > 0 ? .yellow : .green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }
}
