import Foundation
import SwiftUI
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published var places: [Place] = PopularCities.defaultPlaces()
    @Published var selectedPlaceID: UUID = PopularCities.myLocation.id
    @Published var snapshots: [UUID: WeatherSnapshot] = [:]
    @Published var summaries: [UUID: PlaceSummary] = [:]
    @Published var settings = AppSettings()
    @Published var searchText = ""
    @Published var searchResults: [GeocodingResult] = []
    @Published var isSearching = false
    @Published var isRefreshing = false
    @Published var banner: String?
    @Published var inspectorVisible = false
    @Published var inspectorTab: InspectorTab = .models
    @Published var focusedDay: Date?
    @Published var expandedModule: WeatherModule?
    @Published var modelSeries: [ModelComparisonSeries] = []
    @Published var ensemble: EnsembleSeries?
    @Published var isLoadingInspector = false

    let location = LocationProvider()
    let client = OpenMeteoClient()
    let store = WeatherStore()

    private var searchTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var watchesSystemUnits = false

    var selectedPlace: Place {
        places.first(where: { $0.id == selectedPlaceID }) ?? places.first ?? PopularCities.myLocation
    }

    var selectedSnapshot: WeatherSnapshot? {
        snapshots[selectedPlaceID]
    }

    var units: UnitPreferences {
        settings.units.followLocale ? .fromSystem() : settings.units
    }

    var language: AppLanguage {
        LanguageResolver.resolve(preference: settings.language)
    }

    func t(_ key: String) -> String {
        L10n.string(key, language: language)
    }

    func bootstrap() async {
        let loadedPlaces = await store.loadPlaces()
        let loadedSettings = await store.loadSettings()
        settings = loadedSettings
        if settings.units.followLocale {
            settings.units = .fromSystem()
        }
        startWatchingSystemUnits()
        places = loadedPlaces
        if !settings.hasCompletedOnboardingSeed {
            places = PopularCities.defaultPlaces()
            settings.hasCompletedOnboardingSeed = true
            await persist()
        }
        if let selected = settings.selectedPlaceID, places.contains(where: { $0.id == selected }) {
            selectedPlaceID = selected
        } else if let firstCity = places.first(where: { !$0.isCurrentLocation }) {
            selectedPlaceID = firstCity.id
        } else if let first = places.first {
            selectedPlaceID = first.id
        }
        inspectorVisible = settings.inspectorVisible

        for place in places {
            if let snap = await store.loadSnapshot(id: place.id) {
                snapshots[place.id] = snap
                summaries[place.id] = PlaceSummary(
                    place: snap.place,
                    temperature: snap.current.temperature,
                    weatherCode: snap.current.weatherCode,
                    isDay: snap.current.isDay,
                    fetchedAt: snap.fetchedAt
                )
            }
        }

        location.request()
        await refreshSelected(force: false)
        await refreshSidebarSummaries()
    }

    func persist() async {
        settings.selectedPlaceID = selectedPlaceID
        settings.inspectorVisible = inspectorVisible
        await store.savePlaces(places)
        await store.saveSettings(settings)
    }

    func select(_ place: Place) {
        selectedPlaceID = place.id
        focusedDay = nil
        expandedModule = nil
        Task { await persist() }
        Task { await refreshSelected(force: false) }
    }

    func add(_ result: GeocodingResult) {
        if let existing = places.first(where: {
            abs($0.latitude - result.latitude) < 0.05 && abs($0.longitude - result.longitude) < 0.05 && !$0.isCurrentLocation
        }) {
            select(existing)
            searchText = ""
            searchResults = []
            return
        }
        var place = result.asPlace(sortIndex: (places.map(\.sortIndex).max() ?? 0) + 1)
        places.append(place)
        searchText = ""
        searchResults = []
        select(place)
        Task { await persist() }
    }

    func addPopular(_ seed: Place) {
        guard !places.contains(where: { $0.id == seed.id || $0.coordinateKey == seed.coordinateKey }) else {
            if let existing = places.first(where: { $0.id == seed.id || $0.coordinateKey == seed.coordinateKey }) {
                select(existing)
            }
            return
        }
        var place = seed
        place.sortIndex = (places.map(\.sortIndex).max() ?? 0) + 1
        places.append(place)
        select(place)
        Task { await persist() }
    }

    func remove(_ place: Place) {
        guard !place.isCurrentLocation else { return }
        places.removeAll { $0.id == place.id }
        snapshots[place.id] = nil
        summaries[place.id] = nil
        if selectedPlaceID == place.id {
            selectedPlaceID = places.first?.id ?? PopularCities.myLocation.id
        }
        Task { await persist() }
    }

    func movePlaces(from offsets: IndexSet, to destination: Int) {
        var items = places
        items.move(fromOffsets: offsets, toOffset: destination)
        for index in items.indices {
            items[index].sortIndex = index
        }
        places = items
        Task { await persist() }
    }

    func updateSearch(_ text: String) {
        searchText = text
        searchTask?.cancel()
        let query = text
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await self?.performSearch(query)
        }
    }

    private func performSearch(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            searchResults = try await client.searchPlaces(query: trimmed)
        } catch {
            if !Task.isCancelled {
                banner = error.localizedDescription
            }
        }
    }

    func refreshSelected(force: Bool) async {
        var place = selectedPlace
        if place.isCurrentLocation {
            if let coord = location.coordinate {
                place = location.currentPlace(existing: place)
                if let idx = places.firstIndex(where: { $0.id == place.id }) {
                    places[idx] = place
                }
            } else if !location.isAuthorized {
                // Keep last known; do not fetch 0,0.
                return
            } else {
                location.refresh()
                return
            }
        }

        if !force, let existing = snapshots[place.id], !existing.isStale() {
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let snap = try await client.forecast(for: place, units: units)
            snapshots[place.id] = snap
            summaries[place.id] = PlaceSummary(
                place: snap.place,
                temperature: snap.current.temperature,
                weatherCode: snap.current.weatherCode,
                isDay: snap.current.isDay,
                fetchedAt: snap.fetchedAt
            )
            await store.saveSnapshot(snap)
            banner = nil
        } catch {
            if snapshots[place.id] == nil {
                banner = error.localizedDescription
            } else {
                banner = "Showing last update — \(error.localizedDescription)"
            }
        }
    }

    func refreshSidebarSummaries() async {
        for place in places where place.id != selectedPlaceID {
            if let existing = snapshots[place.id], !existing.isStale(ttl: 45 * 60) {
                continue
            }
            var resolved = place
            if place.isCurrentLocation {
                guard location.coordinate != nil else { continue }
                resolved = location.currentPlace(existing: place)
            }
            do {
                let snap = try await client.forecastOnly(for: resolved, units: units)
                snapshots[place.id] = snap
                summaries[place.id] = PlaceSummary(
                    place: snap.place,
                    temperature: snap.current.temperature,
                    weatherCode: snap.current.weatherCode,
                    isDay: snap.current.isDay,
                    fetchedAt: snap.fetchedAt
                )
                await store.saveSnapshot(snap)
            } catch {
                continue
            }
        }
    }

    func applyUnits(_ units: UnitPreferences) {
        settings.units = units
        objectWillChange.send()
        Task { await persist() }
    }

    private func startWatchingSystemUnits() {
        guard !watchesSystemUnits else { return }
        watchesSystemUnits = true
        NotificationCenter.default.addObserver(forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.refreshUnitsFromSystemIfNeeded()
            }
        }
        DistributedNotificationCenter.default().addObserver(forName: .init("AppleMeasurementUnits_Notification"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.refreshUnitsFromSystemIfNeeded()
            }
        }
    }

    func refreshUnitsFromSystemIfNeeded() {
        guard settings.units.followLocale else { return }
        let next = UnitPreferences.fromSystem()
        guard next != settings.units else { return }
        applyUnits(next)
    }

    func loadInspectorIfNeeded() async {
        guard inspectorVisible, let snapshot = selectedSnapshot else { return }
        isLoadingInspector = true
        defer { isLoadingInspector = false }
        let models = ["best_match", "ecmwf_ifs", "gfs_seamless", "icon_seamless"]
        do {
            async let extras = client.forecast(for: snapshot.place, units: units, includeExtras: true)
            async let comparison = client.modelComparison(for: snapshot.place, units: units, models: models)
            let ensembleModel = OpenMeteoClient.defaultEnsembleModel(for: snapshot.place)
            async let ensembleCall = client.ensemble(for: snapshot.place, units: units, model: ensembleModel)
            if let rich = try? await extras {
                snapshots[snapshot.place.id] = rich
                await store.saveSnapshot(rich)
            }
            modelSeries = try await comparison
            ensemble = try? await ensembleCall
        } catch {
            banner = error.localizedDescription
        }
    }

    func menuBarSnapshot() -> WeatherSnapshot? {
        if let id = settings.menuBarPlaceID, let snap = snapshots[id] {
            return snap
        }
        return selectedSnapshot
    }

    func previousPlace() {
        guard let idx = places.firstIndex(where: { $0.id == selectedPlaceID }) else { return }
        let next = places[(idx - 1 + places.count) % places.count]
        select(next)
    }

    func nextPlace() {
        guard let idx = places.firstIndex(where: { $0.id == selectedPlaceID }) else { return }
        let next = places[(idx + 1) % places.count]
        select(next)
    }
}

