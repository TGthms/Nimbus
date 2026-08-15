import XCTest
@testable import NimbusShared

final class OpenMeteoClientTests: XCTestCase {
    func testForecastURLContainsRequiredParameters() {
        let query = ForecastQuery(
            latitude: 35.6895,
            longitude: 139.6917,
            timezone: "Asia/Tokyo",
            forecastDays: 16,
            units: UnitPreferences(temperature: .celsius, wind: .kilometersPerHour, precipitation: .millimeter, followLocale: false),
            includeAtmosphere: true,
            includeSolar: true,
            includePressureLevels: true
        )
        let url = query.url()
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        func value(_ name: String) -> String? { items.first(where: { $0.name == name })?.value }

        XCTAssertEqual(url.host, "api.open-meteo.com")
        XCTAssertEqual(url.path, "/v1/forecast")
        XCTAssertEqual(value("latitude"), "35.6895")
        XCTAssertEqual(value("longitude"), "139.6917")
        XCTAssertEqual(value("timezone"), "Asia/Tokyo")
        XCTAssertEqual(value("forecast_days"), "16")
        XCTAssertEqual(value("temperature_unit"), "celsius")
        XCTAssertEqual(value("wind_speed_unit"), "kmh")
        XCTAssertEqual(value("precipitation_unit"), "mm")
        XCTAssertTrue(value("current")!.contains("weather_code"))
        XCTAssertTrue(value("hourly")!.contains("precipitation_probability"))
        XCTAssertTrue(value("hourly")!.contains("cape"))
        XCTAssertTrue(value("hourly")!.contains("shortwave_radiation"))
        XCTAssertTrue(value("hourly")!.contains("temperature_850hPa"))
        XCTAssertTrue(value("daily")!.contains("temperature_2m_max"))
    }

    func testAirQualityAndGeocodingURLs() {
        let query = ForecastQuery(latitude: 51.5, longitude: -0.12)
        let air = query.airQualityURL()
        XCTAssertEqual(air.host, "air-quality-api.open-meteo.com")
        XCTAssertTrue(air.absoluteString.contains("us_aqi"))

        let geo = ForecastQuery.geocodingURL(name: "Tokyo", count: 8, language: "en")
        XCTAssertEqual(geo.host, "geocoding-api.open-meteo.com")
        XCTAssertTrue(geo.absoluteString.contains("name=Tokyo"))
    }

