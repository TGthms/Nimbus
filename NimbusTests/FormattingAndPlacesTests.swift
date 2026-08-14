import XCTest
@testable import NimbusShared

final class FormattingAndPlacesTests: XCTestCase {
    func testTemperatureConversion() {
        XCTAssertEqual(TemperatureUnit.fahrenheit.display(0), 32, accuracy: 0.001)
        XCTAssertEqual(TemperatureUnit.fahrenheit.display(100), 212, accuracy: 0.001)
        XCTAssertEqual(TemperatureUnit.celsius.display(18), 18, accuracy: 0.001)
    }

    func testWindAndPrecipConversion() {
        XCTAssertEqual(WindSpeedUnit.milesPerHour.displayFromKmh(16.09344), 10, accuracy: 0.05)
        XCTAssertEqual(WindSpeedUnit.metersPerSecond.displayFromKmh(36), 10, accuracy: 0.001)
        XCTAssertEqual(PrecipitationUnit.inch.displayFromMM(25.4), 1, accuracy: 0.001)
    }

    func testFormattingUsesShippedHelpers() {
        XCTAssertEqual(WeatherFormatting.temperature(21.6, unit: .celsius), "22°")
        XCTAssertEqual(WeatherFormatting.percent(41.2), "41%")
        XCTAssertEqual(WeatherFormatting.compass(0), "N")
        XCTAssertEqual(WeatherFormatting.compass(90), "E")
        XCTAssertEqual(WeatherFormatting.compass(180), "S")
        XCTAssertTrue(WeatherFormatting.visibility(12_000, unit: .kilometer).contains("km"))
        XCTAssertEqual(WeatherFormatting.pressure(1013.4), "1013 hPa")
    }

