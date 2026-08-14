import Foundation

public struct AppSettings: Hashable, Codable, Sendable {
    public var units: UnitPreferences
    public var appearance: AppearanceMode
    public var followPlaceSun: Bool
    public var menuBarPlaceID: UUID?
    public var selectedPlaceID: UUID?
    public var inspectorVisible: Bool
    public var hasCompletedOnboardingSeed: Bool
    public var language: AppLanguage
    public var motion: MotionPreference

    public init(
        units: UnitPreferences = .fromSystem(),
        appearance: AppearanceMode = .scene,
        followPlaceSun: Bool = true,
        menuBarPlaceID: UUID? = nil,
        selectedPlaceID: UUID? = nil,
        inspectorVisible: Bool = false,
        hasCompletedOnboardingSeed: Bool = false,
        language: AppLanguage = .system,
        motion: MotionPreference = .followSystem
    ) {
        self.units = units
        self.appearance = appearance
        self.followPlaceSun = followPlaceSun
        self.menuBarPlaceID = menuBarPlaceID
        self.selectedPlaceID = selectedPlaceID
        self.inspectorVisible = inspectorVisible
        self.hasCompletedOnboardingSeed = hasCompletedOnboardingSeed
        self.language = language
        self.motion = motion
    }

    public enum AppearanceMode: String, Codable, CaseIterable, Sendable {
        case system
        case light
        case dark
        case scene
    }

    enum CodingKeys: String, CodingKey {
        case units, appearance, followPlaceSun, menuBarPlaceID, selectedPlaceID
        case inspectorVisible, hasCompletedOnboardingSeed, language, motion
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        units = try c.decodeIfPresent(UnitPreferences.self, forKey: .units) ?? .fromLocale()
        appearance = try c.decodeIfPresent(AppearanceMode.self, forKey: .appearance) ?? .scene
        followPlaceSun = try c.decodeIfPresent(Bool.self, forKey: .followPlaceSun) ?? true
        menuBarPlaceID = try c.decodeIfPresent(UUID.self, forKey: .menuBarPlaceID)
        selectedPlaceID = try c.decodeIfPresent(UUID.self, forKey: .selectedPlaceID)
        inspectorVisible = try c.decodeIfPresent(Bool.self, forKey: .inspectorVisible) ?? false
        hasCompletedOnboardingSeed = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboardingSeed) ?? false
        language = try c.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .system
        motion = try c.decodeIfPresent(MotionPreference.self, forKey: .motion) ?? .followSystem
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(units, forKey: .units)
        try c.encode(appearance, forKey: .appearance)
        try c.encode(followPlaceSun, forKey: .followPlaceSun)
        try c.encodeIfPresent(menuBarPlaceID, forKey: .menuBarPlaceID)
        try c.encodeIfPresent(selectedPlaceID, forKey: .selectedPlaceID)
        try c.encode(inspectorVisible, forKey: .inspectorVisible)
        try c.encode(hasCompletedOnboardingSeed, forKey: .hasCompletedOnboardingSeed)
        try c.encode(language, forKey: .language)
        try c.encode(motion, forKey: .motion)
    }
}

public enum AppGroup {
    public static let identifier = "group.app.nimbus.mac"
    public static let suiteName = identifier

    public static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return url
        }
        let fallback = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Nimbus", isDirectory: true)
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }
}

public actor WeatherStore {
    private let fileManager: FileManager
    private let root: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(root: URL = AppGroup.containerURL) {
        self.fileManager = .default
        self.root = root
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        try? fileManager.createDirectory(at: root.appendingPathComponent("snapshots"), withIntermediateDirectories: true)
        Self.migrateCacheIfNeeded(root: root, fileManager: fileManager)
    }

    /// Snapshots are SI (°C, km/h, mm). Generation 1 stored API-converted imperial.
    private static let cacheGeneration = "2"

    private static func migrateCacheIfNeeded(root: URL, fileManager: FileManager) {
        let marker = root.appendingPathComponent("cache-generation.txt")
        let existing = (try? String(contentsOf: marker, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard existing != cacheGeneration else { return }
        try? fileManager.removeItem(at: root.appendingPathComponent("snapshots"))
        try? fileManager.createDirectory(at: root.appendingPathComponent("snapshots"), withIntermediateDirectories: true)
        try? cacheGeneration.write(to: marker, atomically: true, encoding: .utf8)
    }

    private var placesURL: URL { root.appendingPathComponent("places.json") }
    private var settingsURL: URL { root.appendingPathComponent("settings.json") }
    private func snapshotURL(for id: UUID) -> URL {
        root.appendingPathComponent("snapshots/\(id.uuidString).json")
    }

    public func loadPlaces() -> [Place] {
        guard let data = try? Data(contentsOf: placesURL),
              let places = try? decoder.decode([Place].self, from: data),
              !places.isEmpty
        else {
            return PopularCities.defaultPlaces()
        }
        return places.sorted { $0.sortIndex < $1.sortIndex }
    }

    public func savePlaces(_ places: [Place]) {
        guard let data = try? encoder.encode(places) else { return }
        try? data.write(to: placesURL, options: .atomic)
    }

    public func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? decoder.decode(AppSettings.self, from: data)
        else {
            return AppSettings()
        }
        return settings
    }

    public func saveSettings(_ settings: AppSettings) {
        guard let data = try? encoder.encode(settings) else { return }
        try? data.write(to: settingsURL, options: .atomic)
    }

    public func loadSnapshot(id: UUID) -> WeatherSnapshot? {
        guard let data = try? Data(contentsOf: snapshotURL(for: id)) else { return nil }
        return try? decoder.decode(WeatherSnapshot.self, from: data)
    }

    public func saveSnapshot(_ snapshot: WeatherSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: snapshotURL(for: snapshot.place.id), options: .atomic)
    }

    public func latestSnapshot() -> WeatherSnapshot? {
        let dir = root.appendingPathComponent("snapshots")
        guard let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return nil
        }
        let newest = files
            .filter { $0.pathExtension == "json" }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return da > db
            }
            .first
        guard let newest, let data = try? Data(contentsOf: newest) else { return nil }
        return try? decoder.decode(WeatherSnapshot.self, from: newest == newest ? data : data)
    }
}
