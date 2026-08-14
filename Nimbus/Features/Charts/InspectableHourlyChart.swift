import SwiftUI
import Charts

struct InspectableHourlyChart: View {
    var hours: [HourlyWeather]
    var kind: ChartSeriesKind
    var units: UnitPreferences
    var timeZone: TimeZone
    var yDomain: ClosedRange<Double>?
    var accent: Color = Color(red: 0.45, green: 0.75, blue: 1)
    var onIndexChange: ((Int) -> Void)?

    @State private var hoverTime: Date?

    private var times: [Date] { hours.map(\.time) }

    private var nowIdx: Int { ChartInspect.nowIndex(times: times) }

    private var selectedIndex: Int {
        if let hoverTime {
            return ChartInspect.nearestIndex(times: times, target: hoverTime)
        }
        return ChartInspect.resolvedIndex(hover: nil, now: nowIdx)
    }

    private var readout: ChartReadout {
        ChartInspect.readout(hours: hours, index: selectedIndex, kind: kind, units: units, timeZone: timeZone)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(readout.valueLabel)
                    .font(.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit())
                Spacer()
                Text(readout.timeLabel)
                    .font(.callout.weight(.medium))
                    .opacity(0.72)
            }
            .accessibilityElement(children: .combine)

            chart
                .frame(height: 168)
        }
        .onChange(of: selectedIndex) { _, index in
            onIndexChange?(index)
        }
    }

    private var chart: some View {
        Chart(hours) { hour in
            let y = ChartInspect.displayY(hour, kind: kind, units: units)
            AreaMark(
                x: .value("Time", hour.time),
                y: .value("Value", y)
            )
            .foregroundStyle(accent.opacity(0.18))
            .interpolationMethod(.catmullRom)
            LineMark(
                x: .value("Time", hour.time),
                y: .value("Value", y)
            )
            .foregroundStyle(accent)
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2))

            if hours.indices.contains(selectedIndex), hours[selectedIndex].id == hour.id {
                RuleMark(x: .value("Sel", hour.time))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                PointMark(
                    x: .value("Time", hour.time),
                    y: .value("Value", y)
                )
                .foregroundStyle(.white)
                .symbolSize(48)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(.white.opacity(0.12))
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(.white.opacity(0.1))
                AxisValueLabel()
            }
        }
        .chartYScale(domain: yDomain ?? automaticDomain)
        .chartXSelection(value: $hoverTime)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let x = location.x
                            if let date: Date = proxy.value(atX: x) {
                                hoverTime = date
                            } else if geo.size.width > 0 {
                                let i = ChartInspect.nearestIndex(times: times, x: x, width: geo.size.width)
                                if hours.indices.contains(i) { hoverTime = hours[i].time }
                            }
                        case .ended:
                            hoverTime = nil
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if let date: Date = proxy.value(atX: value.location.x) {
                                    hoverTime = date
                                }
                            }
                            .onEnded { _ in
                                hoverTime = nil
                            }
                    )
            }
        }
    }

    private var automaticDomain: ClosedRange<Double> {
        let values = hours.map { ChartInspect.displayY($0, kind: kind, units: units) }
        let lo = values.min() ?? 0
        let hi = values.max() ?? 1
        if kind == .humidity { return 0...100 }
        if kind == .uv { return 0...max(11, hi) }
        if kind == .precipitation || kind == .wind || kind == .visibility {
            return 0...max(hi * 1.15, 1)
        }
        let pad = max((hi - lo) * 0.14, 1)
        return (lo - pad)...(hi + pad)
    }
}
