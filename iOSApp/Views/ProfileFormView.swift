import SwiftUI

/// Sign-up questions, also used later to edit the profile.
struct ProfileFormView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss

    let isOnboarding: Bool

    @State private var playingHand: Hand = .right
    @State private var backhand: BackhandStyle = .twoHanded

    var body: some View {
        Form {
            Section {
                Picker("Forehand hand", selection: $playingHand) {
                    ForEach(Hand.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Which hand do you play with?")
            } footer: {
                Text("The hand that holds the racket on your forehand.")
            }

            Section("Your backhand") {
                Picker("Backhand", selection: $backhand) {
                    ForEach(BackhandStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section {
                if let placement = profileStore.placement {
                    LabeledContent("Worn on", value: "\(placement.wrist.label) wrist")
                    LabeledContent("Digital Crown", value: "On the \(placement.crown.label.lowercased())")
                } else {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Open TennisTracker on your Apple Watch so we can see which wrist it's on.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Apple Watch")
            } footer: {
                Text("Read from your watch settings. To change it, open the Watch app on iPhone › General › Watch Orientation.")
            }

            if let placement = profileStore.placement {
                let quality = PlayerProfile(playingHand: playingHand, backhand: backhand).expectedQuality(with: placement)
                Section("Expected stroke detection") {
                    QualityBadge(quality: quality)
                    Text(quality.explanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(isOnboarding ? "Your game" : "Profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isOnboarding ? "Continue" : "Save") {
                    profileStore.save(PlayerProfile(playingHand: playingHand, backhand: backhand))
                    if !isOnboarding { dismiss() }
                }
            }
            if !isOnboarding {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            if let profile = profileStore.profile {
                playingHand = profile.playingHand
                backhand = profile.backhand
            }
        }
    }
}

struct QualityBadge: View {
    let quality: DetectionQuality

    var body: some View {
        Label("\(quality.label) accuracy", systemImage: "scope")
            .font(.headline)
            .foregroundStyle(color)
    }

    private var color: Color {
        switch quality {
        case .high: .green
        case .medium: .orange
        case .low: .red
        }
    }
}
