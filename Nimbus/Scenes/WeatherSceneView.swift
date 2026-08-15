import SwiftUI

struct WeatherSceneView: View {
    var recipe: SceneRecipe
    var isActive: Bool = true
    var overlayPresented: Bool = false
    var motionPreference: MotionPreference = .followSystem

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var animate: Bool {
        MotionPolicy.shouldAnimateScene(
            windowActive: isActive,
            overlayPresented: overlayPresented,
            systemReduceMotion: reduceMotion,
            preference: motionPreference
        )
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: animate ? 1.0 / 8.0 : 120, paused: !animate)) { timeline in
            Canvas { context, size in
                SceneCompositor.draw(
                    context: &context,
                    size: size,
                    recipe: recipe,
                    time: animate ? timeline.date.timeIntervalSinceReferenceDate : 0,
                    reduceMotion: !animate
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

enum SceneCompositor {
    static func draw(context: inout GraphicsContext, size: CGSize, recipe: SceneRecipe, time: TimeInterval, reduceMotion: Bool) {
        let colors = NimbusTheme.skyColors(recipe: recipe)
        let sky = Gradient(colors: colors)
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(sky, startPoint: CGPoint(x: size.width / 2, y: 0), endPoint: CGPoint(x: size.width / 2, y: size.height))
        )

        drawGlow(context: &context, size: size, recipe: recipe)
        if recipe.solarElevation > -6 {
            drawSun(context: &context, size: size, recipe: recipe)
            if !reduceMotion && recipe.cloudCover < 0.55 {
                drawSunRays(context: &context, size: size, recipe: recipe, time: time)
            }
        } else {
            if !reduceMotion || recipe.cloudCover < 0.7 {
                drawStars(context: &context, size: size, recipe: recipe, time: time, reduceMotion: reduceMotion)
            }
            drawMoon(context: &context, size: size, recipe: recipe)
        }

        drawCloudDeck(context: &context, size: size, cover: recipe.cloudHigh, y: size.height * 0.12, scale: 1.35, alpha: 0.28, time: time, recipe: recipe, speed: 8, reduceMotion: reduceMotion)
        drawCloudDeck(context: &context, size: size, cover: max(recipe.cloudMid, recipe.cloudCover * 0.45), y: size.height * 0.22, scale: 1.15, alpha: 0.38, time: time, recipe: recipe, speed: 14, reduceMotion: reduceMotion)
        drawCloudDeck(context: &context, size: size, cover: max(recipe.cloudLow, recipe.cloudCover * 0.7), y: size.height * 0.34, scale: 1.0, alpha: 0.5, time: time, recipe: recipe, speed: 22, reduceMotion: reduceMotion)

        if recipe.condition.isFog || recipe.visibility < 2500 {
            drawFog(context: &context, size: size, recipe: recipe, time: time, reduceMotion: reduceMotion)
        }

        if recipe.precipRate > 0.05 && !reduceMotion {
            if recipe.isSnow {
                drawSnow(context: &context, size: size, recipe: recipe, time: time)
            } else {
                drawRain(context: &context, size: size, recipe: recipe, time: time)
            }
        } else if recipe.precipRate > 0.05 {
            drawStaticPrecipHint(context: &context, size: size, recipe: recipe)
        }

        if recipe.lightning && !reduceMotion {
            drawLightning(context: &context, size: size, time: time)
        }

        if recipe.aqiHaze > 0.05 {
            var haze = context
            haze.opacity = recipe.aqiHaze * 0.28
            haze.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(red: 0.62, green: 0.52, blue: 0.38))
            )
        }

        // Horizon wash for type contrast
        let wash = Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(recipe.isDay ? 0.10 : 0.28)])
        context.fill(
            Path(CGRect(x: 0, y: size.height * 0.55, width: size.width, height: size.height * 0.45)),
            with: .linearGradient(wash, startPoint: CGPoint(x: size.width / 2, y: size.height * 0.55), endPoint: CGPoint(x: size.width / 2, y: size.height))
        )
    }

    private static func drawGlow(context: inout GraphicsContext, size: CGSize, recipe: SceneRecipe) {
        let elev = recipe.solarElevation
        guard elev > -10 else { return }
        let t = SolarMath.smoothstep(-8, 18, elev)
        let sunPoint = sunPoint(size: size, recipe: recipe)
        let radius = size.width * (0.35 + 0.15 * t)
        let glowColor = elev < 8
            ? Color(red: 1.0, green: 0.55, blue: 0.28).opacity(0.35)
            : Color(red: 1.0, green: 0.92, blue: 0.65).opacity(0.28)
        context.fill(
            Path(ellipseIn: CGRect(x: sunPoint.x - radius, y: sunPoint.y - radius, width: radius * 2, height: radius * 2)),
            with: .radialGradient(Gradient(colors: [glowColor, .clear]), center: sunPoint, startRadius: 4, endRadius: radius)
        )
    }

    private static func sunPoint(size: CGSize, recipe: SceneRecipe) -> CGPoint {
        let elev = max(-10, min(80, recipe.solarElevation))
        let y = size.height * (0.72 - SolarMath.smoothstep(-6, 55, elev) * 0.52)
        let az = recipe.windDirection // not solar azimuth; compute from elevation only for a pleasing path
        let xFrac = 0.22 + SolarMath.smoothstep(-10, 60, elev) * 0.46
        _ = az
        return CGPoint(x: size.width * xFrac, y: y)
    }

    private static func drawSunRays(context: inout GraphicsContext, size: CGSize, recipe: SceneRecipe, time: TimeInterval) {
        let p = sunPoint(size: size, recipe: recipe)
        let spin = time * 0.04
        let count = 8
        for i in 0..<count {
            let angle = Double(i) / Double(count) * .pi * 2 + spin
            var path = Path()
            path.move(to: p)
            let reach = size.width * 0.42
            path.addLine(to: CGPoint(x: p.x + cos(angle) * reach, y: p.y + sin(angle) * reach))
            context.stroke(path, with: .color(Color.white.opacity(0.05)), lineWidth: 18)
        }
    }

    private static func drawSun(context: inout GraphicsContext, size: CGSize, recipe: SceneRecipe) {
        let p = sunPoint(size: size, recipe: recipe)
        let r: CGFloat = recipe.solarElevation < 8 ? 26 : 22
        let core = recipe.solarElevation < 8 ? Color(red: 1, green: 0.72, blue: 0.32) : Color(red: 1, green: 0.95, blue: 0.78)
        context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(core))
        context.fill(
            Path(ellipseIn: CGRect(x: p.x - r * 2.4, y: p.y - r * 2.4, width: r * 4.8, height: r * 4.8)),
            with: .radialGradient(Gradient(colors: [core.opacity(0.45), .clear]), center: p, startRadius: r, endRadius: r * 2.6)
        )
    }

    private static func drawMoon(context: inout GraphicsContext, size: CGSize, recipe: SceneRecipe) {
        let p = CGPoint(x: size.width * 0.72, y: size.height * 0.18)
        let r: CGFloat = 18
        context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(Color(red: 0.92, green: 0.93, blue: 0.88)))
        // Crescent cut for less-than-full
        if recipe.moonIllumination < 0.92 {
            let offset = (0.5 - recipe.moonIllumination) * 22
            var cut = context
            cut.blendMode = .destinationOut
            cut.fill(
                Path(ellipseIn: CGRect(x: p.x - r + offset, y: p.y - r, width: r * 2, height: r * 2)),
                with: .color(.black)
            )
        }
    }

    private static let cachedStars: [StarSpec] = {
        var rng = SplitGenerator(seed: 77)
        return (0..<36).map { _ in
            StarSpec(
                x: rng.next(),
                y: rng.next() * 0.62,
                size: 0.6 + rng.next() * 1.3,
                phase: rng.next() * .pi * 2,
                speed: 0.45 + rng.next() * 0.5
            )
        }
    }()

    private static func drawStars(context: inout GraphicsContext, size: CGSize, recipe: SceneRecipe, time: TimeInterval, reduceMotion: Bool) {
        let dim = 1 - recipe.cloudCover * 0.7
        guard dim > 0.05 else { return }
        let visible = Int(Double(cachedStars.count) * (1 - recipe.cloudCover * 0.85))
        for i in 0..<visible {
            let star = cachedStars[i]
            let twinkle = reduceMotion ? 1.0 : 0.7 + 0.3 * sin(time * star.speed + star.phase)
            context.opacity = twinkle * dim
            let s = star.size
            context.fill(
                Path(ellipseIn: CGRect(x: star.x * size.width, y: star.y * size.height, width: s, height: s)),
                with: .color(.white)
            )
        }
        context.opacity = 1
    }

    private static func drawCloudDeck(
        context: inout GraphicsContext,
        size: CGSize,
        cover: Double,
        y: CGFloat,
        scale: CGFloat,
        alpha: Double,
        time: TimeInterval,
        recipe: SceneRecipe,
        speed: Double,
        reduceMotion: Bool
    ) {
        guard cover > 0.04 else { return }
        let count = Int(2 + cover * 5)
        let wind = recipe.windSpeed
        let drift = reduceMotion ? 0 : time * (speed + wind * 0.15)
        var rng = SplitGenerator(seed: UInt64(y * 13))
        for i in 0..<count {
            let baseX = rng.next() * (size.width + 240) - 120
            let x = CGFloat((Double(baseX) + drift).truncatingRemainder(dividingBy: Double(size.width + 260))) - 130
            let cy = y + CGFloat(rng.next() * 36 - 10)
            let w = (140 + rng.next() * 180) * scale
            let h = (36 + rng.next() * 28) * scale
            let puff = Path(ellipseIn: CGRect(x: x, y: cy, width: w, height: h))
            let color = recipe.isDay
                ? Color.white.opacity(alpha * (0.45 + cover * 0.55))
                : Color.white.opacity(alpha * 0.18)
            context.fill(puff, with: .color(color))
            context.fill(Path(ellipseIn: CGRect(x: x + w * 0.22, y: cy - h * 0.45, width: w * 0.46, height: h * 0.9)), with: .color(color))
            _ = i
        }
    }

    private static func drawRain(context: inout GraphicsContext, size: CGSize, recipe: SceneRecipe, time: TimeInterval) {
        let count = Int(10 + min(recipe.precipRate, 2) * 12)
        let shear = CGFloat(sin(recipe.windDirection * .pi / 180) * min(recipe.windSpeed, 40) * 0.6)
        var rng = SplitGenerator(seed: 3)
        for i in 0..<count {
            let speed = 380.0 + rng.next() * 220
            let x0 = rng.next() * (size.width + 80) - 40
            let y0 = (rng.next() * size.height + time * speed).truncatingRemainder(dividingBy: Double(size.height + 40))
            let x = x0 + Double(shear) * (y0 / Double(size.height))
            var path = Path()
            path.move(to: CGPoint(x: x, y: y0))
            path.addLine(to: CGPoint(x: x + Double(shear) * 0.08, y: y0 + 12 + rng.next() * 8))
            context.stroke(path, with: .color(Color.white.opacity(0.28 + recipe.precipRate * 0.08)), lineWidth: 1)
            _ = i
        }
    }

    private static func drawSnow(context: inout GraphicsContext, size: CGSize, recipe: SceneRecipe, time: TimeInterval) {
        let count = Int(10 + min(recipe.precipRate, 2) * 10)
        var rng = SplitGenerator(seed: 9)
        for i in 0..<count {
            let speed = 40.0 + rng.next() * 50
            let sway = sin(time * 0.8 + Double(i)) * 16
            let x = (rng.next() * size.width + sway).truncatingRemainder(dividingBy: size.width)
            let y = (rng.next() * size.height + time * speed).truncatingRemainder(dividingBy: Double(size.height))
            let s = 1.4 + rng.next() * 2.4
            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)), with: .color(Color.white.opacity(0.85)))
        }
    }

    private static func drawStaticPrecipHint(context: inout GraphicsContext, size: CGSize, recipe: SceneRecipe) {
        context.opacity = 0.18
        context.fill(
            Path(CGRect(x: 0, y: size.height * 0.35, width: size.width, height: size.height * 0.65)),
            with: .linearGradient(
                Gradient(colors: [Color.clear, (recipe.isSnow ? Color.white : Color(red: 0.7, green: 0.8, blue: 0.9)).opacity(0.35)]),
                startPoint: CGPoint(x: size.width / 2, y: size.height * 0.35),
                endPoint: CGPoint(x: size.width / 2, y: size.height)
            )
        )
        context.opacity = 1
    }

    private static func drawFog(context: inout GraphicsContext, size: CGSize, recipe: SceneRecipe, time: TimeInterval, reduceMotion: Bool) {
        let strength = recipe.condition.isFog ? 0.55 : max(0, 1 - recipe.visibility / 4000)
        for i in 0..<4 {
            let offset = reduceMotion ? 0 : sin(time * 0.12 + Double(i)) * 18
            let y = size.height * (0.45 + CGFloat(i) * 0.12)
            context.fill(
                Path(ellipseIn: CGRect(x: -80 + offset, y: y, width: size.width + 160, height: 90)),
                with: .color(Color.white.opacity(0.10 + strength * 0.12))
            )
        }
    }

    private static func drawLightning(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let pulse = time.truncatingRemainder(dividingBy: 7)
        guard pulse < 0.18 || (pulse > 0.28 && pulse < 0.36) else { return }
        let flash = pulse < 0.18 ? (0.18 - pulse) / 0.18 : (0.36 - pulse) / 0.08
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.white.opacity(0.18 * flash)))
        var bolt = Path()
        let x = size.width * 0.62
        bolt.move(to: CGPoint(x: x, y: size.height * 0.08))
        bolt.addLine(to: CGPoint(x: x - 18, y: size.height * 0.22))
        bolt.addLine(to: CGPoint(x: x + 6, y: size.height * 0.24))
        bolt.addLine(to: CGPoint(x: x - 22, y: size.height * 0.46))
        context.stroke(bolt, with: .color(Color.white.opacity(0.85 * flash)), lineWidth: 2)
    }
}

private struct StarSpec {
    var x: Double
    var y: Double
    var size: CGFloat
    var phase: Double
    var speed: Double
}

struct SplitGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z = z ^ (z >> 31)
        return Double(z % 10_000) / 10_000
    }
}
