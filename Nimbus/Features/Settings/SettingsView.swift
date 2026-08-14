import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var showsDone: Bool = true
    @Environment(\.dismiss) private var dismiss

    private var lang: AppLanguage { model.language }

    var body: some View {
        NavigationStack {
            Form {
                Section(model.t("language")) {
                    Picker(model.t("language"), selection: $model.settings.language) {
                        Text(model.t("language_system")).tag(AppLanguage.system)
                        ForEach(AppLanguage.displayOrder) { language in
                            Text(language.nativeName).tag(language)
                        }
                    }
                }

                Section(model.t("units")) {
                    Toggle(model.t("follow_locale"), isOn: localeBinding)
                    Picker(model.t("temperature"), selection: unitBinding(\.temperature)) {
                        ForEach(TemperatureUnit.allCases) { Text($0.title).tag($0) }
                    }
                    .disabled(model.settings.units.followLocale)
                    Picker(model.t("wind"), selection: unitBinding(\.wind)) {
                        ForEach(WindSpeedUnit.allCases) { Text($0.title).tag($0) }
                    }
                    .disabled(model.settings.units.followLocale)
                    Picker(model.t("precipitation"), selection: unitBinding(\.precipitation)) {
                        ForEach(PrecipitationUnit.allCases) { Text($0.title).tag($0) }
                    }
                    .disabled(model.settings.units.followLocale)
                }

                Section(model.t("appearance")) {
                    Picker(model.t("chrome"), selection: $model.settings.appearance) {
                        Text(model.t("follow_scene")).tag(AppSettings.AppearanceMode.scene)
                        Text(model.t("system")).tag(AppSettings.AppearanceMode.system)
                        Text(model.t("light")).tag(AppSettings.AppearanceMode.light)
                        Text(model.t("dark")).tag(AppSettings.AppearanceMode.dark)
                    }
                    Toggle(model.t("grade_sun"), isOn: $model.settings.followPlaceSun)
                }

                Section(model.t("motion")) {
                    Picker(model.t("motion"), selection: $model.settings.motion) {
                        ForEach(MotionPreference.allCases) { pref in
                            Text(L10n.string(pref.localizationKey, language: lang)).tag(pref)
                        }
                    }
                }

                Section(model.t("menu_bar")) {
                    Picker(model.t("shows"), selection: menuPlaceBinding) {
                        Text(model.t("selected_city")).tag(UUID?.none)
                        ForEach(model.places) { place in
                            Text(place.isCurrentLocation ? model.t("my_location") : place.displayName)
                                .tag(Optional(place.id))
                        }
                    }
                }

                Section(model.t("data")) {
                    Text(model.t("data_blurb"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Link("Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(model.t("settings"))
            .toolbar {
                if showsDone {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(model.t("done")) {
                            Task { await model.persist() }
                            dismiss()
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
            }
        }
        .frame(minWidth: 440, minHeight: 520)
        .preferredColorScheme(nil)
        .onChange(of: model.settings) { _, _ in
            Task { await model.persist() }
        }
    }

    private var localeBinding: Binding<Bool> {
        Binding(
            get: { model.settings.units.followLocale },
            set: { follow in
                if follow {
                    model.applyUnits(.fromLocale())
                } else {
                    var units = model.settings.units
                    units.followLocale = false
                    model.applyUnits(units)
                }
            }
        )
    }

    private func unitBinding<T: Equatable>(_ keyPath: WritableKeyPath<UnitPreferences, T>) -> Binding<T> {
        Binding(
            get: { model.units[keyPath: keyPath] },
            set: { value in
                var units = model.settings.units
                units.followLocale = false
                units[keyPath: keyPath] = value
                model.applyUnits(units)
            }
        )
    }

    private var menuPlaceBinding: Binding<UUID?> {
        Binding(
            get: { model.settings.menuBarPlaceID },
            set: { model.settings.menuBarPlaceID = $0 }
        )
    }
}
