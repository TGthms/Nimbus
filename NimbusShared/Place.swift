import Foundation

public struct Place: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var admin1: String?
    public var country: String?
    public var latitude: Double
    public var longitude: Double
    public var timezone: String?
    public var isCurrentLocation: Bool
    public var isPopularSeed: Bool
    public var sortIndex: Int

    public init(
        id: UUID = UUID(),
        name: String,
        admin1: String? = nil,
        country: String? = nil,
        latitude: Double,
        longitude: Double,
        timezone: String? = nil,
        isCurrentLocation: Bool = false,
        isPopularSeed: Bool = false,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.admin1 = admin1
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.timezone = timezone
        self.isCurrentLocation = isCurrentLocation
        self.isPopularSeed = isPopularSeed
        self.sortIndex = sortIndex
    }

    public var subtitle: String {
        [admin1, country].compactMap { $0 }.filter { !$0.isEmpty && $0 != name }.joined(separator: ", ")
    }

    public var displayName: String {
        isCurrentLocation ? "My Location" : name
    }

    public var coordinateKey: String {
        String(format: "%.4f,%.4f", latitude, longitude)
    }
}

public enum PopularCities {
    public static let myLocation = Place(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "My Location",
        latitude: 0,
        longitude: 0,
        isCurrentLocation: true,
        sortIndex: 0
    )

    /// Curated world cities shown on first launch. Users can remove any of them
    /// and add any other place via search.
    public static let seeds: [Place] = [
        Place(id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!, name: "New York", admin1: "New York", country: "United States", latitude: 40.7128, longitude: -74.0060, timezone: "America/New_York", isPopularSeed: true, sortIndex: 1),
        Place(id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!, name: "London", admin1: "England", country: "United Kingdom", latitude: 51.5074, longitude: -0.1278, timezone: "Europe/London", isPopularSeed: true, sortIndex: 2),
        Place(id: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!, name: "Tokyo", admin1: "Tokyo", country: "Japan", latitude: 35.6895, longitude: 139.6917, timezone: "Asia/Tokyo", isPopularSeed: true, sortIndex: 3),
        Place(id: UUID(uuidString: "00000000-0000-0000-0000-000000000104")!, name: "Paris", admin1: "Île-de-France", country: "France", latitude: 48.8566, longitude: 2.3522, timezone: "Europe/Paris", isPopularSeed: true, sortIndex: 4),
        Place(id: UUID(uuidString: "00000000-0000-0000-0000-000000000105")!, name: "Los Angeles", admin1: "California", country: "United States", latitude: 34.0522, longitude: -118.2437, timezone: "America/Los_Angeles", isPopularSeed: true, sortIndex: 5),
        Place(id: UUID(uuidString: "00000000-0000-0000-0000-000000000106")!, name: "Hong Kong", country: "Hong Kong", latitude: 22.3193, longitude: 114.1694, timezone: "Asia/Hong_Kong", isPopularSeed: true, sortIndex: 6),
        Place(id: UUID(uuidString: "00000000-0000-0000-0000-000000000107")!, name: "Sydney", admin1: "New South Wales", country: "Australia", latitude: -33.8688, longitude: 151.2093, timezone: "Australia/Sydney", isPopularSeed: true, sortIndex: 7),
        Place(id: UUID(uuidString: "00000000-0000-0000-0000-000000000108")!, name: "Singapore", country: "Singapore", latitude: 1.3521, longitude: 103.8198, timezone: "Asia/Singapore", isPopularSeed: true, sortIndex: 8),
        Place(id: UUID(uuidString: "00000000-0000-0000-0000-000000000109")!, name: "San Francisco", admin1: "California", country: "United States", latitude: 37.7749, longitude: -122.4194, timezone: "America/Los_Angeles", isPopularSeed: true, sortIndex: 9),
        Place(id: UUID(uuidString: "00000000-0000-0000-0000-000000000110")!, name: "Berlin", admin1: "Berlin", country: "Germany", latitude: 52.5200, longitude: 13.4050, timezone: "Europe/Berlin", isPopularSeed: true, sortIndex: 10),
        Place(id: UUID(uuidString: "00000000-0000-0000-0000-000000000111")!, name: "Toronto", admin1: "Ontario", country: "Canada", latitude: 43.6532, longitude: -79.3832, timezone: "America/Toronto", isPopularSeed: true, sortIndex: 11),
        Place(id: UUID(uuidString: "00000000-0000-0000-0000-000000000112")!, name: "Dubai", admin1: "Dubai", country: "United Arab Emirates", latitude: 25.2048, longitude: 55.2708, timezone: "Asia/Dubai", isPopularSeed: true, sortIndex: 12)
    ]

    public static func defaultPlaces() -> [Place] {
        [myLocation] + seeds
    }

    public static func matching(_ query: String) -> [Place] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return seeds }
        return seeds.filter {
            $0.name.lowercased().contains(q)
                || ($0.admin1?.lowercased().contains(q) ?? false)
                || ($0.country?.lowercased().contains(q) ?? false)
        }
    }
}
