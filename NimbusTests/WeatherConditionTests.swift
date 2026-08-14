import XCTest
@testable import NimbusShared

final class WeatherConditionTests: XCTestCase {
    func testOfficialWMOCodesRoundTrip() {
        let codes = [0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99]
        for code in codes {
            let condition = WeatherCondition(wmoCode: code)
            XCTAssertNotEqual(condition, .unknown, "WMO \(code) should be mapped")
            XCTAssertEqual(condition.wmoCode, code)
            XCTAssertFalse(condition.phrase(isDay: true).isEmpty)
            XCTAssertFalse(condition.symbolName(isDay: true).isEmpty)
        }
    }

    func testUnknownCode() {
        XCTAssertEqual(WeatherCondition(wmoCode: 1234), .unknown)
        XCTAssertEqual(WeatherCondition.unknown.phrase(isDay: true), "—")
    }

    func testClassification() {
        XCTAssertTrue(WeatherCondition(wmoCode: 63).isPrecipitation)
        XCTAssertTrue(WeatherCondition(wmoCode: 75).isSnow)
        XCTAssertTrue(WeatherCondition(wmoCode: 95).isThunder)
        XCTAssertTrue(WeatherCondition(wmoCode: 45).isFog)
        XCTAssertFalse(WeatherCondition(wmoCode: 0).isPrecipitation)
        XCTAssertGreaterThan(WeatherCondition(wmoCode: 65).precipIntensity, WeatherCondition(wmoCode: 61).precipIntensity)
    }

    func testUVAndAQICategories() {
        XCTAssertEqual(UVCategory(index: 1).title, "Low")
        XCTAssertEqual(UVCategory(index: 5).title, "Moderate")
        XCTAssertEqual(UVCategory(index: 7).title, "High")
        XCTAssertEqual(UVCategory(index: 10).title, "Very High")
        XCTAssertEqual(UVCategory(index: 12).title, "Extreme")
        XCTAssertEqual(AQICategory(usAQI: 20).shortTitle, "Good")
        XCTAssertEqual(AQICategory(usAQI: 80).shortTitle, "Moderate")
        XCTAssertEqual(AQICategory(usAQI: 160).shortTitle, "Unhealthy")
        XCTAssertEqual(AQICategory(usAQI: 320).shortTitle, "Hazardous")
    }
}
