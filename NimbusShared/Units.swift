import Foundation

public enum TemperatureUnit: String, Codable, CaseIterable, Sendable, Identifiable {
    case celsius
    case fahrenheit

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .celsius: return "Celsius"
        case .fahrenheit: return "Fahrenheit"
        }
    }

    public var symbol: String {
        switch self {
        case .celsius: return "°"
        case .fahrenheit: return "°"
        }
    }

    public var apiValue: String {
        switch self {
        case .celsius: return "celsius"
        case .fahrenheit: return "fahrenheit"
        }
    }

    /// Open-Meteo already converts when requested. This is for local display of cached SI-ish values.
    public func display(_ celsius: Double) -> Double {
        switch self {
        case .celsius: return celsius
        case .fahrenheit: return celsius * 9.0 / 5.0 + 32.0
        }
    }
}

public enum WindSpeedUnit: String, Codable, CaseIterable, Sendable, Identifiable {
    case kilometersPerHour
    case milesPerHour
    case metersPerSecond
    case knots

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .kilometersPerHour: return "km/h"
        case .milesPerHour: return "mph"
        case .metersPerSecond: return "m/s"
        case .knots: return "knots"
        }
    }

    public var apiValue: String {
        switch self {
        case .kilometersPerHour: return "kmh"
        case .milesPerHour: return "mph"
        case .metersPerSecond: return "ms"
        case .knots: return "kn"
        }
    }

    public func displayFromKmh(_ kmh: Double) -> Double {
        switch self {
        case .kilometersPerHour: return kmh
        case .milesPerHour: return kmh * 0.621371
        case .metersPerSecond: return kmh / 3.6
        case .knots: return kmh * 0.539957
        }
    }
}

public enum PrecipitationUnit: String, Codable, CaseIterable, Sendable, Identifiable {
    case millimeter
    case inch

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .millimeter: return "mm"
        case .inch: return "in"
        }
    }

    public var apiValue: String {
        switch self {
        case .millimeter: return "mm"
        case .inch: return "inch"
        }
    }

    public func displayFromMM(_ mm: Double) -> Double {
        switch self {
        case .millimeter: return mm
        case .inch: return mm / 25.4
        }
    }
}

public enum DistanceUnit: String, Codable, CaseIterable, Sendable, Identifiable {
    case kilometer
    case mile

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .kilometer: return "km"
        case .mile: return "mi"
        }
    }
}

public struct UnitPreferences: Codable, Hashable, Sendable {
    public var temperature: TemperatureUnit
    public var wind: WindSpeedUnit
    public var precipitation: PrecipitationUnit
    public var distance: DistanceUnit
    public var followLocale: Bool

    public init(
        temperature: TemperatureUnit = .celsius,
        wind: WindSpeedUnit = .kilometersPerHour,
        precipitation: PrecipitationUnit = .millimeter,
        distance: DistanceUnit = .kilometer,
        followLocale: Bool = true
    ) {
        self.temperature = temperature
        self.wind = wind
        self.precipitation = precipitation
        self.distance = distance
        self.followLocale = followLocale
    }

    /// When follow-locale is on, replace stored units with the locale’s preference.
    enum CodingKeys: String, CodingKey {
        case temperature, wind, precipitation, distance, followLocale
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        temperature = try c.decodeIfPresent(TemperatureUnit.self, forKey: .temperature) ?? .celsius
        wind = try c.decodeIfPresent(WindSpeedUnit.self, forKey: .wind) ?? .kilometersPerHour
        precipitation = try c.decodeIfPresent(PrecipitationUnit.self, forKey: .precipitation) ?? .millimeter
        distance = try c.decodeIfPresent(DistanceUnit.self, forKey: .distance) ?? .kilometer
        followLocale = try c.decodeIfPresent(Bool.self, forKey: .followLocale) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(temperature, forKey: .temperature)
        try c.encode(wind, forKey: .wind)
        try c.encode(precipitation, forKey: .precipitation)
        try c.encode(distance, forKey: .distance)
        try c.encode(followLocale, forKey: .followLocale)
    }

    public func resolved(against locale: Locale = .current) -> UnitPreferences {
        if followLocale { return .fromLocale(locale) }
        return self
    }

    /// Region is only a fallback. Language & Region “Measurement system” wins
    /// (US + Metric must not become mph/in just because the region is US).
    public static func usesImperial(_ locale: Locale) -> Bool {
        usesImperialMeasures(locale.measurementSystem, regionCode: locale.region?.identifier)
    }

    public static func usesImperialMeasures(_ system: Locale.MeasurementSystem, regionCode: String?) -> Bool {
        if system == .metric { return false }
        if system == .us { return true }
        if system == .uk { return false }
        if let regionCode, imperialRegions.contains(regionCode) { return true }
        return false
    }

    public static func fromSignals(_ signals: LocaleUnitSignals) -> UnitPreferences {
        let imperial = usesImperialMeasures(signals.measurement, regionCode: signals.regionCode)
        return UnitPreferences(
            temperature: signals.temperature,
            wind: imperial ? .milesPerHour : .kilometersPerHour,
            precipitation: imperial ? .inch : .millimeter,
            distance: imperial ? .mile : .kilometer,
            followLocale: true
        )
    }

