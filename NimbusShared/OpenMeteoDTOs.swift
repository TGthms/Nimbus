import Foundation

struct ForecastDTO: Decodable, Sendable {
    var latitude: Double
    var longitude: Double
    var generationtime_ms: Double?
    var utc_offset_seconds: Int?
    var timezone: String?
    var timezone_abbreviation: String?
    var elevation: Double?
    var current: CurrentDTO?
    var hourly: HourlyDTO?
    var daily: DailyDTO?
}

struct CurrentDTO: Decodable, Sendable {
    var time: String
    var interval: Int?
    var temperature_2m: Double?
    var relative_humidity_2m: Double?
    var apparent_temperature: Double?
    var is_day: Int?
    var precipitation: Double?
    var rain: Double?
    var showers: Double?
    var snowfall: Double?
    var weather_code: Int?
    var cloud_cover: Double?
    var pressure_msl: Double?
    var surface_pressure: Double?
    var wind_speed_10m: Double?
    var wind_direction_10m: Double?
    var wind_gusts_10m: Double?
    var visibility: Double?
    var dew_point_2m: Double?
    var uv_index: Double?
    var cape: Double?
}

struct HourlyDTO: Decodable, Sendable {
    var time: [String]
    var temperature_2m: [Double?]?
    var relative_humidity_2m: [Double?]?
    var dew_point_2m: [Double?]?
    var apparent_temperature: [Double?]?
    var precipitation_probability: [Double?]?
    var precipitation: [Double?]?
    var rain: [Double?]?
    var showers: [Double?]?
    var snowfall: [Double?]?
    var weather_code: [Int?]?
    var pressure_msl: [Double?]?
    var cloud_cover: [Double?]?
    var cloud_cover_low: [Double?]?
    var cloud_cover_mid: [Double?]?
    var cloud_cover_high: [Double?]?
    var visibility: [Double?]?
    var wind_speed_10m: [Double?]?
    var wind_direction_10m: [Double?]?
    var wind_gusts_10m: [Double?]?
    var uv_index: [Double?]?
    var is_day: [Int?]?
    var cape: [Double?]?
    var lifted_index: [Double?]?
    var convective_inhibition: [Double?]?
    var freezing_level_height: [Double?]?
    var boundary_layer_height: [Double?]?
    var shortwave_radiation: [Double?]?
    var direct_radiation: [Double?]?
    var diffuse_radiation: [Double?]?
    var sunshine_duration: [Double?]?
    var temperature_1000hPa: [Double?]?
    var temperature_925hPa: [Double?]?
    var temperature_850hPa: [Double?]?
    var temperature_700hPa: [Double?]?
    var temperature_500hPa: [Double?]?
    var temperature_300hPa: [Double?]?
    var relative_humidity_1000hPa: [Double?]?
    var relative_humidity_925hPa: [Double?]?
    var relative_humidity_850hPa: [Double?]?
    var relative_humidity_700hPa: [Double?]?
    var relative_humidity_500hPa: [Double?]?
    var relative_humidity_300hPa: [Double?]?
    var wind_speed_1000hPa: [Double?]?
    var wind_speed_850hPa: [Double?]?
    var wind_speed_700hPa: [Double?]?
    var wind_speed_500hPa: [Double?]?
    var wind_direction_1000hPa: [Double?]?
    var wind_direction_850hPa: [Double?]?
    var wind_direction_700hPa: [Double?]?
    var wind_direction_500hPa: [Double?]?
}

struct DailyDTO: Decodable, Sendable {
    var time: [String]
    var weather_code: [Int?]?
    var temperature_2m_max: [Double?]?
    var temperature_2m_min: [Double?]?
    var apparent_temperature_max: [Double?]?
    var apparent_temperature_min: [Double?]?
    var sunrise: [String?]?
    var sunset: [String?]?
    var daylight_duration: [Double?]?
    var sunshine_duration: [Double?]?
    var uv_index_max: [Double?]?
    var precipitation_sum: [Double?]?
    var precipitation_hours: [Double?]?
    var precipitation_probability_max: [Double?]?
    var rain_sum: [Double?]?
    var showers_sum: [Double?]?
    var snowfall_sum: [Double?]?
    var wind_speed_10m_max: [Double?]?
    var wind_gusts_10m_max: [Double?]?
    var wind_direction_10m_dominant: [Double?]?
    var shortwave_radiation_sum: [Double?]?
    var moonrise: [String?]?
    var moonset: [String?]?
    var moon_phase: [Double?]?
}

struct AirQualityDTO: Decodable, Sendable {
    var latitude: Double?
    var longitude: Double?
    var timezone: String?
    var current: AirCurrentDTO?
    var hourly: AirHourlyDTO?
}

struct AirCurrentDTO: Decodable, Sendable {
    var time: String
    var us_aqi: Double?
    var european_aqi: Double?
    var pm2_5: Double?
    var pm10: Double?
    var carbon_monoxide: Double?
    var nitrogen_dioxide: Double?
    var sulphur_dioxide: Double?
    var ozone: Double?
    var alder_pollen: Double?
    var birch_pollen: Double?
    var grass_pollen: Double?
    var mugwort_pollen: Double?
    var olive_pollen: Double?
    var ragweed_pollen: Double?
}

struct AirHourlyDTO: Decodable, Sendable {
    var time: [String]
    var us_aqi: [Double?]?
    var pm2_5: [Double?]?
    var pm10: [Double?]?
    var alder_pollen: [Double?]?
    var birch_pollen: [Double?]?
    var grass_pollen: [Double?]?
}

public struct GeocodingResult: Identifiable, Hashable, Sendable {
    public var id: Int
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var elevation: Double?
    public var timezone: String?
    public var country: String?
    public var countryCode: String?
    public var admin1: String?
    public var population: Int?

    public var subtitle: String {
        [admin1, country].compactMap { $0 }.filter { !$0.isEmpty && $0 != name }.joined(separator: ", ")
    }

    public func asPlace(sortIndex: Int = 100) -> Place {
        Place(
            name: name,
            admin1: admin1,
            country: country,
            latitude: latitude,
            longitude: longitude,
            timezone: timezone,
            sortIndex: sortIndex
        )
    }
}

struct GeocodingDTO: Decodable, Sendable {
    var results: [GeocodingItemDTO]?
}

struct GeocodingItemDTO: Decodable, Sendable {
    var id: Int
    var name: String
    var latitude: Double
    var longitude: Double
    var elevation: Double?
    var timezone: String?
    var country: String?
    var country_code: String?
    var admin1: String?
    var population: Int?
}

struct EnsembleDTO: Decodable, Sendable {
    var timezone: String?
    var hourly: EnsembleHourlyDTO?
}

struct EnsembleHourlyDTO: Decodable, Sendable {
    var time: [String]
    var temperature_2m: [Double?]?
    var temperature_2m_spread: [Double?]?
    var precipitation: [Double?]?
    var precipitation_spread: [Double?]?
}

enum OpenMeteoDateParser {
    static func date(_ string: String, timeZone: TimeZone) -> Date? {
        let local = DateFormatter()
        local.calendar = Calendar(identifier: .gregorian)
        local.locale = Locale(identifier: "en_US_POSIX")
        local.timeZone = timeZone
        if string.count == 10 {
            local.dateFormat = "yyyy-MM-dd"
        } else if string.count == 16 {
            local.dateFormat = "yyyy-MM-dd'T'HH:mm"
        } else if string.contains(".") {
            local.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        } else if string.contains("Z") || string.contains("+") {
            local.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        } else {
            local.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        }
        return local.date(from: string)
    }
}
