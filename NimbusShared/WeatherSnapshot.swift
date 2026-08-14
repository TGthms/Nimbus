import Foundation

public struct CurrentWeather: Hashable, Codable, Sendable {
    public var time: Date
    public var temperature: Double?
    public var apparentTemperature: Double?
    public var humidity: Double?
    public var dewPoint: Double?
    public var isDay: Bool
    public var precipitation: Double?
    public var rain: Double?
    public var showers: Double?
    public var snowfall: Double?
    public var weatherCode: Int
    public var cloudCover: Double?
    public var cloudCoverLow: Double?
    public var cloudCoverMid: Double?
    public var cloudCoverHigh: Double?
    public var pressureMSL: Double?
    public var surfacePressure: Double?
    public var windSpeed: Double?
    public var windDirection: Double?
    public var windGusts: Double?
    public var visibility: Double?
    public var uvIndex: Double?
    public var cape: Double?
    public var liftedIndex: Double?
    public var convectiveInhibition: Double?
    public var freezingLevelHeight: Double?
    public var boundaryLayerHeight: Double?
    public var vapourPressureDeficit: Double?
    public var shortwaveRadiation: Double?

    public var condition: WeatherCondition { WeatherCondition(wmoCode: weatherCode) }
}

public struct HourlyWeather: Identifiable, Hashable, Codable, Sendable {
    public var time: Date
    public var temperature: Double?
    public var apparentTemperature: Double?
    public var humidity: Double?
    public var dewPoint: Double?
    public var precipitationProbability: Double?
    public var precipitation: Double?
    public var rain: Double?
    public var showers: Double?
    public var snowfall: Double?
    public var weatherCode: Int
    public var pressureMSL: Double?
    public var cloudCover: Double?
    public var cloudCoverLow: Double?
    public var cloudCoverMid: Double?
    public var cloudCoverHigh: Double?
    public var visibility: Double?
    public var windSpeed: Double?
    public var windDirection: Double?
    public var windGusts: Double?
    public var uvIndex: Double?
    public var isDay: Bool
    public var cape: Double?
    public var liftedIndex: Double?
    public var convectiveInhibition: Double?
    public var freezingLevelHeight: Double?
    public var boundaryLayerHeight: Double?
    public var shortwaveRadiation: Double?
    public var directRadiation: Double?
    public var diffuseRadiation: Double?
    public var sunshineDuration: Double?
    public var temperature1000hPa: Double?
    public var temperature925hPa: Double?
    public var temperature850hPa: Double?
    public var temperature700hPa: Double?
    public var temperature500hPa: Double?
    public var temperature300hPa: Double?
    public var humidity1000hPa: Double?
    public var humidity925hPa: Double?
    public var humidity850hPa: Double?
    public var humidity700hPa: Double?
    public var humidity500hPa: Double?
    public var humidity300hPa: Double?
    public var windSpeed1000hPa: Double?
    public var windSpeed850hPa: Double?
    public var windSpeed700hPa: Double?
    public var windSpeed500hPa: Double?
    public var windDirection1000hPa: Double?
    public var windDirection850hPa: Double?
    public var windDirection700hPa: Double?
    public var windDirection500hPa: Double?

    public var id: Date { time }
    public var condition: WeatherCondition { WeatherCondition(wmoCode: weatherCode) }
}

public struct DailyWeather: Identifiable, Hashable, Codable, Sendable {
    public var date: Date
    public var weatherCode: Int
    public var temperatureMax: Double?
    public var temperatureMin: Double?
    public var apparentMax: Double?
    public var apparentMin: Double?
    public var sunrise: Date?
    public var sunset: Date?
    public var daylightDuration: Double?
    public var sunshineDuration: Double?
    public var uvIndexMax: Double?
    public var precipitationSum: Double?
    public var precipitationHours: Double?
    public var precipitationProbabilityMax: Double?
    public var rainSum: Double?
    public var showersSum: Double?
    public var snowfallSum: Double?
    public var windSpeedMax: Double?
    public var windGustsMax: Double?
    public var windDirectionDominant: Double?
    public var shortwaveRadiationSum: Double?
    public var moonrise: Date?
    public var moonset: Date?
    public var moonPhase: Double?

