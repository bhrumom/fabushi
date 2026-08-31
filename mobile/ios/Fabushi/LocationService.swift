import CoreLocation
import Observation

@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    var coordinate: CLLocationCoordinate2D?
    var errorMessage: String?
    var loading = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        coordinate = nil
        errorMessage = nil
        loading = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            loading = false
            errorMessage = "请在系统设置中允许位置权限"
        @unknown default:
            loading = false
            errorMessage = "无法读取位置授权状态"
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let shouldRequest = manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways
        let isDenied = manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
        Task { @MainActor [weak self] in
            guard let self else { return }
            if shouldRequest {
                self.manager.requestLocation()
            } else if isDenied {
                self.loading = false
                self.errorMessage = "请在系统设置中允许位置权限"
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latitude = locations.last?.coordinate.latitude
        let longitude = locations.last?.coordinate.longitude
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.loading = false
            if let latitude, let longitude {
                self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            } else {
                self.coordinate = nil
                self.errorMessage = "暂时无法获取当前位置"
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.loading = false
            self.errorMessage = message
        }
    }
}
