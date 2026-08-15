import SwiftUI

struct HeroView: View {
    var snapshot: WeatherSnapshot
    var units: UnitPreferences
    var recipe: SceneRecipe
    var language: AppLanguage = .english

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snapshot.place.isCurrentLocation ? L10n.string("my_location", language: language) : snapshot.place.name)
                .font(.system(size: 34, weight: .semibold, design: .default))
                .tracking(-0.4)
            Text(snapshot.current.condition.phrase(isDay: snapshot.current.isDay, language: language))
                .font(.title3.weight(.medium))
                .opacity(0.86)
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(WeatherFormatting.temperature(snapshot.current.temperature, unit: units.temperature))
                    .font(.system(size: 96, weight: .medium, design: .rounded))
                    .tracking(-4)
                    .minimumScaleFactor(0.5)
                VStack(alignment: .leading, spacing: 4) {
                    if let today = snapshot.today {
                        Text("\(L10n.string("high_abbrev", language: language)):\(WeatherFormatting.temperature(today.temperatureMax, unit: units.temperature))  \(L10n.string("low_abbrev", language: language)):\(WeatherFormatting.temperature(today.temperatureMin, unit: units.temperature))")
                            .font(.title3.weight(.semibold).monospacedDigit())
                    }
                    Text("\(L10n.string("feels_like", language: language)) \(WeatherFormatting.temperature(snapshot.current.apparentTemperature, unit: units.temperature))")
                        .font(.callout)
                        .opacity(0.8)
                }
            }
            Text(WeatherFormatting.relativeUpdated(from: snapshot.fetchedAt))
                .font(.caption)
                .opacity(0.65)
        }
        .foregroundStyle(NimbusTheme.heroPrimary(recipe: recipe))
        .shadow(color: .black.opacity(recipe.isDay ? 0.08 : 0.35), radius: 12, y: 2)
        .padding(.top, 28)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct HourlyStripView: View {
    var snapshot: WeatherSnapshot
    var units: UnitPreferences
    var focusedDay: Date?
    var recipe: SceneRecipe
    var language: AppLanguage = .english

    @State private var hoverTime: Date?

    private var hours: [HourlyWeather] {
        if let focusedDay {
            return snapshot.hours(on: focusedDay)
        }
        return snapshot.hours(limit: 24)
    }

    private var selectedIndex: Int {
        let times = hours.map(\.time)
        if let hoverTime {
            return ChartInspect.nearestIndex(times: times, target: hoverTime)
        }
        return ChartInspect.nowIndex(times: times)
    }

    private var readout: ChartReadout {
        ChartInspect.readout(
            hours: hours,
            index: selectedIndex,
            kind: .temperature,
            units: units,
            timeZone: snapshot.timezone
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(focusedDay == nil ? L10n.string("hourly", language: language) : WeatherFormatting.weekday(focusedDay ?? Date(), timeZone: snapshot.timezone))
                    .font(.headline)
                Spacer()
                Text("\(readout.valueLabel)  \(readout.timeLabel)")
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .opacity(0.8)
            }
            .padding(.horizontal, 18)

            InspectableHourlyChart(
                hours: hours,
                kind: .temperature,
                units: units,
                timeZone: snapshot.timezone,
                accent: Color.white.opacity(0.92),
                compact: true,
                showsReadout: false,
                hoverTime: $hoverTime
            )
            .padding(.horizontal, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(hours.enumerated()), id: \.element.id) { index, hour in
                        let selected = index == selectedIndex
                        VStack(spacing: 8) {
                            Text(WeatherFormatting.hourLabel(hour.time, timeZone: snapshot.timezone))
                                .font(.caption.weight(.semibold))
                                .opacity(0.75)
                            Image(systemName: hour.condition.symbolName(isDay: hour.isDay))
                                .symbolRenderingMode(.hierarchical)
                                .font(.title3)
                                .frame(height: 22)
                            if let pop = hour.precipitationProbability, pop >= 10, hour.condition.isPrecipitation || pop >= 20 {
                                Text(WeatherFormatting.percent(pop))
                                    .font(.caption2.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(Color(red: 0.45, green: 0.78, blue: 1.0))
                            } else {
                                Text(" ")
                                    .font(.caption2)
                            }
                            Text(WeatherFormatting.temperature(hour.temperature, unit: units.temperature))
                                .font(.callout.weight(.semibold).monospacedDigit())
                        }
                        .frame(width: 58)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selected ? Color.white.opacity(0.16) : Color.clear)
                        )
                        .onHover { inside in
                            hoverTime = inside ? hour.time : nil
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .padding(.vertical, 12)
        .nimbusGlass()
        .foregroundStyle(NimbusTheme.heroPrimary(recipe: recipe))
        .padding(.horizontal, 20)
    }
}

struct DailyForecastView: View {
    var snapshot: WeatherSnapshot
    var units: UnitPreferences
    var focusedDay: Date?
    var recipe: SceneRecipe
    var language: AppLanguage = .english
    var onSelect: (Date) -> Void

    private var range: (min: Double, max: Double) {
        snapshot.temperatureRange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.string("forecast_16", language: language))
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            ForEach(snapshot.daily) { day in
                Button {
                    onSelect(day.date)
                } label: {
                    HStack(spacing: 10) {
                        Text(WeatherFormatting.weekday(day.date, timeZone: snapshot.timezone))
                            .font(.body.weight(.medium))
                            .frame(width: 92, alignment: .leading)
                        Image(systemName: day.condition.symbolName(isDay: true))
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 22)
                        Text(WeatherFormatting.percent(day.precipitationProbabilityMax))
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color(red: 0.45, green: 0.78, blue: 1.0))
                            .frame(width: 36, alignment: .leading)
                            .opacity((day.precipitationProbabilityMax ?? 0) >= 10 ? 1 : 0)
                        Text(WeatherFormatting.temperature(day.temperatureMin, unit: units.temperature))
                            .font(.callout.monospacedDigit())
                            .opacity(0.7)
                            .frame(width: 36, alignment: .trailing)
                        RangeBar(
                            low: day.temperatureMin ?? range.min,
                            high: day.temperatureMax ?? range.max,
                            globalMin: range.min,
                            globalMax: range.max
                        )
                        .frame(height: 6)
                        Text(WeatherFormatting.temperature(day.temperatureMax, unit: units.temperature))
                            .font(.callout.weight(.semibold).monospacedDigit())
                            .frame(width: 36, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isFocused(day.date) ? Color.white.opacity(0.12) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)
        }
        .nimbusGlass()
        .foregroundStyle(NimbusTheme.heroPrimary(recipe: recipe))
        .padding(.horizontal, 20)
    }

    private func isFocused(_ date: Date) -> Bool {
        guard let focusedDay else { return false }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = snapshot.timezone
        return cal.isDate(date, inSameDayAs: focusedDay)
    }
}

struct RangeBar: View {
    var low: Double
    var high: Double
    var globalMin: Double
    var globalMax: Double

    var body: some View {
        GeometryReader { geo in
            let span = Swift.max(globalMax - globalMin, 1)
            let x = (low - globalMin) / span
            let w = (high - low) / span
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.15))
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 0.45, green: 0.75, blue: 1), Color(red: 1, green: 0.72, blue: 0.32)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: Swift.max(8, geo.size.width * w))
                    .offset(x: geo.size.width * x)
            }
        }
    }
}
