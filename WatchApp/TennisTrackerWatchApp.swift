import SwiftUI

@main
struct TennisTrackerWatchApp: App {
    @StateObject private var workout = WorkoutManager()
    @StateObject private var connectivity = WatchConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                RootView()
            }
            .environmentObject(workout)
            .environmentObject(connectivity)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var workout: WorkoutManager

    var body: some View {
        switch workout.state {
        case .idle:
            StartView()
        case .starting, .running, .ending:
            SessionView()
        }
    }
}
