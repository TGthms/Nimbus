import SwiftUI

@main
struct NimbusApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Nimbus", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 980, minHeight: 640)
                .preferredColorScheme(colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu(model.t("location")) {
                Button(model.t("previous_city")) { model.previousPlace() }
                    .keyboardShortcut("[", modifiers: [.command])
                Button(model.t("next_city")) { model.nextPlace() }
                    .keyboardShortcut("]", modifiers: [.command])
                Divider()
                Button(model.t("refresh")) {
                    Task { await model.refreshSelected(force: true) }
                }
                .keyboardShortcut("r", modifiers: [.command])
                Button(model.t("search_cities")) { model.focusSearch() }
                    .keyboardShortcut("f", modifiers: [.command])
            }
            CommandGroup(after: .sidebar) {
                Button(model.inspectorVisible ? model.t("hide_inspector") : model.t("show_inspector")) {
                    model.inspectorVisible.toggle()
                }
                .keyboardShortcut("i", modifiers: [.command])
            }
        }

        MenuBarExtra {
            MenuBarPanel(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model, showsDone: false)
        }
    }

    private var colorScheme: ColorScheme? {
        switch model.settings.appearance {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        case .scene:
            if let recipe = model.selectedSnapshot?.sceneRecipe {
                return recipe.isDay && recipe.solarElevation > 0 ? .light : .dark
            }
            return .dark
        }
    }
}
