import SwiftUI
import Charts

struct ModuleGridView: View {
    var snapshot: WeatherSnapshot
    var units: UnitPreferences
    var language: AppLanguage
    var recipe: SceneRecipe
    var onSelect: (WeatherModule) -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(WeatherModule.allCases) { module in
                ModuleCard(
                    module: module,
                    snapshot: snapshot,
                    units: units,
                    language: language,
                    recipe: recipe
                ) {
                    onSelect(module)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }
}

struct ModuleCard: View {
    var module: WeatherModule
    var snapshot: WeatherSnapshot
    var units: UnitPreferences
    var language: AppLanguage
    var recipe: SceneRecipe
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: module.symbol)
                    Text(L10n.string(module.localizationKey, language: language).uppercased())
                        .tracking(0.6)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .opacity(0.55)
                }
                .font(.caption.weight(.semibold))
                .opacity(0.7)

                ModuleHeader(module: module, snapshot: snapshot, units: units, language: language)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 118, maxHeight: 132, alignment: .topLeading)
            .nimbusGlass()
            .foregroundStyle(NimbusTheme.heroPrimary(recipe: recipe))
        }
        .buttonStyle(ScalePressStyle())
        .accessibilityLabel(L10n.string(module.localizationKey, language: language))
    }
}

struct ModuleHeader: View {
    var module: WeatherModule
    var snapshot: WeatherSnapshot
    var units: UnitPreferences
    var language: AppLanguage

    var body: some View {
        let c = snapshot.current
        let today = snapshot.today
        switch module {
        case .precipitation:
            VStack(alignment: .leading, spacing: 4) {
                Text(WeatherFormatting.precipitation(today?.precipitationSum, unit: units.precipitation))
                    .font(.title.weight(.semibold).monospacedDigit())
                Text("\(WeatherFormatting.percent(today?.precipitationProbabilityMax)) \(L10n.string("chance_today", language: language))")
                    .font(.callout)
                    .opacity(0.75)
            }
        case .wind:
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "location.north.fill")
                    .rotationEffect(.degrees((c.windDirection ?? 0) + 180))
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text(WeatherFormatting.wind(c.windSpeed, unit: units.wind))
                        .font(.title.weight(.semibold).monospacedDigit())
                    Text("\(L10n.string("gusts", language: language)) \(WeatherFormatting.wind(c.windGusts, unit: units.wind))  \(WeatherFormatting.compass(c.windDirection))")
                        .font(.callout)
                        .opacity(0.75)
                }
            }
        case .uv:
            VStack(alignment: .leading, spacing: 6) {
                Text(uvText)
                    .font(.title.weight(.semibold).monospacedDigit())
                Text(UVCategory(index: c.uvIndex ?? today?.uvIndexMax ?? 0).title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(UVCategory(index: c.uvIndex ?? today?.uvIndexMax ?? 0).color)
            }
        case .feelsLike:
            VStack(alignment: .leading, spacing: 4) {
                Text(WeatherFormatting.temperature(c.apparentTemperature, unit: units.temperature))
                    .font(.title.weight(.semibold).monospacedDigit())
                Text(feelsReason)
                    .font(.callout)
                    .opacity(0.75)
            }
        case .humidity:
            VStack(alignment: .leading, spacing: 4) {
                Text(WeatherFormatting.percent(c.humidity))
                    .font(.title.weight(.semibold).monospacedDigit())
                Text("\(L10n.string("dew_point", language: language)) \(WeatherFormatting.temperature(c.dewPoint, unit: units.temperature))")
                    .font(.callout)
                    .opacity(0.75)
            }
        case .visibility:
            VStack(alignment: .leading, spacing: 4) {
                Text(WeatherFormatting.visibility(c.visibility, unit: units.distance))
                    .font(.title.weight(.semibold).monospacedDigit())
                Text(visibilityWord)
                    .font(.callout)
                    .opacity(0.75)
            }
        case .pressure:
            VStack(alignment: .leading, spacing: 4) {
                Text(WeatherFormatting.pressure(c.pressureMSL))
                    .font(.title.weight(.semibold).monospacedDigit())
                Text(pressureTrend)
                    .font(.callout)
                    .opacity(0.75)
            }
        case .sunMoon:
            VStack(alignment: .leading, spacing: 4) {
                Text(sunLabel)
                    .font(.title3.weight(.semibold))
                Text(MoonMath.phase(on: Date()).name)
                    .font(.callout)
                    .opacity(0.75)
            }
        case .airQuality:
            let aqi = snapshot.airQuality
            VStack(alignment: .leading, spacing: 4) {
                Text(aqi.flatMap { $0.usAQI ?? $0.europeanAQI }.map { "\(Int($0.rounded()))" } ?? "—")
                    .font(.title.weight(.semibold).monospacedDigit())
                Text(aqi?.category.shortTitle ?? "—")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(aqi?.category.color ?? .secondary)
            }
        }
    }

    private var uvText: String {
        let value = snapshot.current.uvIndex ?? snapshot.today?.uvIndexMax
        guard let value else { return "—" }
        return String(format: value < 10 ? "%.1f" : "%.0f", value)
    }

    private var feelsReason: String {
        let c = snapshot.current
        guard let actual = c.temperature, let feel = c.apparentTemperature else { return " " }
        if feel > actual + 1 { return L10n.string("humidity", language: language) }
        if feel < actual - 1 { return L10n.string("wind", language: language) }
        return " "
    }

    private var visibilityWord: String {
        guard let v = snapshot.current.visibility else { return " " }
        switch v {
        case ..<1000: return "—"
        case ..<4000: return "—"
        default: return L10n.string("clear", language: language)
        }
    }

    private var pressureTrend: String {
        let hours = snapshot.hours(limit: 4)
        guard let first = hours.first?.pressureMSL, let last = hours.last?.pressureMSL else { return " " }
        let delta = last - first
        if delta > 1 { return L10n.string("rising", language: language) }
        if delta < -1 { return L10n.string("falling", language: language) }
        return L10n.string("steady", language: language)
    }

    private var sunLabel: String {
        guard let today = snapshot.today, let sunrise = today.sunrise, let sunset = today.sunset else { return "—" }
        let now = Date()
        let event = now < sunrise ? sunrise : sunset
        return time(event)
    }

    private func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = snapshot.timezone
        f.timeStyle = .short
        return f.string(from: date)
    }
}

