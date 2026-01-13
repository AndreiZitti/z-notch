//
//  AstroView.swift
//  boringNotch
//
//  View for displaying astro weather data in the notch
//

import SwiftUI

struct AstroView: View {
    @StateObject private var service = AstroService.shared
    @ObservedObject private var authManager = AuthManager.shared

    var body: some View {
        VStack(spacing: 8) {
            if !authManager.isAuthenticated {
                signInPrompt
            } else if service.isLoading && service.places.isEmpty {
                loadingView
            } else if let error = service.error {
                errorView(error)
            } else if service.places.isEmpty {
                emptyView
            } else {
                placesGrid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .task {
            if authManager.isAuthenticated && service.places.isEmpty {
                await service.fetchSavedPlaces()
            }
        }
    }

    // MARK: - Subviews

    private var signInPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("Sign in to see your places")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading places...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task {
                    await service.fetchSavedPlaces()
                }
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(.accentColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "star.slash")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("No saved places")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placesGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(service.places) { placeWithForecast in
                    PlaceCard(placeWithForecast: placeWithForecast)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Place Card

struct PlaceCard: View {
    let placeWithForecast: PlaceWithForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with name and rating
            HStack {
                Text(placeWithForecast.place.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Spacer()

                if let rating = placeWithForecast.currentRating {
                    Text(rating.emoji)
                        .font(.caption)
                }
            }

            if placeWithForecast.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.6)
                    Spacer()
                }
            } else if let forecast = placeWithForecast.forecast {
                // Current conditions
                HStack(spacing: 8) {
                    // Cloud cover
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clouds")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text("\(forecast.hours.first?.cloudTotal ?? 0)%")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }

                    // Rating
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rating")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(forecast.hours.first?.rating.rawValue.capitalized ?? "-")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(ratingColor(forecast.hours.first?.rating))
                    }

                    // Best window
                    if let bestWindow = forecast.bestWindows.first {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Best")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(formatTime(bestWindow.time))
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }
                }
            } else if let error = placeWithForecast.error {
                Text(error)
                    .font(.system(size: 9))
                    .foregroundColor(.red)
                    .lineLimit(2)
            } else {
                Text("Tap to load")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .frame(width: 140)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            if placeWithForecast.forecast == nil && !placeWithForecast.isLoading {
                Task {
                    await AstroService.shared.fetchForecast(for: placeWithForecast.id)
                }
            }
        }
    }

    private func ratingColor(_ rating: CloudRating?) -> Color {
        guard let rating = rating else { return .secondary }
        switch rating {
        case .excellent: return .green
        case .great: return .mint
        case .good: return .yellow
        case .poor: return .orange
        case .bad: return .red
        }
    }

    private func formatTime(_ isoTime: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        guard let date = formatter.date(from: isoTime) else { return isoTime }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        return timeFormatter.string(from: date)
    }
}

#Preview {
    AstroView()
        .frame(width: 400, height: 120)
        .background(.black)
}
