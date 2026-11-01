import SwiftUI

@main
struct TennisTrackerApp: App {
    @StateObject private var profileStore: ProfileStore
    @StateObject private var sessionStore: SessionStore

    init() {
        let profiles = ProfileStore()
        let sessions = SessionStore()

        let connectivity = PhoneConnectivity.shared
        connectivity.onPlacement = { placement in
            MainActor.assumeIsolated { profiles.updatePlacement(placement) }
        }
        connectivity.onFileReceived = {
            MainActor.assumeIsolated { sessions.reload() }
        }
        connectivity.activate(profile: profiles.profile)

        _profileStore = StateObject(wrappedValue: profiles)
        _sessionStore = StateObject(wrappedValue: sessions)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(profileStore)
                .environmentObject(sessionStore)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var profileStore: ProfileStore

    var body: some View {
        if profileStore.profile == nil {
            NavigationStack {
                ProfileFormView(isOnboarding: true)
            }
        } else {
            SessionListView()
        }
    }
}
