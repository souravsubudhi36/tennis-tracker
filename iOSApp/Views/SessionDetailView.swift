import SwiftUI

struct SessionDetailView: View {
    let entry: SessionStore.Entry

    private var metadata: SessionMetadata { entry.metadata }

    var body: some View {
        List {
            Section("Session") {
                LabeledContent("Duration", value: formatDuration(metadata.duration))
                LabeledContent("Court", value: metadata.indoor ? "Indoor" : "Outdoor")
                LabeledContent("Avg heart rate", value: metadata.averageHeartRate.map { "\(Int($0)) bpm" } ?? "–")
                LabeledContent("Active energy", value: metadata.activeEnergyKcal.map { "\(Int($0)) kcal" } ?? "–")
            }

            Section("Player setup") {
                if let profile = metadata.profile {
                    LabeledContent("Plays with", value: "\(profile.playingHand.label) hand")
                    LabeledContent("Backhand", value: profile.backhand.label)
                    QualityBadge(quality: profile.expectedQuality(with: metadata.placement))
                } else {
                    Text("No profile was set when this was recorded.")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Watch wrist", value: metadata.placement.wrist.label)
                LabeledContent("Digital Crown", value: metadata.placement.crown.label)
            }

            Section {
                LabeledContent("Started at") {
                    Text(metadata.startDate.formatted(
                        .dateTime.hour().minute().second().secondFraction(.fractional(3))))
                        .monospacedDigit()
                }
                LabeledContent("Unix start time") {
                    Text(String(format: "%.3f", metadata.startDate.timeIntervalSince1970))
                        .monospacedDigit()
                        .textSelection(.enabled)
                }
            } header: {
                Text("Video sync")
            } footer: {
                Text("Every sample in the CSVs has a Unix timestamp (column t). Use the start time to line the recording up with a video of the session.")
            }

            Section("Recording") {
                LabeledContent("Watch", value: "\(metadata.watchModel) · watchOS \(metadata.watchOSVersion)")
                LabeledContent("Sensors", value: metadata.sensorSource == .batched ? "High-rate (batched)" : "Standard")
                LabeledContent("Device motion", value: "\(metadata.deviceMotionSamples.formatted()) samples @ \(Int(metadata.deviceMotionHz)) Hz")
                if let hz = metadata.accelerometerHz {
                    LabeledContent("Accelerometer", value: "\(metadata.accelerometerSamples.formatted()) samples @ \(Int(hz)) Hz")
                }
            }

            Section {
                ForEach(entry.fileURLs, id: \.self) { url in
                    ShareLink(item: url) {
                        LabeledContent(url.lastPathComponent, value: fileSize(url))
                    }
                }
                ForEach(entry.missingFiles, id: \.self) { name in
                    LabeledContent(name, value: "Waiting for watch…")
                        .foregroundStyle(.secondary)
                }
                if entry.fileURLs.count > 1 {
                    ShareLink(items: entry.fileURLs) {
                        Label("Export all files", systemImage: "square.and.arrow.up")
                    }
                }
            } header: {
                Text("Files")
            } footer: {
                Text("AirDrop these to your Mac to inspect or label them.")
            }
        }
        .navigationTitle(metadata.startDate.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func fileSize(_ url: URL) -> String {
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