    public static func fromLocale(_ locale: Locale = .current) -> UnitPreferences {
        fromSignals(.from(locale: locale, temperaturePreference: nil))
    }

    /// Follows System Settings → Language & Region, including a US region
    /// with Metric measures and/or Celsius temperature.
    public static func fromSystem(
        locale: Locale = .current,
        temperaturePreference: String? = UserDefaults.standard.string(forKey: "AppleTemperatureUnit")
    ) -> UnitPreferences {
        fromSignals(.from(locale: locale, temperaturePreference: temperaturePreference))
    }

    private static let imperialRegions: Set<String> = ["US", "LR", "MM", "PR", "GU", "VI", "AS", "MP"]
}

public struct LocaleUnitSignals: Equatable, Sendable {
    public var regionCode: String?
    public var measurement: Locale.MeasurementSystem
    public var temperature: TemperatureUnit

    public init(regionCode: String?, measurement: Locale.MeasurementSystem, temperature: TemperatureUnit) {
        self.regionCode = regionCode
        self.measurement = measurement
        self.temperature = temperature
    }

    public static func from(locale: Locale, temperaturePreference: String?) -> LocaleUnitSignals {
        let imperial = UnitPreferences.usesImperialMeasures(locale.measurementSystem, regionCode: locale.region?.identifier)
        let fallbackTemp: TemperatureUnit = imperial ? .fahrenheit : .celsius
        return LocaleUnitSignals(
            regionCode: locale.region?.identifier,
            measurement: locale.measurementSystem,
            temperature: Self.parseTemperature(temperaturePreference) ?? fallbackTemp
        )
    }

    public static func parseTemperature(_ raw: String?) -> TemperatureUnit? {
        guard let raw else { return nil }
        if raw.localizedCaseInsensitiveContains("celsius") { return .celsius }
        if raw.localizedCaseInsensitiveContains("fahrenheit") { return .fahrenheit }
        return nil
    }
}

public enum WeatherFormatting {
    /// `value` is always SI from the API (°C). Convert here for display.
    public static func temperature(_ value: Double?, unit: TemperatureUnit, showUnit: Bool = false) -> String {
        guard let value else { return "—" }
        let rounded = Int(unit.display(value).rounded())
        return showUnit ? "\(rounded)\(unit == .celsius ? "°C" : "°F")" : "\(rounded)°"
    }

    public static func signedTemperature(_ value: Double?, unit: TemperatureUnit) -> String {
        guard let value else { return "—" }
        let rounded = Int(unit.display(value).rounded())
        return "\(rounded)°"
    }

    public static func wind(_ kmh: Double?, unit: WindSpeedUnit) -> String {
        guard let kmh else { return "—" }
        let value = unit.displayFromKmh(kmh)
        if unit == .metersPerSecond {
            return String(format: "%.1f %@", value, unit.title)
        }
        return "\(Int(value.rounded())) \(unit.title)"
    }

    public static func precipitation(_ mm: Double?, unit: PrecipitationUnit) -> String {
        guard let mm else { return "—" }
        let value = unit.displayFromMM(mm)
        if unit == .inch {
            return String(format: "%.2f in", value)
        }
        if value < 0.1 {
            return "0 mm"
        }
        if value < 10 {
            return String(format: "%.1f mm", value)
        }
        return "\(Int(value.rounded())) mm"
    }

    public static func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded()))%"
    }

    public static func pressure(_ hPa: Double?) -> String {
        guard let hPa else { return "—" }
        return "\(Int(hPa.rounded())) hPa"
    }

    public static func visibility(_ meters: Double?, unit: DistanceUnit = .kilometer) -> String {
        guard let meters else { return "—" }
        switch unit {
        case .mile:
            let miles = meters / 1609.344
            if miles < 0.1 { return String(format: "%.0f ft", meters * 3.28084) }
            return String(format: miles >= 10 ? "%.0f mi" : "%.1f mi", miles)
        case .kilometer:
            if meters >= 1000 {
                let km = meters / 1000
                return String(format: km >= 10 ? "%.0f km" : "%.1f km", km)
            }
            return "\(Int(meters.rounded())) m"
        }
    }

    public static func compass(_ degrees: Double?) -> String {
        guard let degrees else { return "—" }
        let dirs = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let idx = Int((degrees.truncatingRemainder(dividingBy: 360) / 22.5).rounded()) % 16
        return dirs[idx]
    }

    public static func relativeUpdated(from date: Date, now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 45 { return "Updated just now" }
        if seconds < 3600 {
            let m = Int(seconds / 60)
            return m <= 1 ? "Updated 1 minute ago" : "Updated \(m) minutes ago"
        }
        if seconds < 86400 {
            let h = Int(seconds / 3600)
            return h == 1 ? "Updated 1 hour ago" : "Updated \(h) hours ago"
        }
        let d = Int(seconds / 86400)
        return d == 1 ? "Updated yesterday" : "Updated \(d) days ago"
    }

    public static func hourLabel(_ date: Date, timeZone: TimeZone, now: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        if calendar.isDate(date, equalTo: now, toGranularity: .hour) {
            return "Now"
        }
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = .current
        formatter.dateFormat = "ha"
        return formatter.string(from: date).lowercased()
    }

    public static func weekday(_ date: Date, timeZone: TimeZone, now: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = .current
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}
