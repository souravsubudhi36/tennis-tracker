import Foundation

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profile: PlayerProfile?
    @Published private(set) var placement: WatchPlacement?

    private static let profileKey = "profile"
    private static let placementKey = "watchPlacement"

    init() {
        profile = Self.load(PlayerProfile.self, key: Self.profileKey)
        placement = Self.load(WatchPlacement.self, key: Self.placementKey)
    }

    func save(_ profile: PlayerProfile) {
        self.profile = profile
        Self.store(profile, key: Self.profileKey)
        PhoneConnectivity.shared.send(profile: profile)
    }

    func updatePlacement(_ placement: WatchPlacement) {
        self.placement = placement
        Self.store(placement, key: Self.placementKey)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder.tennis.decode(type, from: data)
    }

    private static func store<T: Encodable>(_ value: T, key: String) {
        UserDefaults.standard.set(try? JSONEncoder.tennis.encode(value), forKey: key)
    }
}
