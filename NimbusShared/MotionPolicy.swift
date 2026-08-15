import Foundation

public enum MotionPreference: String, Codable, CaseIterable, Sendable, Identifiable {
    case followSystem
    case always
    case never

    public var id: String { rawValue }

    public var localizationKey: String {
        switch self {
        case .followSystem: return "motion_system"
        case .always: return "motion_always"
        case .never: return "motion_never"
        }
    }
}

/// Single policy used by the scene compositor and by tests.
public enum MotionPolicy {
    /// Looping particles, lightning pulses, and drifting decks.
    public static func allowsDynamicMotion(systemReduceMotion: Bool, preference: MotionPreference) -> Bool {
        switch preference {
        case .always: return true
        case .never: return false
        case .followSystem: return !systemReduceMotion
        }
    }

    public static func allowsParticles(systemReduceMotion: Bool, preference: MotionPreference) -> Bool {
        allowsDynamicMotion(systemReduceMotion: systemReduceMotion, preference: preference)
    }

    public static func allowsLightning(systemReduceMotion: Bool, preference: MotionPreference) -> Bool {
        allowsDynamicMotion(systemReduceMotion: systemReduceMotion, preference: preference)
    }

    /// Living sky only while the window is in front and no modal card is up.
    public static func shouldAnimateScene(
        windowActive: Bool,
        overlayPresented: Bool,
        systemReduceMotion: Bool,
        preference: MotionPreference
    ) -> Bool {
        guard windowActive, !overlayPresented else { return false }
        return allowsDynamicMotion(systemReduceMotion: systemReduceMotion, preference: preference)
    }

    /// Reduce Transparency and Increase Contrast both ask for heavier, more opaque surfaces.
    public static func prefersSolidSurfaces(reduceTransparency: Bool, increaseContrast: Bool) -> Bool {
        reduceTransparency || increaseContrast
    }
}
