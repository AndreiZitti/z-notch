//
//  AstroModels.swift
//  boringNotch
//
//  Models for astro weather data
//

import Foundation

// MARK: - Saved Place Model

struct SavedPlace: Codable, Identifiable {
    let id: String
    let lat: Double
    let lng: Double
    let name: String
    let label: String?
    let bortle: Int?
    let savedAt: String
    let autoLoadWeather: Bool?
}

// MARK: - Cloud Forecast Models

struct CloudForecast: Codable {
    let location: ForecastLocation
    let generatedAt: String
    let hours: [HourlyForecast]
    let bestWindows: [BestWindow]
}

struct ForecastLocation: Codable {
    let lat: Double
    let lng: Double
    let timezone: String
}

struct HourlyForecast: Codable, Identifiable {
    var id: String { time }
    let time: String
    let isNight: Bool
    let cloudTotal: Int
    let cloudLow: Int
    let cloudMid: Int
    let cloudHigh: Int
    let precipitation: Double
    let rating: CloudRating
}

struct BestWindow: Codable, Identifiable {
    var id: String { time }
    let time: String
    let cloudTotal: Int
    let rating: CloudRating
}

enum CloudRating: String, Codable {
    case excellent
    case great
    case good
    case poor
    case bad

    var color: String {
        switch self {
        case .excellent: return "green"
        case .great: return "mint"
        case .good: return "yellow"
        case .poor: return "orange"
        case .bad: return "red"
        }
    }

    var emoji: String {
        switch self {
        case .excellent: return "🌟"
        case .great: return "✨"
        case .good: return "🌤"
        case .poor: return "☁️"
        case .bad: return "🌧"
        }
    }
}

// MARK: - Place with Forecast

struct PlaceWithForecast: Identifiable {
    let place: SavedPlace
    var forecast: CloudForecast?
    var isLoading: Bool = false
    var error: String?

    var id: String { place.id }

    var currentRating: CloudRating? {
        forecast?.hours.first?.rating
    }

    var currentCloudCover: Int? {
        forecast?.hours.first?.cloudTotal
    }
}
