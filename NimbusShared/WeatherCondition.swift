import Foundation
import SwiftUI

/// WMO weather interpretation codes used by Open-Meteo.
/// https://open-meteo.com/en/docs
public enum WeatherCondition: String, Sendable, Codable, Hashable, CaseIterable {
    case clear
    case mainlyClear
    case partlyCloudy
    case overcast
    case fog
    case depositingRimeFog
    case lightDrizzle
    case drizzle
    case denseDrizzle
    case lightFreezingDrizzle
    case denseFreezingDrizzle
    case slightRain
    case rain
    case heavyRain
    case lightFreezingRain
    case heavyFreezingRain
    case slightSnow
    case snow
    case heavySnow
    case snowGrains
    case slightRainShowers
    case rainShowers
    case violentRainShowers
    case slightSnowShowers
    case heavySnowShowers
    case thunderstorm
    case thunderstormSlightHail
    case thunderstormHeavyHail
    case unknown

    public init(wmoCode: Int) {
        switch wmoCode {
        case 0: self = .clear
        case 1: self = .mainlyClear
        case 2: self = .partlyCloudy
        case 3: self = .overcast
        case 45: self = .fog
        case 48: self = .depositingRimeFog
        case 51: self = .lightDrizzle
        case 53: self = .drizzle
        case 55: self = .denseDrizzle
        case 56: self = .lightFreezingDrizzle
        case 57: self = .denseFreezingDrizzle
        case 61: self = .slightRain
        case 63: self = .rain
        case 65: self = .heavyRain
        case 66: self = .lightFreezingRain
        case 67: self = .heavyFreezingRain
        case 71: self = .slightSnow
        case 73: self = .snow
        case 75: self = .heavySnow
        case 77: self = .snowGrains
        case 80: self = .slightRainShowers
        case 81: self = .rainShowers
        case 82: self = .violentRainShowers
        case 85: self = .slightSnowShowers
        case 86: self = .heavySnowShowers
        case 95: self = .thunderstorm
        case 96: self = .thunderstormSlightHail
        case 99: self = .thunderstormHeavyHail
        default: self = .unknown
        }
    }

    public var wmoCode: Int {
        switch self {
        case .clear: return 0
        case .mainlyClear: return 1
        case .partlyCloudy: return 2
        case .overcast: return 3
        case .fog: return 45
        case .depositingRimeFog: return 48
        case .lightDrizzle: return 51
        case .drizzle: return 53
        case .denseDrizzle: return 55
        case .lightFreezingDrizzle: return 56
        case .denseFreezingDrizzle: return 57
        case .slightRain: return 61
        case .rain: return 63
        case .heavyRain: return 65
        case .lightFreezingRain: return 66
        case .heavyFreezingRain: return 67
        case .slightSnow: return 71
        case .snow: return 73
        case .heavySnow: return 75
        case .snowGrains: return 77
        case .slightRainShowers: return 80
        case .rainShowers: return 81
        case .violentRainShowers: return 82
        case .slightSnowShowers: return 85
        case .heavySnowShowers: return 86
        case .thunderstorm: return 95
        case .thunderstormSlightHail: return 96
        case .thunderstormHeavyHail: return 99
        case .unknown: return -1
        }
    }

    public func phrase(isDay: Bool) -> String {
        switch self {
        case .clear: return isDay ? "Clear" : "Clear Night"
        case .mainlyClear: return isDay ? "Mostly Clear" : "Mostly Clear Night"
        case .partlyCloudy: return "Partly Cloudy"
        case .overcast: return "Overcast"
        case .fog: return "Fog"
        case .depositingRimeFog: return "Rime Fog"
        case .lightDrizzle: return "Light Drizzle"
        case .drizzle: return "Drizzle"
        case .denseDrizzle: return "Dense Drizzle"
        case .lightFreezingDrizzle: return "Light Freezing Drizzle"
        case .denseFreezingDrizzle: return "Freezing Drizzle"
        case .slightRain: return "Light Rain"
        case .rain: return "Rain"
        case .heavyRain: return "Heavy Rain"
        case .lightFreezingRain: return "Light Freezing Rain"
        case .heavyFreezingRain: return "Freezing Rain"
        case .slightSnow: return "Light Snow"
        case .snow: return "Snow"
        case .heavySnow: return "Heavy Snow"
        case .snowGrains: return "Snow Grains"
        case .slightRainShowers: return "Light Showers"
        case .rainShowers: return "Showers"
        case .violentRainShowers: return "Violent Showers"
        case .slightSnowShowers: return "Light Snow Showers"
        case .heavySnowShowers: return "Snow Showers"
        case .thunderstorm: return "Thunderstorm"
        case .thunderstormSlightHail: return "Thunderstorm with Hail"
        case .thunderstormHeavyHail: return "Severe Thunderstorm"
        case .unknown: return "—"
        }
    }