struct ModuleDetailOverlay: View {
    var module: WeatherModule
    var snapshot: WeatherSnapshot
    var units: UnitPreferences
    var language: AppLanguage
    var recipe: SceneRecipe
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.38)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: module.symbol)
                    Text(L10n.string(module.localizationKey, language: language))
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.string("close", language: language))
                    .keyboardShortcut(.cancelAction)
                }

                ModuleHeader(module: module, snapshot: snapshot, units: units, language: language)
                    .font(.title)

                detailChart
                    .frame(height: 200)

                extraCopy
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(22)
            .frame(width: 440)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 28, y: 12)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .center)))
    }

    @ViewBuilder
    private var detailChart: some View {
        let hours = snapshot.hours(limit: 24)
        switch module {
        case .precipitation:
            Chart(hours) { hour in
                BarMark(
                    x: .value("Time", hour.time),
                    y: .value("Precip", hour.precipitation ?? 0)
                )
                .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1))
            }
            .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 6)) }
        case .wind:
            Chart(hours) { hour in
                LineMark(x: .value("Time", hour.time), y: .value("Wind", hour.windSpeed ?? 0))
                AreaMark(x: .value("Time", hour.time), y: .value("Wind", hour.windSpeed ?? 0))
                    .foregroundStyle(Color.white.opacity(0.12))
            }
            .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 6)) }
        case .uv:
            Chart(hours) { hour in
                AreaMark(x: .value("Time", hour.time), y: .value("UV", hour.uvIndex ?? 0))
                    .foregroundStyle(Color.orange.opacity(0.28))
                LineMark(x: .value("Time", hour.time), y: .value("UV", hour.uvIndex ?? 0))
                    .foregroundStyle(Color.orange)
            }
            .chartYScale(domain: 0...12)
        case .humidity:
            Chart(hours) { hour in
                LineMark(x: .value("Time", hour.time), y: .value("RH", hour.humidity ?? 0))
            }
            .chartYScale(domain: 0...100)
        case .pressure:
            let values = hours.compactMap(\.pressureMSL)
            let lo = (values.min() ?? 1000) - 4
            let hi = (values.max() ?? 1020) + 4
            Chart(hours) { hour in
                LineMark(x: .value("Time", hour.time), y: .value("hPa", hour.pressureMSL ?? 0))
            }
            .chartYScale(domain: lo...hi)
        case .visibility:
            Chart(hours) { hour in
                LineMark(
                    x: .value("Time", hour.time),
                    y: .value("Vis", units.distance == .mile ? (hour.visibility ?? 0) / 1609.344 : (hour.visibility ?? 0) / 1000)
                )
            }
        case .feelsLike:
            Chart(hours) { hour in
                LineMark(x: .value("Time", hour.time), y: .value("Apparent", hour.apparentTemperature ?? 0))
                LineMark(x: .value("Time", hour.time), y: .value("Air", hour.temperature ?? 0))
                    .foregroundStyle(.secondary)
            }
        case .sunMoon:
            VStack(alignment: .leading, spacing: 8) {
                if let today = snapshot.today {
                    labeled(L10n.string("sunrise", language: language), today.sunrise)
                    labeled(L10n.string("sunset", language: language), today.sunset)
                    if let daylight = today.daylightDuration {
                        Text(formattedDuration(daylight))
                    }
                }
            }
        case .airQuality:
            if let aq = snapshot.airQuality {
                VStack(alignment: .leading, spacing: 6) {
                    pollutant("PM2.5", aq.pm25, "µg/m³")
                    pollutant("PM10", aq.pm10, "µg/m³")
                    pollutant("O₃", aq.ozone, "µg/m³")
                    pollutant("NO₂", aq.nitrogenDioxide, "µg/m³")
                }
            }
        }
    }

    @ViewBuilder
    private var extraCopy: some View {
        switch module {
        case .airQuality:
            if let aq = snapshot.airQuality {
                Text(aq.category.title)
            }
        default:
            EmptyView()
        }
    }

    private func labeled(_ title: String, _ date: Date?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(date.map(time) ?? "—").monospacedDigit()
        }
    }

    private func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = snapshot.timezone
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func pollutant(_ name: String, _ value: Double?, _ unit: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(value.map { String(format: "%.0f %@", $0, unit) } ?? "—").monospacedDigit()
        }
        .font(.callout)
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let hours = Int(seconds / 3600)
        let minutes = Int(seconds.truncatingRemainder(dividingBy: 3600) / 60)
        return "\(hours)h \(minutes)m"
    }
}

extension WeatherModule {
    var localizationKey: String {
        switch self {
        case .precipitation: return "precipitation"
        case .wind: return "wind"
        case .uv: return "uv_index"
        case .feelsLike: return "feels_like"
        case .humidity: return "humidity"
        case .visibility: return "visibility"
        case .pressure: return "pressure"
        case .sunMoon: return "sun_moon"
        case .airQuality: return "air_quality"
        }
    }
}
