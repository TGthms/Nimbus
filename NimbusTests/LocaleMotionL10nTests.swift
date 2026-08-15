import XCTest
@testable import NimbusShared

final class LocaleMotionL10nTests: XCTestCase {
    func testUSLocaleYieldsImperialUnits() {
        let units = UnitPreferences.fromLocale(Locale(identifier: "en_US"))
        XCTAssertEqual(units.temperature, .fahrenheit)
        XCTAssertEqual(units.wind, .milesPerHour)
        XCTAssertEqual(units.precipitation, .inch)
        XCTAssertEqual(units.distance, .mile)
        XCTAssertTrue(units.followLocale)
        XCTAssertTrue(UnitPreferences.usesImperial(Locale(identifier: "en_US")))
    }

    /// System Settings can be Region = United States + Measurement = Metric + Temperature = °C.
    func testUSRegionMetricSystemAndCelsiusFollowsLanguageAndRegion() {
        let units = UnitPreferences.fromSignals(
            LocaleUnitSignals(regionCode: "US", measurement: .metric, temperature: .celsius)
        )
        XCTAssertEqual(units.temperature, .celsius)
        XCTAssertEqual(units.wind, .kilometersPerHour)
        XCTAssertEqual(units.precipitation, .millimeter)
        XCTAssertEqual(units.distance, .kilometer)
        XCTAssertFalse(UnitPreferences.usesImperialMeasures(.metric, regionCode: "US"))
    }

    func testTemperaturePickerIsIndependentOfUSMeasures() {
        let units = UnitPreferences.fromSignals(
            LocaleUnitSignals(regionCode: "US", measurement: .us, temperature: .celsius)
        )
        XCTAssertEqual(units.temperature, .celsius)
        XCTAssertEqual(units.wind, .milesPerHour)
        XCTAssertEqual(units.precipitation, .inch)
    }

    func testFromSystemHonorsAppleTemperatureUnit() {
        let celsius = UnitPreferences.fromSystem(
            locale: Locale(identifier: "en_US"),
            temperaturePreference: "Celsius"
        )
        XCTAssertEqual(celsius.temperature, .celsius)
        let fahrenheit = UnitPreferences.fromSystem(
            locale: Locale(identifier: "en_US"),
            temperaturePreference: "Fahrenheit"
        )
        XCTAssertEqual(fahrenheit.temperature, .fahrenheit)
        XCTAssertEqual(LocaleUnitSignals.parseTemperature("Celsius"), .celsius)
        XCTAssertEqual(LocaleUnitSignals.parseTemperature("Fahrenheit"), .fahrenheit)
    }

    func testGBAndJPLocalesYieldMetricUnits() {
        for id in ["en_GB", "ja_JP", "fr_FR"] {
            let units = UnitPreferences.fromLocale(Locale(identifier: id))
            XCTAssertEqual(units.temperature, .celsius, id)
            XCTAssertEqual(units.wind, .kilometersPerHour, id)
            XCTAssertEqual(units.precipitation, .millimeter, id)
            XCTAssertEqual(units.distance, .kilometer, id)
        }
    }

    func testFollowLocaleResolvedReplacesStoredUnits() {
        var stored = UnitPreferences(temperature: .celsius, wind: .knots, precipitation: .millimeter, distance: .kilometer, followLocale: true)
        let resolved = stored.resolved(against: Locale(identifier: "en_US"))
        XCTAssertEqual(resolved.temperature, .fahrenheit)
        XCTAssertEqual(resolved.wind, .milesPerHour)
        stored.followLocale = false
        stored.temperature = .celsius
        XCTAssertEqual(stored.resolved(against: Locale(identifier: "en_US")).temperature, .celsius)
    }

    func testVisibilityUsesDistanceUnit() {
        XCTAssertTrue(WeatherFormatting.visibility(16_093, unit: .mile).contains("mi"))
        XCTAssertTrue(WeatherFormatting.visibility(12_000, unit: .kilometer).contains("km"))
    }

    func testReduceMotionFollowSystemDisablesParticles() {
        XCTAssertFalse(MotionPolicy.allowsParticles(systemReduceMotion: true, preference: .followSystem))
        XCTAssertFalse(MotionPolicy.allowsLightning(systemReduceMotion: true, preference: .followSystem))
        XCTAssertFalse(MotionPolicy.allowsDynamicMotion(systemReduceMotion: true, preference: .followSystem))
    }

    func testReduceMotionNeverAndAlways() {
        XCTAssertFalse(MotionPolicy.allowsParticles(systemReduceMotion: false, preference: .never))
        XCTAssertTrue(MotionPolicy.allowsParticles(systemReduceMotion: true, preference: .always))
        XCTAssertTrue(MotionPolicy.allowsLightning(systemReduceMotion: false, preference: .followSystem))
    }

    func testLanguageResolverSystemFirst() {
        XCTAssertEqual(LanguageResolver.resolve(preference: .japanese, preferredLanguages: ["en-US"]), .japanese)
        XCTAssertEqual(LanguageResolver.resolve(preference: .system, preferredLanguages: ["ja-JP", "en"]), .japanese)
        XCTAssertEqual(LanguageResolver.match(["zh-Hans-CN"]), .chineseSimplified)
        XCTAssertEqual(LanguageResolver.match(["zh-Hant-TW"]), .chineseTraditional)
        XCTAssertEqual(LanguageResolver.match(["pt-BR"]), .portugueseBrazil)
        XCTAssertEqual(LanguageResolver.match(["ar-SA"]), .arabic)
        XCTAssertEqual(LanguageResolver.match(["nl-NL"]), .dutch)
        XCTAssertEqual(LanguageResolver.match(["ko-KR"]), .korean)
        XCTAssertEqual(LanguageResolver.match(["it-IT"]), .italian)
        XCTAssertEqual(LanguageResolver.match(["es-MX"]), .spanish)
        XCTAssertEqual(LanguageResolver.match(["fr-CA"]), .french)
        XCTAssertEqual(LanguageResolver.match(["de-DE"]), .german)
        XCTAssertEqual(LanguageResolver.match(["en-AU"]), .english)
    }