    public var id: Date { date }
    public var condition: WeatherCondition { WeatherCondition(wmoCode: weatherCode) }
}

public struct AirQualitySnapshot: Hashable, Codable, Sendable {
    public var time: Date
    public var usAQI: Double?
    public var europeanAQI: Double?
    public var pm25: Double?
    public var pm10: Double?
    public var carbonMonoxide: Double?
    public var nitrogenDioxide: Double?
    public var sulphurDioxide: Double?
    public var ozone: Double?
    public var alderPollen: Double?
    public var birchPollen: Double?
    public var grassPollen: Double?
    public var mugwortPollen: Double?
    public var olivePollen: Double?
    public var ragweedPollen: Double?
    public var hourlyAQI: [Date: Double]

    public var category: AQICategory {
        AQICategory(usAQI: usAQI ?? europeanAQI ?? 0)
    }

    public var hasPollen: Bool {
        [alderPollen, birchPollen, grassPollen, mugwortPollen, olivePollen, ragweedPollen]
            .contains { ($0 ?? 0) > 0 }
    }

    public var dominantPollutant: String {
        // Normalize against a typical “moderate” breakpoint so µg/m³ CO
        // cannot outrank actual criteria pollutants by raw magnitude.
        let scores: [(String, Double)] = [
            ("PM2.5", (pm25 ?? 0) / 35.4),
            ("PM10", (pm10 ?? 0) / 154.0),
            ("O₃", (ozone ?? 0) / 120.0),
            ("NO₂", (nitrogenDioxide ?? 0) / 100.0),
            ("SO₂", (sulphurDioxide ?? 0) / 75.0),
            ("CO", (carbonMonoxide ?? 0) / 10_000.0)
        ]
        return scores.max(by: { $0.1 < $1.1 })?.0 ?? "—"
    }
}

public struct SceneRecipe: Hashable, Codable, Sendable {
    public var condition: WeatherCondition
    public var isDay: Bool
    public var cloudCover: Double
    public var cloudLow: Double
    public var cloudMid: Double
    public var cloudHigh: Double
    public var precipRate: Double
    public var isSnow: Bool
    public var windSpeed: Double
    public var windDirection: Double
    public var visibility: Double
    public var lightning: Bool
    public var solarElevation: Double
    public var moonIllumination: Double
    public var aqiHaze: Double

    public static func from(current: CurrentWeather, place: Place, date: Date = Date(), aqi: Double? = nil) -> SceneRecipe {
        let elev = SolarMath.solarElevation(latitude: place.latitude, longitude: place.longitude, date: date)
        let moon = MoonMath.phase(on: date)
        let precip = current.precipitation ?? 0
        let codeIntensity = current.condition.precipIntensity
        return SceneRecipe(
            condition: current.condition,
            isDay: current.isDay,
            cloudCover: (current.cloudCover ?? current.condition.cloudBias * 100) / 100,
            cloudLow: (current.cloudCoverLow ?? current.cloudCover ?? 0) / 100,
            cloudMid: (current.cloudCoverMid ?? 0) / 100,
            cloudHigh: (current.cloudCoverHigh ?? 0) / 100,
            precipRate: max(precip, codeIntensity * 2),
            isSnow: current.condition.isSnow || (current.snowfall ?? 0) > 0.05,
            windSpeed: current.windSpeed ?? 0,
            windDirection: current.windDirection ?? 0,
            visibility: current.visibility ?? 20000,
            lightning: current.condition.isThunder,
            solarElevation: elev,
            moonIllumination: moon.illumination,
            aqiHaze: min(1, max(0, ((aqi ?? 0) - 60) / 180))
        )
    }
}

