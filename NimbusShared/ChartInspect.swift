import Foundation

public enum ChartSeriesKind: String, Sendable, CaseIterable {
    case temperature
    case apparentTemperature
    case wind
    case precipitation
    case humidity
    case uv
    case pressure
    case visibility
}

public struct ChartReadout: Equatable, Sendable {
    public var index: Int
    public var timeLabel: String
    public var valueLabel: String

    public init(index: Int, timeLabel: String, valueLabel: String) {
        self.index = index
        self.timeLabel = timeLabel
        self.valueLabel = valueLabel
    }
}

/// Nearest-hour inspect used by overlay, inspector, and hourly charts.
public enum ChartInspect {
    public static func nearestIndex(count: Int, fraction: Double) -> Int {
        guard count > 1 else { return 0 }
        let t = min(1, max(0, fraction))
        return Int((t * Double(count - 1)).rounded())
    }

    public static func nearestIndex(times: [Date], x: Double, width: Double) -> Int {
        guard width > 0, !times.isEmpty else { return 0 }
        return nearestIndex(count: times.count, fraction: x / width)
    }

    public static func nearestIndex(times: [Date], target: Date) -> Int {
        guard !times.isEmpty else { return 0 }
        var best = 0
        var bestDelta = abs(times[0].timeIntervalSince(target))
        for i in 1..<times.count {
            let delta = abs(times[i].timeIntervalSince(target))
            if delta < bestDelta {
                bestDelta = delta
                best = i
            }
        }
        return best
    }

    public static func nowIndex(times: [Date], now: Date = Date()) -> Int {
        nearestIndex(times: times, target: now)
    }

    /// Hover wins while the pointer is down/inside; leaving the chart passes `nil`.
    public static func resolvedIndex(hover: Int?, now: Int) -> Int {
        hover ?? now
    }

    public static func formatValue(_ hour: HourlyWeather, kind: ChartSeriesKind, units: UnitPreferences) -> String {
        switch kind {
        case .temperature:
            return WeatherFormatting.temperature(hour.temperature, unit: units.temperature)
        case .apparentTemperature:
            return WeatherFormatting.temperature(hour.apparentTemperature, unit: units.temperature)
        case .wind:
            return WeatherFormatting.wind(hour.windSpeed, unit: units.wind)
        case .precipitation:
            return WeatherFormatting.precipitation(hour.precipitation, unit: units.precipitation)
        case .humidity:
            return WeatherFormatting.percent(hour.humidity)
        case .uv:
            guard let uv = hour.uvIndex else { return "—" }
            return String(format: uv < 10 ? "%.1f" : "%.0f", uv)
        case .pressure:
            return WeatherFormatting.pressure(hour.pressureMSL)
        case .visibility:
            return WeatherFormatting.visibility(hour.visibility, unit: units.distance)
        }
    }

    public static func readout(
        hours: [HourlyWeather],
        index: Int,
        kind: ChartSeriesKind,
        units: UnitPreferences,
        timeZone: TimeZone,
        now: Date = Date()
    ) -> ChartReadout {
        guard !hours.isEmpty else {
            return ChartReadout(index: 0, timeLabel: "—", valueLabel: "—")
        }
        let i = min(max(0, index), hours.count - 1)
        let hour = hours[i]
        return ChartReadout(
            index: i,
            timeLabel: WeatherFormatting.hourLabel(hour.time, timeZone: timeZone, now: now),
            valueLabel: formatValue(hour, kind: kind, units: units)
        )
    }

    public static func displayY(_ hour: HourlyWeather, kind: ChartSeriesKind, units: UnitPreferences) -> Double {
        switch kind {
        case .temperature: return units.temperature.display(hour.temperature ?? 0)
        case .apparentTemperature: return units.temperature.display(hour.apparentTemperature ?? 0)
        case .wind: return units.wind.displayFromKmh(hour.windSpeed ?? 0)
        case .precipitation: return units.precipitation.displayFromMM(hour.precipitation ?? 0)
        case .humidity: return hour.humidity ?? 0
        case .uv: return hour.uvIndex ?? 0
        case .pressure: return hour.pressureMSL ?? 0
        case .visibility:
            let meters = hour.visibility ?? 0
            return units.distance == .mile ? meters / 1609.344 : meters / 1000
        }
    }
}
