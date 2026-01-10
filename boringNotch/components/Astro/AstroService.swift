//
//  AstroService.swift
//  boringNotch
//
//  Service for fetching astro weather data
//

import Foundation
import Supabase

@MainActor
final class AstroService: ObservableObject {
    static let shared = AstroService()

    @Published var places: [PlaceWithForecast] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    private init() {}

    // MARK: - Fetch Saved Places

    func fetchSavedPlaces() async {
        guard AuthManager.shared.isAuthenticated,
              let userId = AuthManager.shared.currentUser?.id else {
            error = "Please sign in to view your saved places"
            return
        }

        isLoading = true
        error = nil

        do {
            // Query the astro.saved_places table
            let response: PostgrestResponse<[SavedPlacesRow]> = try await supabase
                .schema("astro")
                .from("saved_places")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()

            if let row = response.value.first {
                // Decode the JSONB places array
                let placesData = try JSONSerialization.data(withJSONObject: row.places)
                let savedPlaces = try JSONDecoder().decode([SavedPlace].self, from: placesData)

                // Create PlaceWithForecast for each place
                places = savedPlaces.map { PlaceWithForecast(place: $0) }

                // Fetch forecasts for places with autoLoadWeather enabled
                await fetchAllForecasts()
            } else {
                places = []
            }
        } catch {
            self.error = "Failed to load places: \(error.localizedDescription)"
            print("AstroService error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Fetch Cloud Forecast

    func fetchForecast(for placeId: String) async {
        guard let index = places.firstIndex(where: { $0.id == placeId }) else { return }

        places[index].isLoading = true
        places[index].error = nil

        let place = places[index].place

        do {
            let forecast = try await fetchCloudForecast(lat: place.lat, lng: place.lng)
            places[index].forecast = forecast
        } catch {
            places[index].error = error.localizedDescription
        }

        places[index].isLoading = false
    }

    func fetchAllForecasts() async {
        await withTaskGroup(of: Void.self) { group in
            for place in places {
                if place.place.autoLoadWeather == true {
                    group.addTask {
                        await self.fetchForecast(for: place.id)
                    }
                }
            }
        }
    }

    // MARK: - Cloud Forecast API

    private func fetchCloudForecast(lat: Double, lng: Double) async throws -> CloudForecast {
        let urlString = "https://astro.zitti.ro/api/cloud-forecast?lat=\(lat)&lng=\(lng)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let forecast = try JSONDecoder().decode(CloudForecast.self, from: data)
        return forecast
    }
}

// MARK: - Supabase Row Model

private struct SavedPlacesRow: Decodable {
    let user_id: String
    let places: [[String: Any]]

    enum CodingKeys: String, CodingKey {
        case user_id
        case places
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user_id = try container.decode(String.self, forKey: .user_id)
        // Decode places as raw JSON
        if let placesData = try? container.decode([[String: AnyCodable]].self, forKey: .places) {
            places = placesData.map { dict in
                dict.mapValues { $0.value }
            }
        } else {
            places = []
        }
    }
}

// Helper for decoding arbitrary JSON
private struct AnyCodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
}
