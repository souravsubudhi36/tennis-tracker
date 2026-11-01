import Foundation

enum Hand: String, Codable, CaseIterable, Identifiable {
    case left, right

    var id: String { rawValue }
    var label: String { self == .left ? "Left" : "Right" }
}

enum BackhandStyle: String, Codable, CaseIterable, Identifiable {
    case oneHanded, twoHanded

    var id: String { rawValue }
    var label: String { self == .oneHanded ? "One-handed" : "Two-handed" }
}

/// What the player tells us at sign-up.
struct PlayerProfile: Codable, Equatable {
    /// The hand that holds the racket on a forehand.
    var playingHand: Hand
    var backhand: BackhandStyle
}

/// Where the watch is worn. Read from the watch's own settings, never asked.
struct WatchPlacement: Codable, Equatable {
    var wrist: Hand
    /// Side the Digital Crown is on, from the wearer's point of view.
    var crown: Hand
}

enum DetectionQuality: String, Codable {
    case high, medium, low

    var label: String {
        switch self {
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        }
    }

    var explanation: String {
        switch self {
        case .high:
            "Your watch is on your hitting arm, so forehands and backhands produce clear, opposite rotations."
        case .medium:
            "Your watch is on your other arm. Your two-handed backhand still moves it strongly, but forehands give a weaker signal. For best results, wear the watch on your hitting wrist when you play."
        case .low:
            "Your watch is on your other arm and a one-handed backhand barely moves it, so backhands will often be missed. Wear the watch on your hitting wrist when you play."
        }
    }
}

extension PlayerProfile {
    func expectedQuality(with placement: WatchPlacement) -> DetectionQuality {
        if placement.wrist == playingHand { return .high }
        return backhand == .twoHanded ? .medium : .low
    }
}
