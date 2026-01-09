import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var location: CLLocation?
    @Published var authorization: CLAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5

        // ✅ use last known location immediately if available
        location = manager.location
        authorization = manager.authorizationStatus
        
        print("📍 LocationService initialized")
        print("   Initial location: \(location?.coordinate.latitude ?? 0), \(location?.coordinate.longitude ?? 0)")
        print("   Authorization: \(authorization.rawValue)")
    }

    // MARK: - Public API

    func requestPermission() {
        print("📍 Requesting location permission...")
        manager.requestWhenInUseAuthorization()
    }

    /// One-shot location request (fast refresh)
    func requestOneShotLocation() {
        let status = manager.authorizationStatus
        print("📍 One-shot location request (status: \(status.rawValue))")
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        } else {
            errorMessage = "Location permission not granted"
            print("❌ Location permission not granted")
        }
    }

    /// Continuous updates (good for map tracking)
    func start() {
        let status = manager.authorizationStatus
        print("📍 Starting location updates (status: \(status.rawValue))")
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
            // also one-shot immediately for quick result
            manager.requestLocation()
        } else if status == .notDetermined {
            print("📍 Authorization not determined, requesting...")
            manager.requestWhenInUseAuthorization()
        } else {
            errorMessage = "Location permission denied"
            print("❌ Location permission denied")
        }
    }

    func stop() {
        print("📍 Stopping location updates")
        manager.stopUpdatingLocation()
    }

    // MARK: - Authorization (iOS 14+)
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        print("📍 Authorization changed: \(authorization.rawValue)")

        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
            print("✅ Location authorized, starting updates")
            manager.startUpdatingLocation()
            manager.requestLocation()
        } else if authorization == .denied || authorization == .restricted {
            errorMessage = "Location access denied. Please enable in Settings."
            print("❌ Location access denied")
        } else {
            manager.stopUpdatingLocation()
        }
    }

    // MARK: - Authorization (iOS 13 and earlier fallback)
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorization = status
        print("📍 [iOS 13] Authorization changed: \(status.rawValue)")

        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
            manager.requestLocation()
        } else {
            manager.stopUpdatingLocation()
        }
    }

    // MARK: - Updates
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // take the most recent valid location
        if let last = locations.last {
            print("📍 Location updated:")
            print("   Lat: \(last.coordinate.latitude)")
            print("   Lon: \(last.coordinate.longitude)")
            print("   Accuracy: \(last.horizontalAccuracy)m")
            print("   Timestamp: \(last.timestamp)")
            
            // Only update if accuracy is reasonable
            if last.horizontalAccuracy < 100 {
                location = last
                errorMessage = nil
            } else {
                print("⚠️ Location accuracy too low: \(last.horizontalAccuracy)m")
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
        errorMessage = error.localizedDescription
        
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                errorMessage = "Location access denied"
            case .locationUnknown:
                errorMessage = "Location unknown, trying again..."
                // Try again after a moment
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    self.requestOneShotLocation()
                }
            default:
                break
            }
        }
    }
}