    func testEveryShippedLanguageResolvesDone() {
        for language in AppLanguage.displayOrder {
            let value = L10n.string(L10n.probeKey, language: language)
            XCTAssertFalse(value.isEmpty, "\(language)")
            XCTAssertNotEqual(value, L10n.probeKey, "\(language) missing translation")
        }
        XCTAssertEqual(AppLanguage.displayOrder.count, 12)
        XCTAssertEqual(AppLanguage.displayOrder.first, .english)
        XCTAssertEqual(L10n.string("done", language: .english), "Done")
        XCTAssertEqual(L10n.string("done", language: .japanese), "完了")
        XCTAssertEqual(L10n.string("sounding", language: .english), "Sounding")
        XCTAssertEqual(L10n.string("settings", language: .chineseSimplified), "设置")
        XCTAssertEqual(L10n.string("location_privacy", language: .english), "My Location uses approximate location only — about a kilometer, not precise GPS. That coarse position is what Nimbus stores and sends to Open-Meteo.")
        XCTAssertEqual(L10n.string("sunrise", language: .english), "Sunrise")
        XCTAssertEqual(L10n.string("sunset", language: .english), "Sunset")
        XCTAssertNotEqual(L10n.string("sunrise", language: .english), L10n.string("today", language: .english))
        XCTAssertNotEqual(L10n.string("sunset", language: .english), L10n.string("sun_moon", language: .english))
        for language in AppLanguage.displayOrder {
            XCTAssertNotEqual(L10n.string("sunrise", language: language), "sunrise", "\(language)")
            XCTAssertNotEqual(L10n.string("sunset", language: language), "sunset", "\(language)")
        }
    }

    func testSceneMotionPausesWhenOverlayOrInactive() {
        XCTAssertFalse(
            MotionPolicy.shouldAnimateScene(
                windowActive: false,
                overlayPresented: false,
                systemReduceMotion: false,
                preference: .followSystem
            )
        )
        XCTAssertFalse(
            MotionPolicy.shouldAnimateScene(
                windowActive: true,
                overlayPresented: true,
                systemReduceMotion: false,
                preference: .followSystem
            )
        )
        XCTAssertTrue(
            MotionPolicy.shouldAnimateScene(
                windowActive: true,
                overlayPresented: false,
                systemReduceMotion: false,
                preference: .followSystem
            )
        )
        XCTAssertFalse(
            MotionPolicy.shouldAnimateScene(
                windowActive: true,
                overlayPresented: false,
                systemReduceMotion: true,
                preference: .followSystem
            )
        )
        XCTAssertTrue(
            MotionPolicy.shouldAnimateScene(
                windowActive: true,
                overlayPresented: false,
                systemReduceMotion: true,
                preference: .always
            )
        )
    }

    func testSolidSurfacesFollowTransparencyAndContrast() {
        XCTAssertFalse(MotionPolicy.prefersSolidSurfaces(reduceTransparency: false, increaseContrast: false))
        XCTAssertTrue(MotionPolicy.prefersSolidSurfaces(reduceTransparency: true, increaseContrast: false))
        XCTAssertTrue(MotionPolicy.prefersSolidSurfaces(reduceTransparency: false, increaseContrast: true))
    }

    func testConditionPhrasesAndChromeKeysLocalizeThroughL10n() {
        let keys = [
            "high_abbrev", "low_abbrev", "search_add_hint", "similar_temperature",
            "cond_clear", "cond_partly_cloudy", "uv_low", "aqi_good", "hide_inspector", "location_privacy"
        ]
        for key in keys {
            for language in AppLanguage.displayOrder {
                let value = L10n.string(key, language: language)
                XCTAssertFalse(value.isEmpty, "\(language) \(key)")
                XCTAssertNotEqual(value, key, "\(language) \(key)")
            }
        }
        XCTAssertEqual(WeatherCondition.clear.phrase(isDay: true), "Clear")
        XCTAssertEqual(WeatherCondition.clear.phraseKey(isDay: true), "cond_clear")
        XCTAssertEqual(WeatherCondition.clear.phrase(isDay: true, language: .japanese), "快晴")
        XCTAssertEqual(WeatherCondition.partlyCloudy.phrase(isDay: true), "Partly Cloudy")
        XCTAssertNotEqual(
            WeatherCondition.clear.phrase(isDay: true, language: .french),
            WeatherCondition.clear.phrase(isDay: true)
        )
        XCTAssertEqual(UVCategory(index: 1).title(language: .english), "Low")
        XCTAssertEqual(AQICategory(usAQI: 20).shortTitle(language: .english), "Good")
        XCTAssertEqual(AQICategory(usAQI: 140).title(language: .english), "Unhealthy for Sensitive Groups")
        XCTAssertEqual(AQICategory(usAQI: 140).shortTitle(language: .english), "Sensitive")
    }

    func testDisplayOrderIsConventionalNotRequestOrder() {
        XCTAssertEqual(
            AppLanguage.displayOrder.map(\.rawValue),
            [
                "english", "spanish", "french", "german", "italian", "portugueseBrazil",
                "dutch", "arabic", "japanese", "korean", "chineseSimplified", "chineseTraditional"
            ]
        )
    }
}
