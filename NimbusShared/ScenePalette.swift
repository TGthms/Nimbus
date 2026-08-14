import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

public enum ScenePalette {
    public static func colors(recipe: SceneRecipe) -> [Color] {
        let storm = recipe.lightning ? 0.55 : 0.0
        let overcast = recipe.cloudCover
        let snow = recipe.isSnow ? 0.35 : 0.0
        let day = SolarMath.daylightFactor(elevationDegrees: recipe.solarElevation)

        let nightTop = Color(red: 0.04, green: 0.06, blue: 0.16)
        let nightBottom = Color(red: 0.08, green: 0.10, blue: 0.22)
        let dawnTop = Color(red: 0.35, green: 0.32, blue: 0.62)
        let dawnBottom = Color(red: 0.96, green: 0.62, blue: 0.42)
        let dayTop = Color(red: 0.23, green: 0.52, blue: 0.90)
        let dayBottom = Color(red: 0.62, green: 0.80, blue: 0.96)
        let noonTop = Color(red: 0.18, green: 0.45, blue: 0.88)
        let noonBottom = Color(red: 0.55, green: 0.78, blue: 0.96)
        let duskTop = Color(red: 0.22, green: 0.16, blue: 0.38)
        let duskBottom = Color(red: 0.86, green: 0.38, blue: 0.28)
        let cloudGray = Color(red: 0.42, green: 0.48, blue: 0.56)
        let stormGray = Color(red: 0.14, green: 0.16, blue: 0.22)
        let snowTop = Color(red: 0.62, green: 0.70, blue: 0.80)
        let snowBottom = Color(red: 0.86, green: 0.90, blue: 0.94)

        let elev = recipe.solarElevation
        var clearTop: Color
        var clearBottom: Color
        if elev < -8 {
            clearTop = nightTop
            clearBottom = nightBottom
        } else if elev < 4 {
            let t = SolarMath.smoothstep(-8, 4, elev)
            if elev < -1 {
                clearTop = blend(nightTop, dawnTop, t: t)
                clearBottom = blend(nightBottom, dawnBottom, t: t)
            } else {
                clearTop = blend(dawnTop, dayTop, t: SolarMath.smoothstep(-1, 8, elev))
                clearBottom = blend(dawnBottom, dayBottom, t: SolarMath.smoothstep(-1, 8, elev))
            }
        } else if elev > 40 {
            clearTop = noonTop
            clearBottom = noonBottom
        } else {
            clearTop = dayTop
            clearBottom = dayBottom
        }

        let duskMix = elev > 0 && elev < 8 ? (8 - elev) / 8 : 0
        var top = blend(clearTop, duskTop, t: duskMix * (1 - overcast * 0.5))
        var bottom = blend(clearBottom, duskBottom, t: duskMix * (1 - overcast * 0.5))
        top = blend(top, cloudGray, t: overcast * 0.55 * day)
        bottom = blend(bottom, cloudGray.opacity(0.85), t: overcast * 0.4 * day)
        top = blend(top, stormGray, t: storm)
        bottom = blend(bottom, stormGray, t: storm * 0.8)
        top = blend(top, snowTop, t: snow * day)
        bottom = blend(bottom, snowBottom, t: snow * day)
        return [top, bottom]
    }

    public static func blend(_ a: Color, _ b: Color, t: Double) -> Color {
        let t = min(1, max(0, t))
        #if canImport(AppKit)
        let ac = NSColor(a).usingColorSpace(.sRGB) ?? .white
        let bc = NSColor(b).usingColorSpace(.sRGB) ?? .white
        return Color(
            red: ac.redComponent * (1 - t) + bc.redComponent * t,
            green: ac.greenComponent * (1 - t) + bc.greenComponent * t,
            blue: ac.blueComponent * (1 - t) + bc.blueComponent * t
        )
        #else
        return t < 0.5 ? a : b
        #endif
    }
}