enum InspectorTab: String, CaseIterable, Identifiable {
    case models
    case atmosphere
    case solar
    case uncertainty
    case sounding

    var id: String { rawValue }

    var title: String {
        switch self {
        case .models: return "Models"
        case .atmosphere: return "Atmosphere"
        case .solar: return "Solar"
        case .uncertainty: return "Uncertainty"
        case .sounding: return "Sounding"
        }
    }
}

enum WeatherModule: String, CaseIterable, Identifiable {
    case precipitation
    case wind
    case uv
    case feelsLike
    case humidity
    case visibility
    case pressure
    case sunMoon
    case airQuality

    var id: String { rawValue }

    var title: String {
        switch self {
        case .precipitation: return "Precipitation"
        case .wind: return "Wind"
        case .uv: return "UV Index"
        case .feelsLike: return "Feels Like"
        case .humidity: return "Humidity"
        case .visibility: return "Visibility"
        case .pressure: return "Pressure"
        case .sunMoon: return "Sun & Moon"
        case .airQuality: return "Air Quality"
        }
    }

    var symbol: String {
        switch self {
        case .precipitation: return "drop.fill"
        case .wind: return "wind"
        case .uv: return "sun.max.fill"
        case .feelsLike: return "thermometer.medium"
        case .humidity: return "humidity.fill"
        case .visibility: return "eye.fill"
        case .pressure: return "barometer"
        case .sunMoon: return "sunrise.fill"
        case .airQuality: return "aqi.medium"
        }
    }
}
