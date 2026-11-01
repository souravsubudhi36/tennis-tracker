import SwiftUI

struct SessionListView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var showingProfile = false

    var body: some View {
        NavigationStack {
            Group {
                if sessionStore.sessions.isEmpty {
                    ContentUnavailableView(
                        "No sessions yet",
                        systemImage: "applewatch",
                        description: Text("Start a session in TennisTracker on your Apple Watch. When you end it, the recording is sent here.")
                    )
                } else {
                    List {
                        ForEach(sessionStore.sessions) { entry in
                            NavigationLink(value: entry.id) {
                                SessionRow(entry: entry)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { sessionStore.sessions[$0] }.forEach(sessionStore.delete)
                        }
                    }
                    .refreshable { sessionStore.reload() }
                }
            }
            .navigationTitle("Sessions")
            .navigationDestination(for: UUID.self) { id in
                if let entry = sessionStore.sessions.first(where: { $0.id == id }) {
                    SessionDetailView(entry: entry)
                }
            }
            .toolbar {
                Button {
                    showingProfile = true
                } label: {
                    Image(systemName: "person.crop.circle")
                }
            }
            .sheet(isPresented: $showingProfile) {
                NavigationStack {
                    ProfileFormView(isOnboarding: false)
                }
            }
        }
    }
}

private struct SessionRow: View {
    let entry: SessionStore.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.metadata.startDate.formatted(.dateTime.weekday(.wide).day().month().hour().minute()))
                .font(.headline)
            HStack {
                Text(formatDuration(entry.metadata.duration))
                Text(entry.metadata.indoor ? "Indoor" : "Outdoor")
                if !entry.missingFiles.isEmpty {
                    Text("Receiving \(entry.receivedFiles.count)/\(entry.metadata.files.count) files")
                        .foregroundStyle(.orange)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}

func formatDuration(_ seconds: TimeInterval) -> String {
    Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond))
}
