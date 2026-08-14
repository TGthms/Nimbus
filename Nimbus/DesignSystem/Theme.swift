import SwiftUI

enum NimbusTheme {
    static let sidebarWidth: CGFloat = 268
    static let inspectorWidth: CGFloat = 380
    static let moduleRadius: CGFloat = 18
    static let heroSpring = Animation.spring(response: 0.38, dampingFraction: 1.0)
    static let panelSpring = Animation.spring(response: 0.34, dampingFraction: 1.0)
    static let sceneSpring = Animation.spring(response: 0.8, dampingFraction: 1.0)

    static func uiAnimation(systemReduceMotion: Bool, preference: MotionPreference) -> Animation {
        MotionPolicy.allowsDynamicMotion(systemReduceMotion: systemReduceMotion, preference: preference)
            ? panelSpring
            : .easeOut(duration: 0.12)
    }

    static func placeAnimation(systemReduceMotion: Bool, preference: MotionPreference) -> Animation {
        MotionPolicy.allowsDynamicMotion(systemReduceMotion: systemReduceMotion, preference: preference)
            ? heroSpring
            : .easeOut(duration: 0.12)
    }

    static func skyColors(recipe: SceneRecipe) -> [Color] {
        ScenePalette.colors(recipe: recipe)
    }

    static func blend(_ a: Color, _ b: Color, t: Double) -> Color {
        ScenePalette.blend(a, b, t: t)
    }

    static func heroPrimary(recipe: SceneRecipe) -> Color {
        recipe.isDay && recipe.solarElevation > 4 && !recipe.lightning ? Color.black.opacity(0.82) : Color.white
    }

    static func heroSecondary(recipe: SceneRecipe) -> Color {
        heroPrimary(recipe: recipe).opacity(0.72)
    }
}

struct GlassBackground: ViewModifier {
    var material: Material = .ultraThinMaterial
    var radius: CGFloat = NimbusTheme.moduleRadius

    func body(content: Content) -> some View {
        content
            .background(material, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
    }
}

extension View {
    func nimbusGlass(_ material: Material = .ultraThinMaterial, radius: CGFloat = NimbusTheme.moduleRadius) -> some View {
        modifier(GlassBackground(material: material, radius: radius))
    }
}

struct ScalePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
