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

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            loading = false
            errorMessage = "请在系统设置中允许位置权限"
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        loading = false
        coordinate = locations.last?.coordinate
        if coordinate == nil { errorMessage = "暂时无法获取当前位置" }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        loading = false
        errorMessage = error.localizedDescription
    }
}
