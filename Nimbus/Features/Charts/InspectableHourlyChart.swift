import SwiftUI
import Charts

struct InspectableHourlyChart: View {
    var hours: [HourlyWeather]
    var kind: ChartSeriesKind
    var units: UnitPreferences
    var timeZone: TimeZone
    var yDomain: ClosedRange<Double>?
    var accent: Color = Color(red: 0.45, green: 0.75, blue: 1)
    var compact: Bool = false
    var showsReadout: Bool = true
    var hoverTime: Binding<Date?>?

    @State private var localHover: Date?
    @State private var plotWidth: CGFloat = 400

    private var hover: Binding<Date?> {
        hoverTime ?? $localHover
    }

    private var times: [Date] { hours.map(\.time) }

    private var nowIdx: Int { ChartInspect.nowIndex(times: times) }

    private var selectedIndex: Int {
        if let time = hover.wrappedValue {
            return ChartInspect.nearestIndex(times: times, target: time)
        }
        return ChartInspect.resolvedIndex(hover: nil, now: nowIdx)
    }

    private var readout: ChartReadout {
        ChartInspect.readout(hours: hours, index: selectedIndex, kind: kind, units: units, timeZone: timeZone)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            if showsReadout {
                HStack(alignment: .firstTextBaseline) {
                    Text(readout.valueLabel)
                        .font(.system(size: compact ? 20 : 28, weight: .semibold, design: .rounded).monospacedDigit())
                    Spacer()
                    Text(readout.timeLabel)
                        .font(.callout.weight(.medium))
                        .opacity(0.72)
                }
                .accessibilityElement(children: .combine)
            }

            chart
                .frame(maxWidth: .infinity)
                .frame(height: compact ? 64 : 160)
                .clipped()
                .compositingGroup()
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { plotWidth = $0 }
        }
        .clipped()
    }

    private var chart: some View {
        Chart(hours) { hour in
            let y = ChartInspect.displayY(hour, kind: kind, units: units)
            LineMark(
                x: .value("Time", hour.time),
                y: .value("Value", y)
            )
            .foregroundStyle(accent)
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: compact ? 1.5 : 2))

            if hours.indices.contains(selectedIndex), hours[selectedIndex].time == hour.time {
                RuleMark(x: .value("Sel", hour.time))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .zIndex(-1)
                PointMark(
                    x: .value("Time", hour.time),
                    y: .value("Value", y)
                )
                .foregroundStyle(.white)
                .symbolSize(compact ? 28 : 48)
            }
        }
        .chartXAxis {
            if compact {
                AxisMarks(values: .stride(by: .hour, count: 12)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4)).foregroundStyle(.white.opacity(0.08))
                }
            } else {
                AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(.white.opacity(0.12))
                    AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                }
            }
        }
        .chartYAxis {
            if compact {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 2))
            } else {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(.white.opacity(0.1))
                    AxisValueLabel()
                }
            }
        }
        .chartYScale(domain: yDomain ?? automaticDomain)
        .chartLegend(.hidden)
        .chartPlotStyle { plot in
            plot.clipped()
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    applyHover(x: value.location.x, width: plotWidth)
                }
                .onEnded { _ in
                    hover.wrappedValue = nil
                }
        )
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                applyHover(x: location.x, width: plotWidth)
            case .ended:
                hover.wrappedValue = nil
            }
        }
    }

    private func applyHover(x: CGFloat, width: CGFloat) {
        let i = ChartInspect.nearestIndex(times: times, x: Double(x), width: Double(max(width, 1)))
        if hours.indices.contains(i) {
            hover.wrappedValue = hours[i].time
        }
    }

    private var automaticDomain: ClosedRange<Double> {
        let values = hours.map { ChartInspect.displayY($0, kind: kind, units: units) }
        let lo = values.min() ?? 0
        let hi = values.max() ?? 1
        switch kind {
        case .humidity: return 0...100
        case .uv: return 0...max(11, hi)
        case .precipitation, .wind, .visibility, .cape, .shortwave:
            return 0...max(hi * 1.15, 1)
        case .pressure:
            let pad = max((hi - lo) * 0.2, 0.6)
            return (lo - pad)...(hi + pad)
        default:
            let pad = max((hi - lo) * 0.14, 1)
            return (lo - pad)...(hi + pad)
        }
    }
}
