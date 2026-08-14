import XCTest
@testable import NimbusShared

final class ChartInspectTests: XCTestCase {
    func testPointerFractionSelectsExpectedHour() {
        XCTAssertEqual(ChartInspect.nearestIndex(count: 24, fraction: 0), 0)
        XCTAssertEqual(ChartInspect.nearestIndex(count: 24, fraction: 1), 23)
        XCTAssertEqual(ChartInspect.nearestIndex(count: 24, fraction: 0.5), 12)
        XCTAssertEqual(ChartInspect.nearestIndex(count: 1, fraction: 0.9), 0)
        let times = Self.hourlyTimes(count: 24)
        XCTAssertEqual(ChartInspect.nearestIndex(times: times, x: 0, width: 230), 0)
        XCTAssertEqual(ChartInspect.nearestIndex(times: times, x: 230, width: 230), 23)
        XCTAssertEqual(ChartInspect.nearestIndex(times: times, x: 10, width: 230), 1)
    }

    func testLeaveResetsToNowNotLastHover() {
        let times = Self.hourlyTimes(count: 24)
        let now = Date(timeIntervalSince1970: 3.2 * 3600)
        let nowIdx = ChartInspect.nowIndex(times: times, now: now)
        XCTAssertEqual(nowIdx, 3)
        XCTAssertEqual(ChartInspect.resolvedIndex(hover: 18, now: nowIdx), 18)
        XCTAssertEqual(ChartInspect.resolvedIndex(hover: nil, now: nowIdx), 3)
        XCTAssertNotEqual(ChartInspect.resolvedIndex(hover: nil, now: nowIdx), 18)
    }

    func testReadoutUsesWeatherFormattingPipeline() {
        let hours = Self.sampleHours()
        let us = UnitPreferences.fromSignals(
            LocaleUnitSignals(regionCode: "US", measurement: .us, temperature: .fahrenheit)
        )
        let metric = UnitPreferences.fromSignals(
            LocaleUnitSignals(regionCode: "GB", measurement: .metric, temperature: .celsius)
        )
        let tz = TimeZone(secondsFromGMT: 0)!

        XCTAssertEqual(ChartInspect.formatValue(hours[0], kind: .temperature, units: us), "32°")
        XCTAssertEqual(ChartInspect.formatValue(hours[0], kind: .wind, units: us), "10 mph")
        XCTAssertEqual(ChartInspect.formatValue(hours[0], kind: .precipitation, units: us), "1.00 in")
        XCTAssertEqual(ChartInspect.formatValue(hours[0], kind: .temperature, units: metric), "0°")
        XCTAssertEqual(ChartInspect.formatValue(hours[0], kind: .wind, units: metric), "16 km/h")

        let hovered = ChartInspect.readout(hours: hours, index: 1, kind: .temperature, units: us, timeZone: tz, now: hours[0].time)
        XCTAssertEqual(hovered.index, 1)
        XCTAssertEqual(hovered.valueLabel, WeatherFormatting.temperature(hours[1].temperature, unit: us.temperature))
        XCTAssertEqual(hovered.valueLabel, "50°")

        let reset = ChartInspect.readout(
            hours: hours,
            index: ChartInspect.resolvedIndex(hover: nil, now: ChartInspect.nowIndex(times: hours.map(\.time), now: hours[0].time)),
            kind: .temperature,
            units: us,
            timeZone: tz,
            now: hours[0].time
        )
        XCTAssertEqual(reset.index, 0)
        XCTAssertEqual(reset.valueLabel, "32°")
        XCTAssertNotEqual(reset.index, hovered.index)
    }

    private static func hourlyTimes(count: Int) -> [Date] {
        (0..<count).map { Date(timeIntervalSince1970: Double($0) * 3600) }
    }

    private static func sampleHours() -> [HourlyWeather] {
        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 3600)
        return [
            hour(at: t0, temp: 0, wind: 16.09344, precip: 25.4),
            hour(at: t1, temp: 10, wind: 8, precip: 0)
        ]
    }

    private static func hour(at time: Date, temp: Double, wind: Double, precip: Double) -> HourlyWeather {
        HourlyWeather(
            time: time,
            temperature: temp,
            apparentTemperature: temp,
            humidity: 50,
            dewPoint: 0,
            precipitationProbability: 20,
            precipitation: precip,
            rain: precip,
            showers: 0,
            snowfall: 0,
            weatherCode: 0,
            pressureMSL: 1013,
            cloudCover: 10,
            cloudCoverLow: 0,
            cloudCoverMid: 0,
            cloudCoverHigh: 0,
            visibility: 16093,
            windSpeed: wind,
            windDirection: 180,
            windGusts: wind,
            uvIndex: 3,
            isDay: true,
            cape: nil,
            liftedIndex: nil,
            convectiveInhibition: nil,
            freezingLevelHeight: nil,
            boundaryLayerHeight: nil,
            shortwaveRadiation: nil,
            directRadiation: nil,
            diffuseRadiation: nil,
            sunshineDuration: nil,
            temperature1000hPa: nil,
            temperature925hPa: nil,
            temperature850hPa: nil,
            temperature700hPa: nil,
            temperature500hPa: nil,
            temperature300hPa: nil,
            humidity1000hPa: nil,
            humidity925hPa: nil,
            humidity850hPa: nil,
            humidity700hPa: nil,
            humidity500hPa: nil,
            humidity300hPa: nil,
            windSpeed1000hPa: nil,
            windSpeed850hPa: nil,
            windSpeed700hPa: nil,
            windSpeed500hPa: nil,
            windDirection1000hPa: nil,
            windDirection850hPa: nil,
            windDirection700hPa: nil,
            windDirection500hPa: nil
        )
    }
}
