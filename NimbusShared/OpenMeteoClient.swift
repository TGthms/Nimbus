import Foundation

public enum OpenMeteoError: Error, LocalizedError, Sendable {
    case invalidURL
    case httpStatus(Int)
    case decoding(Error)
    case emptyForecast
    case transport(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Could not build the weather request."
        case .httpStatus(let code): return "Weather service returned \(code)."
        case .decoding: return "Weather data could not be read."
        case .emptyForecast: return "No forecast was returned."
        case .transport: return "The network request failed."
        }
    }
}

public struct ForecastQuery: Equatable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var timezone: String
    public var forecastDays: Int
    public var units: UnitPreferences
    public var models: [String]
    public var includeAtmosphere: Bool
    public var includeSolar: Bool
    public var includePressureLevels: Bool

    public init(
        latitude: Double,
        longitude: Double,
        timezone: String = "auto",
        forecastDays: Int = 16,
        units: UnitPreferences = .init(),
        models: [String] = [],
        includeAtmosphere: Bool = true,
        includeSolar: Bool = false,
        includePressureLevels: Bool = false
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.timezone = timezone
        self.forecastDays = forecastDays
        self.units = units
        self.models = models
        self.includeAtmosphere = includeAtmosphere
        self.includeSolar = includeSolar
        self.includePressureLevels = includePressureLevels
    }

    public static let currentVariables = [
        "temperature_2m", "relative_humidity_2m", "apparent_temperature", "is_day",
        "precipitation", "rain", "showers", "snowfall", "weather_code", "cloud_cover",
        "pressure_msl", "surface_pressure", "wind_speed_10m", "wind_direction_10m",
        "wind_gusts_10m", "visibility"
    ]

    public static let hourlyBase = [
        "temperature_2m", "relative_humidity_2m", "dew_point_2m", "apparent_temperature",
        "precipitation_probability", "precipitation", "rain", "showers", "snowfall",
        "weather_code", "pressure_msl", "cloud_cover", "cloud_cover_low", "cloud_cover_mid",
        "cloud_cover_high", "visibility", "wind_speed_10m", "wind_direction_10m",
        "wind_gusts_10m", "uv_index", "is_day"
    ]

    public static let hourlyAtmosphere = [
        "cape", "lifted_index", "convective_inhibition", "freezing_level_height",
        "boundary_layer_height"
    ]

    public static let hourlySolar = [
        "shortwave_radiation", "direct_radiation", "diffuse_radiation", "sunshine_duration"
    ]

    public static let hourlyPressure = [
        "temperature_1000hPa", "temperature_925hPa", "temperature_850hPa",
        "temperature_700hPa", "temperature_500hPa", "temperature_300hPa",
        "relative_humidity_1000hPa", "relative_humidity_925hPa", "relative_humidity_850hPa",
        "relative_humidity_700hPa", "relative_humidity_500hPa", "relative_humidity_300hPa",
        "wind_speed_1000hPa", "wind_speed_850hPa", "wind_speed_700hPa", "wind_speed_500hPa",
        "wind_direction_1000hPa", "wind_direction_850hPa", "wind_direction_700hPa",
        "wind_direction_500hPa"
    ]

    public static let dailyVariables = [
        "weather_code", "temperature_2m_max", "temperature_2m_min",
        "apparent_temperature_max", "apparent_temperature_min",
        "sunrise", "sunset", "daylight_duration", "sunshine_duration",
        "uv_index_max", "precipitation_sum", "precipitation_hours",
        "precipitation_probability_max", "rain_sum", "showers_sum", "snowfall_sum",
        "wind_speed_10m_max", "wind_gusts_10m_max", "wind_direction_10m_dominant",
        "shortwave_radiation_sum"
    ]

    public func url(base: URL = URL(string: "https://api.open-meteo.com/v1/forecast")!) -> URL {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "timezone", value: timezone),
            URLQueryItem(name: "forecast_days", value: String(forecastDays)),
            // Always SI. Display conversion happens in WeatherFormatting so
            // imperial prefs cannot be converted twice (API + formatter).
            URLQueryItem(name: "temperature_unit", value: "celsius"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
            URLQueryItem(name: "precipitation_unit", value: "mm"),
            URLQueryItem(name: "current", value: Self.currentVariables.joined(separator: ",")),
            URLQueryItem(name: "daily", value: Self.dailyVariables.joined(separator: ","))
        ]

        var hourly = Self.hourlyBase
        if includeAtmosphere { hourly += Self.hourlyAtmosphere }
        if includeSolar { hourly += Self.hourlySolar }
        if includePressureLevels { hourly += Self.hourlyPressure }
        items.append(URLQueryItem(name: "hourly", value: hourly.joined(separator: ",")))

        if !models.isEmpty {
            items.append(URLQueryItem(name: "models", value: models.joined(separator: ",")))
        }

        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        components.queryItems = items
        return components.url!
    }

    public func airQualityURL(base: URL = URL(string: "https://air-quality-api.open-meteo.com/v1/air-quality")!) -> URL {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "timezone", value: timezone),
            URLQueryItem(name: "forecast_days", value: "5"),
            URLQueryItem(
                name: "current",
                value: "us_aqi,european_aqi,pm2_5,pm10,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone,alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen"
            ),
            URLQueryItem(
                name: "hourly",
                value: "us_aqi,pm2_5,pm10,alder_pollen,birch_pollen,grass_pollen"
            )
        ]
        return components.url!
    }

    public static func geocodingURL(name: String, count: Int = 8, language: String = "en") -> URL {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "count", value: String(count)),
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "format", value: "json")
        ]
        return components.url!
    }

    public func ensembleURL(
        model: String,
        base: URL = URL(string: "https://ensemble-api.open-meteo.com/v1/ensemble")!
    ) -> URL {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "timezone", value: timezone),
            URLQueryItem(name: "forecast_days", value: "7"),
            URLQueryItem(name: "models", value: model),
            URLQueryItem(name: "temperature_unit", value: "celsius"),
            URLQueryItem(name: "precipitation_unit", value: "mm"),
            URLQueryItem(
                name: "hourly",
                value: "temperature_2m,temperature_2m_spread,precipitation,precipitation_spread"
            )
        ]
        return components.url!
    }
}

