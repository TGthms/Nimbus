import SwiftUI

struct SidebarView: View {
    @ObservedObject var model: AppModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if showsSearchResults {
                        searchResultsSection
                    } else {
                        myLocationSection
                        savedSection
                        if !unaddedPopular.isEmpty {
                            popularSection
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .frame(width: NimbusTheme.sidebarWidth)
        .background(.regularMaterial)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(width: 1)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(model.t("search_cities"), text: $model.searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onChange(of: model.searchText) { _, newValue in
                    model.updateSearch(newValue)
                }
            if model.isSearching {
                ProgressView().controlSize(.small)
            } else if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                    model.searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quaternary.opacity(0.5)))
        .padding(12)
        .onChange(of: model.searchFocusTick) { _, _ in
            searchFocused = true
        }
    }

    private var showsSearchResults: Bool {
        !model.searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var myLocationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(model.t("my_location"))
            if let place = model.places.first(where: \.isCurrentLocation) {
                PlaceRow(
                    place: displayPlace(place),
                    summary: model.summaries[place.id],
                    selected: model.selectedPlaceID == place.id,
                    units: model.units,
                    authorized: model.location.isAuthorized,
                    language: model.language
                ) {
                    if !model.location.isAuthorized {
                        model.location.request()
                    }
                    model.select(place)
                }
            }
        }
    }

    private var savedSection: some View {
        let saved = model.places.filter { !$0.isCurrentLocation }
        return VStack(alignment: .leading, spacing: 6) {
            sectionLabel(model.t("cities"))
            if saved.isEmpty {
                Text(model.t("search_add_hint"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
            ForEach(saved) { place in
                PlaceRow(
                    place: place,
                    summary: model.summaries[place.id],
                    selected: model.selectedPlaceID == place.id,
                    units: model.units,
                    authorized: true,
                    language: model.language
                ) {
                    model.select(place)
                }
                .contextMenu {
                    Button(model.t("remove"), role: .destructive) { model.remove(place) }
                }
            }
        }
    }

    private var unaddedPopular: [Place] {
        let existing = Set(model.places.map(\.coordinateKey))
        return PopularCities.seeds.filter { !existing.contains($0.coordinateKey) }
    }

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(model.t("popular"))
            ForEach(unaddedPopular) { place in
                HStack(spacing: 10) {
                    Image(systemName: "building.2")
                        .frame(width: 22)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(place.name).font(.body.weight(.medium))
                        if !place.subtitle.isEmpty {
                            Text(place.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button(model.t("add")) { model.addPopular(place) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            let popularHits = PopularCities.matching(model.searchText)
            if !popularHits.isEmpty && model.searchResults.isEmpty {
                sectionLabel(model.t("popular_matches"))
                ForEach(popularHits) { place in
                    searchAddRow(title: place.name, subtitle: place.subtitle) {
                        model.addPopular(place)
                    }
                }
            }
            sectionLabel(model.t("search_results"))
            if model.searchResults.isEmpty && !model.isSearching {
                Text(model.t("no_cities_found"))
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            ForEach(model.searchResults) { result in
                searchAddRow(title: result.name, subtitle: result.subtitle) {
                    model.add(result)
                }
            }
        }
    }

    private func searchAddRow(title: String, subtitle: String, add: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.body.weight(.medium))
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(model.t("add"), action: add)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.white.opacity(0.22))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    private func displayPlace(_ place: Place) -> Place {
        guard place.isCurrentLocation else { return place }
        return model.location.currentPlace(existing: place)
    }
}

struct PlaceRow: View {
    var place: Place
    var summary: PlaceSummary?
    var selected: Bool
    var units: UnitPreferences
    var authorized: Bool
    var language: AppLanguage = .english
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: place.isCurrentLocation ? "location.fill" : summary?.condition.symbolName(isDay: summary?.isDay ?? true) ?? "building.2")
                    .foregroundStyle(selected ? .primary : .secondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(place.isCurrentLocation ? (authorized ? place.name : L10n.string("my_location", language: language)) : place.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(place.isCurrentLocation && !authorized ? L10n.string("enable_location", language: language) : (place.subtitle.isEmpty ? " " : place.subtitle))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if let temp = summary?.temperature {
                    Text(WeatherFormatting.temperature(temp, unit: units.temperature))
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Color.primary.opacity(0.12) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
