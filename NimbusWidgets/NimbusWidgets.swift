import WidgetKit
import SwiftUI

struct WeatherEntry: TimelineEntry, Sendable {
    var date: Date
    var placeName: String
    var temperature: Double?
    var high: Double?
    var low: Double?
    var condition: WeatherCondition
    var isDay: Bool
    var hours: [HourSlot]
    var days: [DaySlot]
    var units: UnitPreferences
    var recipe: SceneRecipe?
}

struct HourSlot: Identifiable, Hashable, Sendable {
    var timeLabel: String
    var temperature: Double?
    var symbol: String
    var id: String { timeLabel }
}

struct DaySlot: Identifiable, Hashable, Sendable {
    var weekday: String
    var high: Double?
    var low: Double?
    var symbol: String
    var id: String { weekday }
}

struct SnapshotProvider: TimelineProvider, Sendable {
    func placeholder(in context: Context) -> WeatherEntry {
        Self.demoEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (WeatherEntry) -> Void) {
        Task {
            let entry = await Self.loadEntry() ?? Self.demoEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<WeatherEntry>) -> Void) {
        Task {
            let entry = await Self.loadEntry() ?? Self.demoEntry()
            let next = Date().addingTimeInterval(20 * 60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private static func loadEntry() async -> WeatherEntry? {
        let store = WeatherStore()
        let settings = await store.loadSettings()
        if let selected = settings.selectedPlaceID, let snap = await store.loadSnapshot(id: selected) {
            return Self.entry(from: snap, units: settings.units)
        }
        if let snap = await store.latestSnapshot() {
            return Self.entry(from: snap, units: settings.units)
        }
        let places = await store.loadPlaces()
        let fallback = places.first(where: { !$0.isCurrentLocation }) ?? PopularCities.seeds[0]
        do {
            let snap = try await OpenMeteoClient().forecastOnly(for: fallback, units: settings.units)
            await store.saveSnapshot(snap)
            return Self.entry(from: snap, units: settings.units)
        } catch {
            return nil
        }
    }

    static func entry(from snap: WeatherSnapshot, units: UnitPreferences) -> WeatherEntry {
        let hours = snap.hours(limit: 6).map {
            HourSlot(
                timeLabel: WeatherFormatting.hourLabel($0.time, timeZone: snap.timezone),
                temperature: $0.temperature,
                symbol: $0.condition.symbolName(isDay: $0.isDay)
            )
        }
        let days = snap.daily.prefix(7).map {
            DaySlot(
                weekday: WeatherFormatting.weekday($0.date, timeZone: snap.timezone),
                high: $0.temperatureMax,
                low: $0.temperatureMin,
                symbol: $0.condition.symbolName(isDay: true)
            )
        }
        return WeatherEntry(
            date: Date(),
            placeName: snap.place.displayName == "My Location" ? snap.place.name : snap.place.displayName,
            temperature: snap.current.temperature,
            high: snap.today?.temperatureMax,
            low: snap.today?.temperatureMin,
            condition: snap.current.condition,
            isDay: snap.current.isDay,
            hours: hours,
            days: Array(days),
            units: units,
            recipe: snap.sceneRecipe
        )
    }

    private static func demoEntry() -> WeatherEntry {
        WeatherEntry(
            date: Date(),
            placeName: "Tokyo",
            temperature: 22,
            high: 26,
            low: 18,
            condition: .partlyCloudy,
            isDay: true,
            hours: [
                HourSlot(timeLabel: "Now", temperature: 22, symbol: "cloud.sun.fill"),
                HourSlot(timeLabel: "2pm", temperature: 23, symbol: "sun.max.fill"),
                HourSlot(timeLabel: "3pm", temperature: 23, symbol: "sun.max.fill")
            ],
            days: [
                DaySlot(weekday: "Today", high: 26, low: 18, symbol: "cloud.sun.fill"),
                DaySlot(weekday: "Tomorrow", high: 24, low: 17, symbol: "cloud.rain.fill")
            ],
            units: .fromLocale(),
            recipe: nil
        )
    }
}

struct WeatherWidgetView: View {
    var entry: WeatherEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        ZStack {
            background
            switch family {
            case .systemSmall: small
            case .systemLarge: large
            default: medium
            }
        }
        .containerBackground(for: .widget) { background }
    }

    private var background: some View {
        LinearGradient(
            colors: entry.recipe.map { ScenePalette.colors(recipe: $0) } ?? [
                Color(red: 0.20, green: 0.46, blue: 0.82),
                Color(red: 0.55, green: 0.74, blue: 0.92)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.placeName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Image(systemName: entry.condition.symbolName(isDay: entry.isDay))
                .font(.title2)
            Spacer(minLength: 0)
            Text(WeatherFormatting.temperature(entry.temperature, unit: entry.units.temperature))
                .font(.system(size: 32, weight: .medium, design: .rounded))
            Text("H:\(WeatherFormatting.temperature(entry.high, unit: entry.units.temperature)) L:\(WeatherFormatting.temperature(entry.low, unit: entry.units.temperature))")
                .font(.caption2)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(4)
    }

    private var medium: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(entry.placeName).font(.headline)
                Text(entry.condition.phrase(isDay: entry.isDay)).font(.caption).opacity(0.85)
                Text(WeatherFormatting.temperature(entry.temperature, unit: entry.units.temperature))
                    .font(.system(size: 36, weight: .medium, design: .rounded))
            }
            Spacer()
            HStack(spacing: 8) {
                ForEach(entry.hours.prefix(5)) { hour in
                    VStack(spacing: 4) {
                        Text(hour.timeLabel).font(.caption2)
                        Image(systemName: hour.symbol)
                        Text(WeatherFormatting.temperature(hour.temperature, unit: entry.units.temperature))
                            .font(.caption.monospacedDigit())
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding(4)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            medium
            VStack(spacing: 4) {
                ForEach(entry.days.prefix(7)) { day in
                    HStack {
                        Text(day.weekday).frame(width: 90, alignment: .leading)
                        Image(systemName: day.symbol)
                        Spacer()
                        Text(WeatherFormatting.temperature(day.low, unit: entry.units.temperature)).opacity(0.7)
                        Text(WeatherFormatting.temperature(day.high, unit: entry.units.temperature)).fontWeight(.semibold)
                    }
                    .font(.caption)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(6)
    }
}

@main
struct NimbusWidgets: WidgetBundle {
    var body: some Widget {
        NimbusWeatherWidget()
    }
}

struct NimbusWeatherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "app.nimbus.mac.widget", provider: SnapshotProvider()) { entry in
            WeatherWidgetView(entry: entry)
        }
        .configurationDisplayName("Nimbus")
        .description("Current conditions, hourly, and the week ahead.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
