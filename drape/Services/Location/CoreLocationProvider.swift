//
//  CoreLocationProvider.swift
//  drape
//
//  CoreLocation-backed implementation of LocationProvider.
//

import Foundation
import CoreLocation
import MapKit

/// Requests "when in use" location permission if needed, then returns the
/// current coordinate. Uses a continuation so callers get a clean async/await
/// interface without exposing CLLocationManager's delegate pattern.
final class CoreLocationProvider: NSObject, LocationProvider, @unchecked Sendable {
    private let manager = CLLocationManager()
    /// Non-nil while a request is in flight.
    private var continuation: CheckedContinuation<Coordinate, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer // city-level is fine for weather
    }

    /// Reverse-geocodes a coordinate to its city name for display (iOS 26 MapKit).
    func placeName(for coordinate: Coordinate) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        guard let item = try? await request.mapItems.first else { return nil }
        let reps = item.addressRepresentations
        return reps?.cityName ?? reps?.cityWithContext ?? item.name
    }

    func currentCoordinate() async throws -> Coordinate {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            throw LocationError.permissionDenied
        case .notDetermined:
            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        default:
            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                manager.requestLocation()
            }
        }
    }
}

extension CoreLocationProvider: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coordinate = Coordinate(latitude: location.coordinate.latitude,
                                    longitude: location.coordinate.longitude)
        continuation?.resume(returning: coordinate)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let mapped: LocationError = (error as? CLError)?.code == .denied
            ? .permissionDenied : .unavailable
        continuation?.resume(throwing: mapped)
        continuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission just granted; now actually request the location.
            manager.requestLocation()
        case .denied, .restricted:
            continuation?.resume(throwing: LocationError.permissionDenied)
            continuation = nil
        default:
            break
        }
    }
}
