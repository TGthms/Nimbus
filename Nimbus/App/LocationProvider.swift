import Foundation
import CoreLocation

@MainActor
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorization: CLAuthorizationStatus
    @Published private(set) var coordinate: CLLocationCoordinate2D?
    @Published private(set) var resolvedName: String?
    @Published private(set) var resolvedAdmin: String?
    @Published private(set) var resolvedCountry: String?
    @Published private(set) var resolvedTimeZone: String?
    @Published var lastError: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        manager.distanceFilter = 1000
    }

    var isAuthorized: Bool {
        authorization.rawValue >= 3
    }

    func request() {
        manager.requestWhenInUseAuthorization()
        if isAuthorized {
            manager.requestLocation()
        }
    }

    func refresh() {
        guard isAuthorized else { return }
        manager.requestLocation()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if self.isAuthorized {
                self.manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coarse = LocationPrivacy.approximate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        let snapped = CLLocation(latitude: coarse.latitude, longitude: coarse.longitude)
        Task { @MainActor in
            self.coordinate = snapped.coordinate
            await self.reverseGeocode(snapped)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            self.lastError = message
        }
    }

    private func reverseGeocode(_ location: CLLocation) async {
        do {
            let marks = try await geocoder.reverseGeocodeLocation(location)
            guard let mark = marks.first else { return }
            resolvedName = mark.locality ?? mark.subLocality ?? mark.name ?? "My Location"
            resolvedAdmin = mark.administrativeArea
            resolvedCountry = mark.country
            resolvedTimeZone = mark.timeZone?.identifier
        } catch {
            lastError = error.localizedDescription
        }
    }

    func currentPlace(existing: Place) -> Place {
        var place = existing
        if let coordinate {
            let coarse = LocationPrivacy.approximate(latitude: coordinate.latitude, longitude: coordinate.longitude)
            place.latitude = coarse.latitude
            place.longitude = coarse.longitude
        }
        if let resolvedName { place.name = resolvedName }
        if let resolvedAdmin { place.admin1 = resolvedAdmin }
        if let resolvedCountry { place.country = resolvedCountry }
        if let resolvedTimeZone { place.timezone = resolvedTimeZone }
        place.isCurrentLocation = true
        return place
    }
}
