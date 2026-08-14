import SwiftUI
import Charts

struct InspectorView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var modelHover: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(model.t("inspector"))
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.12) : NimbusTheme.panelSpring) { model.inspectorVisible = false }
                    Task { await model.persist() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(model.t("close"))
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(InspectorTab.allCases) { tab in
                        Button {
                            model.inspectorTab = tab
                        } label: {
                            Text(model.t(tab.localizationKey))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(model.inspectorTab == tab ? Color.accentColor : Color.primary.opacity(0.08))
                                )
                                .foregroundStyle(model.inspectorTab == tab ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
            }

            Divider().padding(.top, 10)

            ScrollView {
                Group {
                    switch model.inspectorTab {
                    case .models: models
                    case .atmosphere: atmosphere
                    case .solar: solar
                    case .uncertainty: uncertainty
                    case .sounding: sounding
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if model.isLoadingInspector {
                ProgressView()
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 380)
        .background(.regularMaterial)
        .overlay(alignment: .leading) {
            Rectangle().fill(.white.opacity(0.08)).frame(width: 1)
        }
        .task(id: "\(model.selectedPlaceID)-\(model.inspectorVisible)-\(model.inspectorTab.rawValue)") {
            await model.loadInspectorIfNeeded()
        }
    }

    @ViewBuilder
    private var models: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.t("models_help"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !model.modelSeries.isEmpty {
                let times = Array(model.modelSeries[0].times.prefix(48))
                let nowIdx = ChartInspect.nowIndex(times: times)
                let idx = ChartInspect.resolvedIndex(
                    hover: modelHover.map { ChartInspect.nearestIndex(times: times, target: $0) },
                    now: nowIdx
                )
                let clock = times.indices.contains(idx)
                    ? WeatherFormatting.hourLabel(times[idx], timeZone: model.selectedSnapshot?.timezone ?? .current)
                    : "—"
                Text(clock)
                    .font(.caption.weight(.semibold))
                    .opacity(0.7)
                Chart {
                    ForEach(model.modelSeries, id: \.model) { series in
                        ForEach(Array(series.times.prefix(48).enumerated()), id: \.offset) { index, time in
                            if let temp = series.temperature[safe: index] ?? nil {
                                LineMark(
                                    x: .value("Time", time),
                                    y: .value("Temp", model.units.temperature.display(temp))
                                )
                                .foregroundStyle(by: .value("Model", series.title))
                            }
                        }
                    }
                    if times.indices.contains(idx) {
                        RuleMark(x: .value("Sel", times[idx]))
                            .foregroundStyle(.primary.opacity(0.35))
                    }
                }
                .frame(height: 170)
                .chartLegend(position: .bottom, alignment: .leading)
                .chartYAxis { AxisMarks(position: .leading) }
                .chartPlotStyle { $0.clipped() }
                .clipped()
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let loc):
                        let i = ChartInspect.nearestIndex(times: times, x: loc.x, width: 340)
                        if times.indices.contains(i) { modelHover = times[i] }
                    case .ended:
                        modelHover = nil
                    }
                }
            }
            ForEach(model.modelSeries, id: \.model) { series in
                let times = Array(series.times.prefix(48))
                let nowIdx = ChartInspect.nowIndex(times: times)
                let idx = ChartInspect.resolvedIndex(
                    hover: modelHover.map { ChartInspect.nearestIndex(times: times, target: $0) },
                    now: nowIdx
                )
                let value = series.temperature[safe: idx] ?? nil
                HStack {
                    Text(series.title)
                    Spacer()
                    Text(WeatherFormatting.temperature(value, unit: model.units.temperature))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var atmosphere: some View {
        if let snap = model.selectedSnapshot {
            VStack(alignment: .leading, spacing: 14) {
                metric("CAPE", snap.current.cape.map { "\(Int($0.rounded())) J/kg" } ?? "—", note: capeNote(snap.current.cape))
                metric("CIN", snap.current.convectiveInhibition.map { "\(Int($0.rounded())) J/kg" } ?? "—", note: nil)
                metric("Freezing", snap.current.freezingLevelHeight.map { "\(Int($0.rounded())) m" } ?? "—", note: nil)
                InspectableHourlyChart(
                    hours: snap.hours(limit: 24),
                    kind: .cape,
                    units: model.units,
                    timeZone: snap.timezone
                )
            }
        }
    }

    @ViewBuilder
    private var solar: some View {
        if let snap = model.selectedSnapshot {
            VStack(alignment: .leading, spacing: 14) {
                metric("GHI", snap.current.shortwaveRadiation.map { "\(Int($0.rounded())) W/m²" } ?? "—", note: nil)
                if let today = snap.today, let sum = today.shortwaveRadiationSum {
                    metric("Σ", String(format: "%.1f MJ/m²", sum), note: nil)
                }
                InspectableHourlyChart(
                    hours: snap.hours(limit: 24),
                    kind: .shortwave,
                    units: model.units,
                    timeZone: snap.timezone,
                    accent: .orange
                )
            }
        }
    }

    @ViewBuilder
    private var uncertainty: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let ensemble = model.ensemble {
                Text(OpenMeteoClient.modelTitle(ensemble.model))
                    .font(.subheadline.weight(.semibold))
                Chart {
                    ForEach(Array(ensemble.times.enumerated()), id: \.offset) { index, time in
                        if let mean = ensemble.temperatureMean[safe: index] ?? nil {
                            let shown = model.units.temperature.display(mean)
                            LineMark(x: .value("Time", time), y: .value("Mean", shown))
                            if let spread = ensemble.temperatureSpread[safe: index] ?? nil {
                                let delta = model.units.temperature.display(mean + spread) - shown
                                AreaMark(
                                    x: .value("Time", time),
                                    yStart: .value("Low", shown - delta),
                                    yEnd: .value("High", shown + delta)
                                )
                                .opacity(0.16)
                            }
                        }
                    }
                }
                .frame(height: 180)
                .chartXAxis(.hidden)
            }
        }
    }

    @ViewBuilder
    private var sounding: some View {
        if let snap = model.selectedSnapshot {
            let hour = snap.hours(limit: 1).first ?? snap.hourly.first
            VStack(alignment: .leading, spacing: 10) {
                if let hour {
                    profileRow("1000 hPa", hour.temperature1000hPa, hour.humidity1000hPa, hour.windSpeed1000hPa)
                    profileRow("925 hPa", hour.temperature925hPa, hour.humidity925hPa, nil)
                    profileRow("850 hPa", hour.temperature850hPa, hour.humidity850hPa, hour.windSpeed850hPa)
                    profileRow("700 hPa", hour.temperature700hPa, hour.humidity700hPa, hour.windSpeed700hPa)
                    profileRow("500 hPa", hour.temperature500hPa, hour.humidity500hPa, hour.windSpeed500hPa)
                    profileRow("300 hPa", hour.temperature300hPa, hour.humidity300hPa, nil)
                }
            }
        }
    }

    private func profileRow(_ level: String, _ t: Double?, _ rh: Double?, _ wind: Double?) -> some View {
        HStack {
            Text(level).frame(width: 78, alignment: .leading)
            Text(WeatherFormatting.temperature(t, unit: model.units.temperature)).frame(width: 52)
            Text(rh.map { "\(Int($0.rounded()))%" } ?? "—").frame(width: 40)
            if let wind {
                Text(WeatherFormatting.wind(wind, unit: model.units.wind))
            }
            Spacer()
        }
        .font(.caption.monospacedDigit())
    }

    private func metric(_ title: String, _ value: String, note: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold).monospacedDigit())
            if let note {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func capeNote(_ cape: Double?) -> String? {
        guard let cape else { return nil }
        switch cape {
        case ..<300: return "—"
        case ..<1000: return "—"
        default: return "CAPE \(Int(cape.rounded()))"
        }
    }
}

extension InspectorTab {
    var localizationKey: String {
        switch self {
        case .models: return "models"
        case .atmosphere: return "atmosphere"
        case .solar: return "solar"
        case .uncertainty: return "uncertainty"
        case .sounding: return "sounding"
        }
    }
}