public struct OpenMeteoClient: Sendable {
    public var session: URLSession
    public var decoder: JSONDecoder

    public init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        self.decoder = decoder
    }

    public func snapshot(fromForecastJSON data: Data, place: Place) throws -> WeatherSnapshot {
        let dto = try decode(ForecastDTO.self, from: data)
        return try Self.mapForecast(dto, place: place)
    }

    public func places(fromGeocodingJSON data: Data) throws -> [GeocodingResult] {
        let dto = try decode(GeocodingDTO.self, from: data)
        return (dto.results ?? []).map {
            GeocodingResult(
                id: $0.id,
                name: $0.name,
                latitude: $0.latitude,
                longitude: $0.longitude,
                elevation: $0.elevation,
                timezone: $0.timezone,
                country: $0.country,
                countryCode: $0.country_code,
                admin1: $0.admin1,
                population: $0.population
            )
        }
    }

    public func airQuality(fromJSON data: Data, timeZone: TimeZone) throws -> AirQualitySnapshot? {
        let dto = try decode(AirQualityDTO.self, from: data)
        return Self.mapAirQuality(dto, timeZone: timeZone)
    }

    public func forecast(for place: Place, units: UnitPreferences, includeExtras: Bool = false) async throws -> WeatherSnapshot {
        let query = ForecastQuery(
            latitude: place.latitude,
            longitude: place.longitude,
            timezone: place.timezone ?? "auto",
            units: units,
            includeAtmosphere: true,
            includeSolar: includeExtras,
            includePressureLevels: includeExtras
        )
        let forecastData = try await data(from: query.url())
        let dto = try decode(ForecastDTO.self, from: forecastData)
        var snapshot = try Self.mapForecast(dto, place: place)
        if let aqData = try? await data(from: query.airQualityURL()),
           let aq = try? decode(AirQualityDTO.self, from: aqData) {
            snapshot.airQuality = Self.mapAirQuality(aq, timeZone: snapshot.timezone)
        }
        return snapshot
    }

    public func forecastOnly(for place: Place, units: UnitPreferences) async throws -> WeatherSnapshot {
        let query = ForecastQuery(
            latitude: place.latitude,
            longitude: place.longitude,
            timezone: place.timezone ?? "auto",
            units: units
        )
        let forecastData = try await data(from: query.url())
        let dto = try decode(ForecastDTO.self, from: forecastData)
        return try Self.mapForecast(dto, place: place)
    }

    public func searchPlaces(query: String, language: String = "en") async throws -> [GeocodingResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        let data = try await data(from: ForecastQuery.geocodingURL(name: trimmed, language: language))
        let dto = try decode(GeocodingDTO.self, from: data)
        return (dto.results ?? []).map {
            GeocodingResult(
                id: $0.id,
                name: $0.name,
                latitude: $0.latitude,
                longitude: $0.longitude,
                elevation: $0.elevation,
                timezone: $0.timezone,
                country: $0.country,
                countryCode: $0.country_code,
                admin1: $0.admin1,
                population: $0.population
            )
        }
    }

    public func ensemble(for place: Place, units: UnitPreferences, model: String) async throws -> EnsembleSeries {
        let query = ForecastQuery(
            latitude: place.latitude,
            longitude: place.longitude,
            timezone: place.timezone ?? "auto",
            units: units
        )
        let data = try await data(from: query.ensembleURL(model: model))
        let dto = try decode(EnsembleDTO.self, from: data)
        let tz = TimeZone(identifier: dto.timezone ?? place.timezone ?? "GMT") ?? .gmt
        let times = (dto.hourly?.time ?? []).compactMap { OpenMeteoDateParser.date($0, timeZone: tz) }
        return EnsembleSeries(
            model: model,
            times: times,
            temperatureMean: dto.hourly?.temperature_2m ?? [],
            temperatureSpread: dto.hourly?.temperature_2m_spread ?? [],
            precipitationMean: dto.hourly?.precipitation ?? [],
            precipitationSpread: dto.hourly?.precipitation_spread ?? []
        )
    }

    public func modelComparison(for place: Place, units: UnitPreferences, models: [String]) async throws -> [ModelComparisonSeries] {
        var results: [ModelComparisonSeries] = []
        for model in models {
            let query = ForecastQuery(
                latitude: place.latitude,
                longitude: place.longitude,
                timezone: place.timezone ?? "auto",
                forecastDays: 3,
                units: units,
                models: [model],
                includeAtmosphere: false
            )
            do {
                let data = try await data(from: query.url())
                let dto = try decode(ForecastDTO.self, from: data)
                let tz = TimeZone(identifier: dto.timezone ?? "GMT") ?? .gmt
                let times = (dto.hourly?.time ?? []).compactMap { OpenMeteoDateParser.date($0, timeZone: tz) }
                results.append(
                    ModelComparisonSeries(
                        model: model,
                        title: Self.modelTitle(model),
                        times: times,
                        temperature: dto.hourly?.temperature_2m ?? [],
                        precipitation: dto.hourly?.precipitation ?? []
                    )
                )
            } catch {
                continue
            }
        }
        return results
    }

    static func mapForecast(_ dto: ForecastDTO, place: Place) throws -> WeatherSnapshot {
        let tz = TimeZone(identifier: dto.timezone ?? place.timezone ?? "GMT") ?? .gmt
        guard let currentDTO = dto.current,
              let currentTime = OpenMeteoDateParser.date(currentDTO.time, timeZone: tz)
        else {
            throw OpenMeteoError.emptyForecast
        }

        let hourlySource = dto.hourly
        var hourly: [HourlyWeather] = []
        if let hourlySource {
            for (index, timeString) in hourlySource.time.enumerated() {
                guard let time = OpenMeteoDateParser.date(timeString, timeZone: tz) else { continue }
                hourly.append(
                    HourlyWeather(
                        time: time,
                        temperature: Series.value(hourlySource.temperature_2m, index),
                        apparentTemperature: Series.value(hourlySource.apparent_temperature, index),
                        humidity: Series.value(hourlySource.relative_humidity_2m, index),
                        dewPoint: Series.value(hourlySource.dew_point_2m, index),
                        precipitationProbability: Series.value(hourlySource.precipitation_probability, index),
                        precipitation: Series.value(hourlySource.precipitation, index),
                        rain: Series.value(hourlySource.rain, index),
                        showers: Series.value(hourlySource.showers, index),
                        snowfall: Series.value(hourlySource.snowfall, index),
                        weatherCode: Series.value(hourlySource.weather_code, index) ?? 0,
                        pressureMSL: Series.value(hourlySource.pressure_msl, index),
                        cloudCover: Series.value(hourlySource.cloud_cover, index),
                        cloudCoverLow: Series.value(hourlySource.cloud_cover_low, index),
                        cloudCoverMid: Series.value(hourlySource.cloud_cover_mid, index),
                        cloudCoverHigh: Series.value(hourlySource.cloud_cover_high, index),
                        visibility: Series.value(hourlySource.visibility, index),
                        windSpeed: Series.value(hourlySource.wind_speed_10m, index),
                        windDirection: Series.value(hourlySource.wind_direction_10m, index),
                        windGusts: Series.value(hourlySource.wind_gusts_10m, index),
                        uvIndex: Series.value(hourlySource.uv_index, index),
                        isDay: (Series.value(hourlySource.is_day, index) ?? 1) == 1,
                        cape: Series.value(hourlySource.cape, index),
                        liftedIndex: Series.value(hourlySource.lifted_index, index),
                        convectiveInhibition: Series.value(hourlySource.convective_inhibition, index),
                        freezingLevelHeight: Series.value(hourlySource.freezing_level_height, index),
                        boundaryLayerHeight: Series.value(hourlySource.boundary_layer_height, index),
                        shortwaveRadiation: Series.value(hourlySource.shortwave_radiation, index),
                        directRadiation: Series.value(hourlySource.direct_radiation, index),
                        diffuseRadiation: Series.value(hourlySource.diffuse_radiation, index),
                        sunshineDuration: Series.value(hourlySource.sunshine_duration, index),
                        temperature1000hPa: Series.value(hourlySource.temperature_1000hPa, index),
                        temperature925hPa: Series.value(hourlySource.temperature_925hPa, index),
                        temperature850hPa: Series.value(hourlySource.temperature_850hPa, index),
                        temperature700hPa: Series.value(hourlySource.temperature_700hPa, index),
                        temperature500hPa: Series.value(hourlySource.temperature_500hPa, index),
                        temperature300hPa: Series.value(hourlySource.temperature_300hPa, index),
                        humidity1000hPa: Series.value(hourlySource.relative_humidity_1000hPa, index),
                        humidity925hPa: Series.value(hourlySource.relative_humidity_925hPa, index),
                        humidity850hPa: Series.value(hourlySource.relative_humidity_850hPa, index),
                        humidity700hPa: Series.value(hourlySource.relative_humidity_700hPa, index),
                        humidity500hPa: Series.value(hourlySource.relative_humidity_500hPa, index),
                        humidity300hPa: Series.value(hourlySource.relative_humidity_300hPa, index),
                        windSpeed1000hPa: Series.value(hourlySource.wind_speed_1000hPa, index),
                        windSpeed850hPa: Series.value(hourlySource.wind_speed_850hPa, index),
                        windSpeed700hPa: Series.value(hourlySource.wind_speed_700hPa, index),
                        windSpeed500hPa: Series.value(hourlySource.wind_speed_500hPa, index),
                        windDirection1000hPa: Series.value(hourlySource.wind_direction_1000hPa, index),
                        windDirection850hPa: Series.value(hourlySource.wind_direction_850hPa, index),
                        windDirection700hPa: Series.value(hourlySource.wind_direction_700hPa, index),
                        windDirection500hPa: Series.value(hourlySource.wind_direction_500hPa, index)
                    )
                )
            }
        }

        var daily: [DailyWeather] = []
        if let dailySource = dto.daily {
            for (index, timeString) in dailySource.time.enumerated() {
                guard let date = OpenMeteoDateParser.date(timeString, timeZone: tz) else { continue }
                daily.append(
                    DailyWeather(
                        date: date,
                        weatherCode: Series.value(dailySource.weather_code, index) ?? 0,
                        temperatureMax: Series.value(dailySource.temperature_2m_max, index),
                        temperatureMin: Series.value(dailySource.temperature_2m_min, index),
                        apparentMax: Series.value(dailySource.apparent_temperature_max, index),
                        apparentMin: Series.value(dailySource.apparent_temperature_min, index),
                        sunrise: Series.value(dailySource.sunrise, index).flatMap { OpenMeteoDateParser.date($0, timeZone: tz) },
                        sunset: Series.value(dailySource.sunset, index).flatMap { OpenMeteoDateParser.date($0, timeZone: tz) },
                        daylightDuration: Series.value(dailySource.daylight_duration, index),
                        sunshineDuration: Series.value(dailySource.sunshine_duration, index),
                        uvIndexMax: Series.value(dailySource.uv_index_max, index),
                        precipitationSum: Series.value(dailySource.precipitation_sum, index),
                        precipitationHours: Series.value(dailySource.precipitation_hours, index),
                        precipitationProbabilityMax: Series.value(dailySource.precipitation_probability_max, index),
                        rainSum: Series.value(dailySource.rain_sum, index),
                        showersSum: Series.value(dailySource.showers_sum, index),
                        snowfallSum: Series.value(dailySource.snowfall_sum, index),
                        windSpeedMax: Series.value(dailySource.wind_speed_10m_max, index),
                        windGustsMax: Series.value(dailySource.wind_gusts_10m_max, index),
                        windDirectionDominant: Series.value(dailySource.wind_direction_10m_dominant, index),
                        shortwaveRadiationSum: Series.value(dailySource.shortwave_radiation_sum, index),
                        moonrise: Series.value(dailySource.moonrise, index).flatMap { OpenMeteoDateParser.date($0, timeZone: tz) },
                        moonset: Series.value(dailySource.moonset, index).flatMap { OpenMeteoDateParser.date($0, timeZone: tz) },
                        moonPhase: Series.value(dailySource.moon_phase, index)
                    )
                )
            }
        }

        let nearestHour = hourly.min(by: { abs($0.time.timeIntervalSince(currentTime)) < abs($1.time.timeIntervalSince(currentTime)) })

        let current = CurrentWeather(
            time: currentTime,
            temperature: currentDTO.temperature_2m,
            apparentTemperature: currentDTO.apparent_temperature,
            humidity: currentDTO.relative_humidity_2m,
            dewPoint: nearestHour?.dewPoint,
            isDay: (currentDTO.is_day ?? 1) == 1,
            precipitation: currentDTO.precipitation,
            rain: currentDTO.rain,
            showers: currentDTO.showers,
            snowfall: currentDTO.snowfall,
            weatherCode: currentDTO.weather_code ?? 0,
            cloudCover: currentDTO.cloud_cover,
            cloudCoverLow: nearestHour?.cloudCoverLow,
            cloudCoverMid: nearestHour?.cloudCoverMid,
            cloudCoverHigh: nearestHour?.cloudCoverHigh,
            pressureMSL: currentDTO.pressure_msl,
            surfacePressure: currentDTO.surface_pressure,
            windSpeed: currentDTO.wind_speed_10m,
            windDirection: currentDTO.wind_direction_10m,
            windGusts: currentDTO.wind_gusts_10m,
            visibility: currentDTO.visibility,
            uvIndex: nearestHour?.uvIndex,
            cape: nearestHour?.cape,
            liftedIndex: nearestHour?.liftedIndex,
            convectiveInhibition: nearestHour?.convectiveInhibition,
            freezingLevelHeight: nearestHour?.freezingLevelHeight,
            boundaryLayerHeight: nearestHour?.boundaryLayerHeight,
            vapourPressureDeficit: nil,
            shortwaveRadiation: nearestHour?.shortwaveRadiation
        )

        var resolved = place
        if resolved.timezone == nil {
            resolved.timezone = dto.timezone
        }

        return WeatherSnapshot(
            place: resolved,
            fetchedAt: Date(),
            current: current,
            hourly: hourly,
            daily: daily,
            timezone: tz,
            generationTimeMS: dto.generationtime_ms
        )
    }

    static func mapAirQuality(_ dto: AirQualityDTO, timeZone: TimeZone) -> AirQualitySnapshot? {
        guard let current = dto.current,
              let time = OpenMeteoDateParser.date(current.time, timeZone: timeZone)
        else { return nil }
        var hourly: [Date: Double] = [:]
        if let hours = dto.hourly {
            for (i, t) in hours.time.enumerated() {
                if let date = OpenMeteoDateParser.date(t, timeZone: timeZone),
                   let value = hours.us_aqi?[safe: i] ?? nil {
                    hourly[date] = value
                }
            }
        }
        return AirQualitySnapshot(
            time: time,
            usAQI: current.us_aqi,
            europeanAQI: current.european_aqi,
            pm25: current.pm2_5,
            pm10: current.pm10,
            carbonMonoxide: current.carbon_monoxide,
            nitrogenDioxide: current.nitrogen_dioxide,
            sulphurDioxide: current.sulphur_dioxide,
            ozone: current.ozone,
            alderPollen: current.alder_pollen,
            birchPollen: current.birch_pollen,
            grassPollen: current.grass_pollen,
            mugwortPollen: current.mugwort_pollen,
            olivePollen: current.olive_pollen,
            ragweedPollen: current.ragweed_pollen,
            hourlyAQI: hourly
        )
    }

    public static func modelTitle(_ id: String) -> String {
        switch id {
        case "best_match": return "Best Match"
        case "ecmwf_ifs": return "ECMWF IFS"
        case "gfs_seamless": return "GFS Seamless"
        case "icon_seamless": return "ICON Seamless"
        case "jma_seamless": return "JMA Seamless"
        case "gem_seamless": return "GEM Seamless"
        case "meteofrance_seamless": return "Météo-France"
        case "ukmo_seamless": return "UK Met Office"
        case "icon_seamless_eps", "icon_eps": return "ICON EPS"
        case "gfs025": return "GFS 0.25°"
        case "gfs_seamless_eps", "gfs025_ens": return "GFS Ensemble"
        default: return id.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    public static func defaultEnsembleModel(for place: Place) -> String {
        // ICON EPS has excellent European coverage; GFS ensemble is the global fallback.
        if let tz = place.timezone, tz.hasPrefix("Europe/") {
            return "icon_seamless_eps"
        }
        return "gfs_seamless"
    }

    public func data(from url: URL) async throws -> Data {
        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw OpenMeteoError.httpStatus(http.statusCode)
            }
            return data
        } catch let error as OpenMeteoError {
            throw error
        } catch {
            throw OpenMeteoError.transport(error)
        }
    }

    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw OpenMeteoError.decoding(error)
        }
    }
}

enum Series {
    static func value<T>(_ array: [T?]?, _ index: Int) -> T? {
        guard let array, index >= 0, index < array.count else { return nil }
        return array[index]
    }

    static func value<T>(_ array: [T]?, _ index: Int) -> T? {
        guard let array, index >= 0, index < array.count else { return nil }
        return array[index]
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
