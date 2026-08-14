import Foundation

/// NOAA-style solar position, sufficient for sky grading and a sun disc.
public enum SolarMath {
    /// Elevation in degrees. Negative is below the horizon.
    public static func solarElevation(latitude: Double, longitude: Double, date: Date) -> Double {
        let position = solarPosition(latitude: latitude, longitude: longitude, date: date)
        return position.elevation
    }

    public static func solarPosition(latitude: Double, longitude: Double, date: Date) -> (azimuth: Double, elevation: Double) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = Double(comps.year ?? 2000)
        let month = Double(comps.month ?? 1)
        let day = Double(comps.day ?? 1)
        let hour = Double(comps.hour ?? 0)
        let minute = Double(comps.minute ?? 0)
        let second = Double(comps.second ?? 0)

        let dayOfYear = julianDay(year: year, month: month, day: day) - julianDay(year: year, month: 1, day: 1) + 1
        let minutes = hour * 60 + minute + second / 60
        let gamma = (2 * .pi / 365.0) * (dayOfYear - 1 + (minutes / 60 - 12) / 24)

        let eqTime = 229.18 * (0.000075
            + 0.001868 * cos(gamma)
            - 0.032077 * sin(gamma)
            - 0.014615 * cos(2 * gamma)
            - 0.040849 * sin(2 * gamma))

        let decl = 0.006918
            - 0.399912 * cos(gamma)
            + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma)
            + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma)
            + 0.00148 * sin(3 * gamma)

        let timeOffset = eqTime + 4 * longitude
        var trueSolarTime = minutes + timeOffset
        trueSolarTime = trueSolarTime.truncatingRemainder(dividingBy: 1440)
        if trueSolarTime < 0 { trueSolarTime += 1440 }

        var hourAngle = trueSolarTime / 4 - 180
        if hourAngle < -180 { hourAngle += 360 }

        let latR = latitude * .pi / 180
        let haR = hourAngle * .pi / 180
        let cosZenith = sin(latR) * sin(decl) + cos(latR) * cos(decl) * cos(haR)
        let zenith = acos(min(1, max(-1, cosZenith)))
        let elevation = 90 - zenith * 180 / .pi

        let denom = cos(latR) * sin(zenith)
        var azimuth: Double
        if abs(denom) > 1e-8 {
            var az = acos(min(1, max(-1, (sin(latR) * cos(zenith) - sin(decl)) / denom)))
            if hourAngle > 0 { az = 2 * .pi - az }
            azimuth = az * 180 / .pi
        } else {
            azimuth = hourAngle > 0 ? 180 : 0
        }

        return (azimuth, elevation)
    }

    /// 0 night … 0.5 twilight … 1 full day. Smooth.
    public static func daylightFactor(elevationDegrees: Double) -> Double {
        // Civil twilight ~ -6°, nautical ~ -12°.
        let t = (elevationDegrees + 8) / 16
        return smoothstep(0, 1, t)
    }

    public static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = min(1, max(0, (x - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }

    private static func julianDay(year: Double, month: Double, day: Double) -> Double {
        var y = year
        var m = month
        if m <= 2 {
            y -= 1
            m += 12
        }
        let a = floor(y / 100)
        let b = 2 - a + floor(a / 4)
        return floor(365.25 * (y + 4716)) + floor(30.6001 * (m + 1)) + day + b - 1524.5
    }
}

public enum MoonMath {
    /// Approximate illumination 0...1 and a coarse phase name.
    public static func phase(on date: Date) -> (illumination: Double, name: String, ageDays: Double) {
        let synodic = 29.53058867
        let knownNew = Date(timeIntervalSince1970: 592_500_000) // 1988-10-11-ish reference is fine; use a well-known new moon
        // 2000-01-06 18:14 UTC new moon
        var comps = DateComponents()
        comps.year = 2000
        comps.month = 1
        comps.day = 6
        comps.hour = 18
        comps.minute = 14
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        let ref = Calendar(identifier: .gregorian).date(from: comps) ?? knownNew
        let age = date.timeIntervalSince(ref) / 86400
        let cycle = age.truncatingRemainder(dividingBy: synodic)
        let positive = cycle < 0 ? cycle + synodic : cycle
        let illumination = 0.5 * (1 - cos(2 * .pi * positive / synodic))
        let name: String
        switch positive {
        case ..<1.0: name = "New Moon"
        case ..<6.4: name = "Waxing Crescent"
        case ..<8.4: name = "First Quarter"
        case ..<13.8: name = "Waxing Gibbous"
        case ..<15.8: name = "Full Moon"
        case ..<21.2: name = "Waning Gibbous"
        case ..<23.2: name = "Last Quarter"
        default: name = "Waning Crescent"
        }
        return (illumination, name, positive)
    }
}
