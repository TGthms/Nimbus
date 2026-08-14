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
            CommandMenu("Location") {
                Button("Previous City") { model.previousPlace() }
                    .keyboardShortcut("[", modifiers: [.command])
                Button("Next City") { model.nextPlace() }
                    .keyboardShortcut("]", modifiers: [.command])
                Divider()
                Button("Refresh") {
                    Task { await model.refreshSelected(force: true) }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
            CommandGroup(after: .sidebar) {
                Button(model.inspectorVisible ? "Hide Inspector" : "Show Inspector") {
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