    public func symbolName(isDay: Bool) -> String {
        switch self {
        case .clear: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case .mainlyClear: return isDay ? "sun.max.fill" : "moon.fill"
        case .partlyCloudy: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case .overcast: return "cloud.fill"
        case .fog, .depositingRimeFog: return "cloud.fog.fill"
        case .lightDrizzle, .drizzle, .denseDrizzle:
            return "cloud.drizzle.fill"
        case .lightFreezingDrizzle, .denseFreezingDrizzle:
            return "cloud.sleet.fill"
        case .slightRain, .rain, .heavyRain:
            return "cloud.rain.fill"
        case .lightFreezingRain, .heavyFreezingRain:
            return "cloud.hail.fill"
        case .slightSnow, .snow, .heavySnow, .snowGrains:
            return "cloud.snow.fill"
        case .slightRainShowers, .rainShowers, .violentRainShowers:
            return isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill"
        case .slightSnowShowers, .heavySnowShowers:
            return "cloud.snow.fill"
        case .thunderstorm, .thunderstormSlightHail, .thunderstormHeavyHail:
            return "cloud.bolt.rain.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }

    public var isPrecipitation: Bool {
        switch self {
        case .clear, .mainlyClear, .partlyCloudy, .overcast, .fog, .depositingRimeFog, .unknown:
            return false
        default:
            return true
        }
    }

    public var isSnow: Bool {
        switch self {
        case .slightSnow, .snow, .heavySnow, .snowGrains, .slightSnowShowers, .heavySnowShowers:
            return true
        default:
            return false
        }
    }

    public var isThunder: Bool {
        switch self {
        case .thunderstorm, .thunderstormSlightHail, .thunderstormHeavyHail:
            return true
        default:
            return false
        }
    }

    public var isFog: Bool {
        self == .fog || self == .depositingRimeFog
    }

    public var precipIntensity: Double {
        switch self {
        case .lightDrizzle, .lightFreezingDrizzle, .slightRain, .lightFreezingRain, .slightSnow, .slightRainShowers, .slightSnowShowers, .snowGrains:
            return 0.25
        case .drizzle, .rain, .snow, .rainShowers:
            return 0.55
        case .denseDrizzle, .denseFreezingDrizzle, .heavyRain, .heavyFreezingRain, .heavySnow, .violentRainShowers, .heavySnowShowers:
            return 0.9
        case .thunderstorm:
            return 0.7
        case .thunderstormSlightHail:
            return 0.85
        case .thunderstormHeavyHail:
            return 1.0
        default:
            return 0
        }
    }

    public var cloudBias: Double {
        switch self {
        case .clear: return 0.05
        case .mainlyClear: return 0.2
        case .partlyCloudy: return 0.45
        case .overcast, .fog, .depositingRimeFog: return 0.9
        default: return 0.7
        }
    }
}

public enum UVCategory: String, Sendable {
    case low, moderate, high, veryHigh, extreme

    public init(index: Double) {
        switch index {
        case ..<3: self = .low
        case ..<6: self = .moderate
        case ..<8: self = .high
        case ..<11: self = .veryHigh
        default: self = .extreme
        }
    }

    public var title: String {
        switch self {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .veryHigh: return "Very High"
        case .extreme: return "Extreme"
        }
    }

    public var color: Color {
        switch self {
        case .low: return Color(red: 0.35, green: 0.78, blue: 0.42)
        case .moderate: return Color(red: 0.98, green: 0.82, blue: 0.22)
        case .high: return Color(red: 0.98, green: 0.55, blue: 0.18)
        case .veryHigh: return Color(red: 0.90, green: 0.22, blue: 0.22)
        case .extreme: return Color(red: 0.62, green: 0.20, blue: 0.72)
        }
    }
}

public enum AQICategory: String, Sendable {
    case good, moderate, unhealthySensitive, unhealthy, veryUnhealthy, hazardous

    public init(usAQI: Double) {
        switch usAQI {
        case ..<50: self = .good
        case ..<100: self = .moderate
        case ..<150: self = .unhealthySensitive
        case ..<200: self = .unhealthy
        case ..<300: self = .veryUnhealthy
        default: self = .hazardous
        }
    }

    public var title: String {
        switch self {
        case .good: return "Good"
        case .moderate: return "Moderate"
        case .unhealthySensitive: return "Unhealthy for Sensitive Groups"
        case .unhealthy: return "Unhealthy"
        case .veryUnhealthy: return "Very Unhealthy"
        case .hazardous: return "Hazardous"
        }
    }

    public var shortTitle: String {
        switch self {
        case .good: return "Good"
        case .moderate: return "Moderate"
        case .unhealthySensitive: return "Sensitive"
        case .unhealthy: return "Unhealthy"
        case .veryUnhealthy: return "Very Unhealthy"
        case .hazardous: return "Hazardous"
        }
    }

    public var color: Color {
        switch self {
        case .good: return Color(red: 0.35, green: 0.78, blue: 0.42)
        case .moderate: return Color(red: 0.98, green: 0.82, blue: 0.22)
        case .unhealthySensitive: return Color(red: 0.98, green: 0.55, blue: 0.18)
        case .unhealthy: return Color(red: 0.90, green: 0.22, blue: 0.22)
        case .veryUnhealthy: return Color(red: 0.55, green: 0.16, blue: 0.55)
        case .hazardous: return Color(red: 0.49, green: 0.06, blue: 0.15)
        }
    }
}