    /// Would fail on the old pipeline: ForecastQuery asked Open-Meteo for mph/inch
    /// while WeatherFormatting.wind/precipitation converted again from km/h and mm
    /// (10 mph → 6 mph). Temperature was never converted at display.
    func testDisplayPipelineIsSIThenConvertOnce() {
        let imperial = UnitPreferences.fromLocale(Locale(identifier: "en_US"))
        let query = ForecastQuery(latitude: 40.7128, longitude: -74.0060, units: imperial)
        let items = URLComponents(url: query.url(), resolvingAgainstBaseURL: false)!.queryItems!
        func value(_ name: String) -> String? { items.first(where: { $0.name == name })?.value }

        XCTAssertEqual(value("temperature_unit"), "celsius")
        XCTAssertEqual(value("wind_speed_unit"), "kmh")
        XCTAssertEqual(value("precipitation_unit"), "mm")

        XCTAssertEqual(WeatherFormatting.temperature(0, unit: .fahrenheit), "32°")
        // Inspector sounding / model-high use these same calls on SI series.
        XCTAssertEqual(WeatherFormatting.temperature(23.3, unit: imperial.temperature), "74°")
        XCTAssertEqual(WeatherFormatting.wind(16.09344, unit: imperial.wind), "10 mph")
        XCTAssertEqual(WeatherFormatting.precipitation(25.4, unit: .inch), "1.00 in")
        XCTAssertNotEqual(WeatherFormatting.temperature(23.3, unit: imperial.temperature), "23°")
        XCTAssertNotEqual(WeatherFormatting.wind(16.09344, unit: imperial.wind), "16 mph")

        let ensemble = query.ensembleURL(model: "gfs_seamless")
        let eItems = URLComponents(url: ensemble, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(eItems.first(where: { $0.name == "temperature_unit" })?.value, "celsius")
        XCTAssertEqual(eItems.first(where: { $0.name == "precipitation_unit" })?.value, "mm")
    }

    func testRelativeUpdated() {
        let now = Date()
        XCTAssertEqual(WeatherFormatting.relativeUpdated(from: now.addingTimeInterval(-10), now: now), "Updated just now")
        XCTAssertEqual(WeatherFormatting.relativeUpdated(from: now.addingTimeInterval(-120), now: now), "Updated 2 minutes ago")
        XCTAssertEqual(WeatherFormatting.relativeUpdated(from: now.addingTimeInterval(-7200), now: now), "Updated 2 hours ago")
    }

    func testPopularCitiesSeed() {
        let places = PopularCities.defaultPlaces()
        XCTAssertEqual(places.first?.isCurrentLocation, true)
        XCTAssertEqual(places.first?.displayName, "My Location")
        XCTAssertGreaterThanOrEqual(PopularCities.seeds.count, 8)
        XCTAssertTrue(places.contains(where: { $0.name == "Tokyo" }))
        XCTAssertTrue(places.contains(where: { $0.name == "London" }))
        XCTAssertTrue(places.contains(where: { $0.name == "New York" }))
        let matches = PopularCities.matching("san")
        XCTAssertTrue(matches.contains(where: { $0.name == "San Francisco" }))
        XCTAssertTrue(PopularCities.matching("").count == PopularCities.seeds.count)
    }

    func testLocaleUnits() {
        let us = Locale(identifier: "en_US")
        let imperial = UnitPreferences.fromLocale(us)
        XCTAssertEqual(imperial.temperature, .fahrenheit)
        XCTAssertEqual(imperial.wind, .milesPerHour)
        let metric = UnitPreferences.fromLocale(Locale(identifier: "en_GB"))
        XCTAssertEqual(metric.temperature, .celsius)
    }

    func testSceneRecipeFromCurrent() {
        let place = PopularCities.seeds.first(where: { $0.name == "Tokyo" })!
        let current = CurrentWeather(
            time: Date(),
            temperature: 12,
            apparentTemperature: 10,
            humidity: 80,
            dewPoint: 8,
            isDay: false,
            precipitation: 2.4,
            rain: 2.4,
            showers: 0,
            snowfall: 0,
            weatherCode: 95,
            cloudCover: 90,
            cloudCoverLow: 80,
            cloudCoverMid: 70,
            cloudCoverHigh: 40,
            pressureMSL: 1002,
            surfacePressure: 1000,
            windSpeed: 30,
            windDirection: 220,
            windGusts: 50,
            visibility: 4000,
            uvIndex: 0,
            cape: 1800,
            liftedIndex: nil,
            convectiveInhibition: nil,
            freezingLevelHeight: 2200,
            boundaryLayerHeight: 800,
            vapourPressureDeficit: nil,
            shortwaveRadiation: 0
        )
        let recipe = SceneRecipe.from(current: current, place: place, aqi: 140)
        XCTAssertTrue(recipe.lightning)
        XCTAssertGreaterThan(recipe.precipRate, 1)
        XCTAssertGreaterThan(recipe.cloudCover, 0.8)
        XCTAssertGreaterThan(recipe.aqiHaze, 0)
    }

    func testSolarMathSmoothAndNoon() {
        XCTAssertEqual(SolarMath.smoothstep(0, 1, -1), 0)
        XCTAssertEqual(SolarMath.smoothstep(0, 1, 2), 1)
        XCTAssertEqual(SolarMath.daylightFactor(elevationDegrees: 40), 1, accuracy: 0.01)
        XCTAssertEqual(SolarMath.daylightFactor(elevationDegrees: -20), 0, accuracy: 0.01)
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 6
        comps.day = 21
        comps.hour = 12
        comps.minute = 0
        comps.timeZone = TimeZone(identifier: "Asia/Tokyo")
        let noon = Calendar(identifier: .gregorian).date(from: comps)!
        let elev = SolarMath.solarElevation(latitude: 35.6895, longitude: 139.6917, date: noon)
        XCTAssertGreaterThan(elev, 60, "Tokyo summer noon should be high sun, got \(elev)")
    }

    func testMoonPhaseNames() {
        let phase = MoonMath.phase(on: Date(timeIntervalSince1970: 1_704_067_200))
        XCTAssertGreaterThanOrEqual(phase.illumination, 0)
        XCTAssertLessThanOrEqual(phase.illumination, 1)
        XCTAssertFalse(phase.name.isEmpty)
    }

    func testStoreSeedsWhenEmpty() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = WeatherStore(root: dir)
        let places = await store.loadPlaces()
        XCTAssertEqual(places.first?.isCurrentLocation, true)
        XCTAssertTrue(places.contains(where: { $0.name == "Paris" }))
    }
}