    func testDecodeRecordedLiveTokyoResponse() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/tokyo-live.json")
        let data = try Data(contentsOf: url)
        let place = PopularCities.seeds.first(where: { $0.name == "Tokyo" })!
        let snapshot = try OpenMeteoClient().snapshot(fromForecastJSON: data, place: place)
        XCTAssertFalse(snapshot.hourly.isEmpty)
        XCTAssertFalse(snapshot.daily.isEmpty)
        XCTAssertNotNil(snapshot.current.temperature)
        XCTAssertNotEqual(snapshot.current.condition, .unknown)
        XCTAssertEqual(snapshot.current.condition, WeatherCondition(wmoCode: snapshot.current.weatherCode))
        XCTAssertGreaterThan(snapshot.hourly.count, 24)
        XCTAssertEqual(snapshot.daily.count, 7)
    }

    func testDecodeForecastFixtureThroughClient() throws {
        let client = OpenMeteoClient()
        let place = PopularCities.seeds.first(where: { $0.name == "Tokyo" })!
        let snapshot = try client.snapshot(fromForecastJSON: Data(Self.forecastFixture.utf8), place: place)

        XCTAssertEqual(snapshot.place.name, "Tokyo")
        XCTAssertEqual(snapshot.current.weatherCode, 2)
        XCTAssertEqual(snapshot.current.condition, .partlyCloudy)
        XCTAssertEqual(snapshot.current.temperature, 22.4)
        XCTAssertEqual(snapshot.hourly.count, 3)
        XCTAssertEqual(snapshot.hourly[1].precipitationProbability, 40)
        XCTAssertEqual(snapshot.daily.count, 2)
        XCTAssertEqual(snapshot.daily[0].temperatureMax, 24.1)
        XCTAssertEqual(snapshot.timezone.identifier, "Asia/Tokyo")
        XCTAssertEqual(snapshot.current.condition.phrase(isDay: true), "Partly Cloudy")
    }

    func testSnapshotPastTTLIsStaleSoRefreshCanReplace() throws {
        let decoded = try OpenMeteoClient().snapshot(
            fromForecastJSON: Data(Self.forecastFixture.utf8),
            place: PopularCities.seeds.first(where: { $0.name == "Tokyo" })!
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let fresh = WeatherSnapshot(
            place: decoded.place,
            fetchedAt: now,
            current: decoded.current,
            hourly: decoded.hourly,
            daily: decoded.daily,
            timezone: decoded.timezone
        )
        XCTAssertFalse(fresh.isStale(ttl: 15 * 60, now: now))
        XCTAssertFalse(fresh.isStale(ttl: 15 * 60, now: now.addingTimeInterval(15 * 60)))
        XCTAssertTrue(fresh.isStale(ttl: 15 * 60, now: now.addingTimeInterval(15 * 60 + 1)))

        let expired = WeatherSnapshot(
            place: decoded.place,
            fetchedAt: now.addingTimeInterval(-16 * 60),
            current: decoded.current,
            hourly: decoded.hourly,
            daily: decoded.daily,
            timezone: decoded.timezone
        )
        XCTAssertTrue(expired.isStale(ttl: 15 * 60, now: now))
        XCTAssertFalse(expired.isStale(ttl: 45 * 60, now: now))
    }

    func testDecodeGeocodingFixtureThroughClient() throws {
        let results = try OpenMeteoClient().places(fromGeocodingJSON: Data(Self.geocodingFixture.utf8))
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].name, "Tokyo")
        XCTAssertEqual(results[0].country, "Japan")
        XCTAssertEqual(results[0].latitude, 35.6895, accuracy: 0.0001)
        let place = results[0].asPlace()
        XCTAssertEqual(place.name, "Tokyo")
        XCTAssertFalse(place.isCurrentLocation)
    }

    func testDecodeAirQualityFixtureThroughClient() throws {
        let aq = try OpenMeteoClient().airQuality(fromJSON: Data(Self.airQualityFixture.utf8), timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        XCTAssertNotNil(aq)
        XCTAssertEqual(aq?.usAQI, 42)
        XCTAssertEqual(aq?.pm25, 9.2)
        XCTAssertEqual(aq?.category, .good)
        XCTAssertEqual(aq?.dominantPollutant, "O₃")
    }

    func testEmptyForecastThrows() {
        let json = #"{"latitude":1,"longitude":1}"#
        XCTAssertThrowsError(try OpenMeteoClient().snapshot(fromForecastJSON: Data(json.utf8), place: PopularCities.seeds[0])) { error in
            guard case OpenMeteoError.emptyForecast = error else {
                return XCTFail("Expected emptyForecast, got \(error)")
            }
        }
    }

    func testDefaultEnsembleModel() {
        let berlin = PopularCities.seeds.first(where: { $0.name == "Berlin" })!
        let tokyo = PopularCities.seeds.first(where: { $0.name == "Tokyo" })!
        XCTAssertEqual(OpenMeteoClient.defaultEnsembleModel(for: berlin), "icon_seamless_eps")
        XCTAssertEqual(OpenMeteoClient.defaultEnsembleModel(for: tokyo), "gfs_seamless")
    }

    private static let forecastFixture = """
    {
      "latitude": 35.6895,
      "longitude": 139.6917,
      "generationtime_ms": 1.2,
      "timezone": "Asia/Tokyo",
      "timezone_abbreviation": "JST",
      "current": {
        "time": "2026-08-12T15:00",
        "interval": 900,
        "temperature_2m": 22.4,
        "relative_humidity_2m": 61,
        "apparent_temperature": 23.1,
        "is_day": 1,
        "precipitation": 0.0,
        "rain": 0.0,
        "showers": 0.0,
        "snowfall": 0.0,
        "weather_code": 2,
        "cloud_cover": 48,
        "pressure_msl": 1014.2,
        "surface_pressure": 1011.0,
        "wind_speed_10m": 12.4,
        "wind_direction_10m": 180,
        "wind_gusts_10m": 20.1,
        "visibility": 24100
      },
      "hourly": {
        "time": ["2026-08-12T14:00", "2026-08-12T15:00", "2026-08-12T16:00"],
        "temperature_2m": [21.8, 22.4, 22.0],
        "relative_humidity_2m": [64, 61, 63],
        "dew_point_2m": [14.8, 14.6, 14.7],
        "apparent_temperature": [22.2, 23.1, 22.7],
        "precipitation_probability": [20, 40, 35],
        "precipitation": [0.0, 0.1, 0.0],
        "rain": [0.0, 0.1, 0.0],
        "showers": [0.0, 0.0, 0.0],
        "snowfall": [0.0, 0.0, 0.0],
        "weather_code": [1, 2, 3],
        "pressure_msl": [1014.6, 1014.2, 1013.8],
        "cloud_cover": [20, 48, 70],
        "visibility": [24100, 24100, 20000],
        "wind_speed_10m": [10.0, 12.4, 11.0],
        "wind_direction_10m": [170, 180, 190],
        "uv_index": [6.2, 5.1, 3.0],
        "is_day": [1, 1, 1]
      },
      "daily": {
        "time": ["2026-08-12", "2026-08-13"],
        "weather_code": [2, 61],
        "temperature_2m_max": [24.1, 21.0],
        "temperature_2m_min": [18.2, 17.4],
        "sunrise": ["2026-08-12T04:58", "2026-08-13T04:59"],
        "sunset": ["2026-08-12T18:32", "2026-08-13T18:31"],
        "uv_index_max": [7.4, 4.1],
        "precipitation_sum": [0.1, 6.2],
        "precipitation_probability_max": [40, 80]
      }
    }
    """

    private static let geocodingFixture = """
    {
      "results": [
        {
          "id": 1850147,
          "name": "Tokyo",
          "latitude": 35.6895,
          "longitude": 139.6917,
          "elevation": 40,
          "timezone": "Asia/Tokyo",
          "country": "Japan",
          "country_code": "JP",
          "admin1": "Tokyo",
          "population": 8336599
        },
        {
          "id": 1,
          "name": "Tokoname",
          "latitude": 34.88,
          "longitude": 136.84,
          "country": "Japan"
        }
      ]
    }
    """

    private static let airQualityFixture = """
    {
      "latitude": 35.7,
      "longitude": 139.7,
      "timezone": "Asia/Tokyo",
      "current": {
        "time": "2026-08-12T15:00",
        "us_aqi": 42,
        "european_aqi": 30,
        "pm2_5": 9.2,
        "pm10": 14.0,
        "carbon_monoxide": 120,
        "nitrogen_dioxide": 12,
        "sulphur_dioxide": 3,
        "ozone": 68
      },
      "hourly": {
        "time": ["2026-08-12T15:00"],
        "us_aqi": [42],
        "pm2_5": [9.2]
      }
    }
    """
}
