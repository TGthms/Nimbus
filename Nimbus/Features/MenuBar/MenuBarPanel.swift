import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let snap = model.menuBarSnapshot()
        HStack(spacing: 4) {
            if let snap {
                Image(systemName: snap.current.condition.symbolName(isDay: snap.current.isDay))
                Text(WeatherFormatting.temperature(snap.current.temperature, unit: model.units.temperature))
                    .monospacedDigit()
            } else {
                Image(systemName: "cloud.sun")
            }
        }
    }
}

struct MenuBarPanel: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let snap = model.menuBarSnapshot() {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snap.place.displayName)
                            .font(.headline)
                        Text(snap.current.condition.phrase(isDay: snap.current.isDay, language: model.language))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(WeatherFormatting.temperature(snap.current.temperature, unit: model.units.temperature))
                        .font(.system(size: 36, weight: .medium, design: .rounded))
                }
                HStack {
                    Text("\(model.t("high_abbrev")):\(WeatherFormatting.temperature(snap.today?.temperatureMax, unit: model.units.temperature))")
                    Text("\(model.t("low_abbrev")):\(WeatherFormatting.temperature(snap.today?.temperatureMin, unit: model.units.temperature))")
                    Spacer()
                    Text(WeatherFormatting.relativeUpdated(from: snap.fetchedAt))
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
                HStack(spacing: 8) {
                    ForEach(snap.hours(limit: 6)) { hour in
                        VStack(spacing: 4) {
                            Text(WeatherFormatting.hourLabel(hour.time, timeZone: snap.timezone))
                                .font(.caption2)
                            Image(systemName: hour.condition.symbolName(isDay: hour.isDay))
                            Text(WeatherFormatting.temperature(hour.temperature, unit: model.units.temperature))
                                .font(.caption.monospacedDigit())
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                Text(model.t("waiting_forecast"))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button(model.t("open_nimbus")) {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut("o")
                Spacer()
                Button(model.t("refresh")) {
                    Task { await model.refreshSelected(force: true) }
                }
            }
        }
        .padding(16)
        .frame(width: 360)
    }
}