public struct WeatherSnapshot: Identifiable, Hashable, Codable, Sendable {
    public var place: Place
    public var fetchedAt: Date
    public var current: CurrentWeather
    public var hourly: [HourlyWeather]
    public var daily: [DailyWeather]
    public var airQuality: AirQualitySnapshot?
    public var timezone: TimeZone
    public var generationTimeMS: Double?

    public var id: UUID { place.id }

    public var timeZone: TimeZone { timezone }

    public enum CodingKeys: String, CodingKey {
        case place, fetchedAt, current, hourly, daily, airQuality, timezoneIdentifier, generationTimeMS
    }

    public init(
        place: Place,
        fetchedAt: Date = Date(),
        current: CurrentWeather,
        hourly: [HourlyWeather],
        daily: [DailyWeather],
        airQuality: AirQualitySnapshot? = nil,
        timezone: TimeZone,
        generationTimeMS: Double? = nil
    ) {
        self.place = place
        self.fetchedAt = fetchedAt
        self.current = current
        self.hourly = hourly
        self.daily = daily
        self.airQuality = airQuality
        self.timezone = timezone
        self.generationTimeMS = generationTimeMS
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        place = try c.decode(Place.self, forKey: .place)
        fetchedAt = try c.decode(Date.self, forKey: .fetchedAt)
        current = try c.decode(CurrentWeather.self, forKey: .current)
        hourly = try c.decode([HourlyWeather].self, forKey: .hourly)
        daily = try c.decode([DailyWeather].self, forKey: .daily)
        airQuality = try c.decodeIfPresent(AirQualitySnapshot.self, forKey: .airQuality)
        let id = try c.decode(String.self, forKey: .timezoneIdentifier)
        timezone = TimeZone(identifier: id) ?? .gmt
        generationTimeMS = try c.decodeIfPresent(Double.self, forKey: .generationTimeMS)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(place, forKey: .place)
        try c.encode(fetchedAt, forKey: .fetchedAt)
        try c.encode(current, forKey: .current)
        try c.encode(hourly, forKey: .hourly)
        try c.encode(daily, forKey: .daily)
        try c.encodeIfPresent(airQuality, forKey: .airQuality)
        try c.encode(timezone.identifier, forKey: .timezoneIdentifier)
        try c.encodeIfPresent(generationTimeMS, forKey: .generationTimeMS)
    }

    public var sceneRecipe: SceneRecipe {
        SceneRecipe.from(current: current, place: place, date: Date(), aqi: airQuality?.usAQI)
    }

    public var today: DailyWeather? {
        daily.first
    }

    public func hours(from start: Date = Date(), limit: Int = 24) -> [HourlyWeather] {
        let filtered = hourly.filter { $0.time >= start.addingTimeInterval(-1800) }
        return Array(filtered.prefix(limit))
    }

    public func hours(on day: Date) -> [HourlyWeather] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return hourly.filter { calendar.isDate($0.time, inSameDayAs: day) }
    }

    public var temperatureRange: (min: Double, max: Double) {
        let mins = daily.compactMap(\.temperatureMin)
        let maxs = daily.compactMap(\.temperatureMax)
        return (mins.min() ?? 0, maxs.max() ?? 1)
    }

    public func isStale(ttl: TimeInterval = 15 * 60, now: Date = Date()) -> Bool {
        now.timeIntervalSince(fetchedAt) > ttl
    }
}

public struct PlaceSummary: Hashable, Codable, Sendable {
    public var place: Place
    public var temperature: Double?
    public var weatherCode: Int
    public var isDay: Bool
    public var fetchedAt: Date

    public var condition: WeatherCondition { WeatherCondition(wmoCode: weatherCode) }
}

public struct ModelComparisonSeries: Hashable, Sendable {
    public var model: String
    public var title: String
    public var times: [Date]
    public var temperature: [Double?]
    public var precipitation: [Double?]
}

public struct EnsembleSeries: Hashable, Sendable {
    public var model: String
    public var times: [Date]
    public var temperatureMean: [Double?]
    public var temperatureSpread: [Double?]
    public var precipitationMean: [Double?]
    public var precipitationSpread: [Double?]
}
