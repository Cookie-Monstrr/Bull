import Foundation
@preconcurrency import CoreLocation
import Combine

enum LocationPermissionState: Equatable {
    case servicesOff
    case notRequested
    case whileUsing
    case always
    case denied
    case restricted
    case unknown

    var label: String {
        switch self {
        case .servicesOff: return "Location Services off"
        case .notRequested: return "Not requested"
        case .whileUsing: return "While using Bull"
        case .always: return "Always allowed"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .unknown: return "Unknown"
        }
    }
}

enum LocationRequestError: LocalizedError, Equatable {
    case servicesOff
    case permissionRequired
    case denied
    case restricted
    case timedOut
    case unusableFix
    case superseded
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .servicesOff:
            return "Location Services are off. Enable them in Settings, or place the pin manually."
        case .permissionRequired:
            return "Allow location while using Bull, or place the pin manually."
        case .denied:
            return "Location access is denied. Open Settings, or place the pin manually."
        case .restricted:
            return "Location access is restricted on this iPhone. Place the pin manually."
        case .timedOut:
            return "Bull could not get a location fix in time. Search or place the pin manually."
        case .unusableFix:
            return "The available location was stale or too inaccurate. Search or place the pin manually."
        case .superseded:
            return "A newer location request replaced this one."
        case .failed(let message):
            return "Location failed: \(message)"
        }
    }
}

@MainActor
final class HighRiskZoneService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var locationServicesEnabled: Bool
    @Published private(set) var monitoredZoneIDs: Set<String> = []
    @Published private(set) var monitoringFailedZoneIDs: Set<String> = []
    @Published private(set) var regionStates: [String: CLRegionState] = [:]
    @Published private(set) var isFindingLocation = false
    @Published var lastError: String?

    private let manager = CLLocationManager()
    private var zonesByID: [String: HighRiskZone] = [:]
    private var eventHandler: ((String, ZoneEventKind) -> Void)?
    private var pendingEvents: [(String, ZoneEventKind)] = []
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var locationRequestID: UUID?
    private var timeoutTask: Task<Void, Never>?
    private let prefix = "bull.zone."

    var permissionState: LocationPermissionState {
        guard locationServicesEnabled else { return .servicesOff }
        switch authorizationStatus {
        case .authorizedAlways: return .always
        case .authorizedWhenInUse: return .whileUsing
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notRequested
        @unknown default: return .unknown
        }
    }

    var authorizationLabel: String { permissionState.label }

    override init() {
        authorizationStatus = .notDetermined
        // The synchronous availability check can stall the main thread on current SDKs.
        // Start optimistically, then refresh it off-main after the manager is configured.
        locationServicesEnabled = true
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
        Task { [weak self] in await self?.refreshPermissionState() }
    }

    func refreshPermissionState() async {
        let enabled = await Task.detached(priority: .utility) {
            CLLocationManager.locationServicesEnabled()
        }.value
        locationServicesEnabled = enabled
        authorizationStatus = manager.authorizationStatus
    }

    func requestWhenInUseAuthorization() async {
        await refreshPermissionState()
        guard locationServicesEnabled else {
            lastError = LocationRequestError.servicesOff.localizedDescription
            return
        }
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    /// Called only after the user explicitly enables background monitoring. iOS normally
    /// requires the While Using step before offering Always.
    func requestBackgroundMonitoringAuthorization() async {
        await refreshPermissionState()
        switch permissionState {
        case .notRequested:
            manager.requestWhenInUseAuthorization()
        case .whileUsing:
            manager.requestAlwaysAuthorization()
        case .always:
            if let eventHandler { configure(zones: Array(zonesByID.values), onEvent: eventHandler) }
        case .servicesOff:
            lastError = LocationRequestError.servicesOff.localizedDescription
        case .denied:
            lastError = LocationRequestError.denied.localizedDescription
        case .restricted:
            lastError = LocationRequestError.restricted.localizedDescription
        case .unknown:
            lastError = LocationRequestError.permissionRequired.localizedDescription
        }
    }

    /// One foreground fix with a single checked continuation, a deterministic timeout,
    /// and basic freshness/accuracy screening. Every path ends the finding state.
    func currentLocation(timeoutSeconds: Double = 12) async throws -> CLLocation {
        await refreshPermissionState()
        guard locationServicesEnabled else { throw LocationRequestError.servicesOff }
        switch permissionState {
        case .denied: throw LocationRequestError.denied
        case .restricted: throw LocationRequestError.restricted
        case .unknown, .servicesOff: throw LocationRequestError.permissionRequired
        case .notRequested, .whileUsing, .always: break
        }

        finishLocationRequest(.failure(LocationRequestError.superseded))
        let requestID = UUID()
        locationRequestID = requestID
        isFindingLocation = true
        lastError = nil

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            timeoutTask = Task { [weak self] in
                try? await Task<Never, Never>.sleep(for: .seconds(max(3, timeoutSeconds)))
                guard !Task.isCancelled else { return }
                guard self?.locationRequestID == requestID else { return }
                self?.finishLocationRequest(.failure(LocationRequestError.timedOut))
            }
            if authorizationStatus == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
        }
    }

    func configure(
        zones: [HighRiskZone],
        onEvent: @escaping (String, ZoneEventKind) -> Void
    ) {
        authorizationStatus = manager.authorizationStatus
        Task { [weak self] in await self?.refreshPermissionState() }
        zonesByID = zones.reduce(into: [:]) { result, zone in result[zone.id] = zone }
        eventHandler = onEvent
        if !pendingEvents.isEmpty {
            let pending = pendingEvents
            pendingEvents.removeAll()
            for (id, kind) in pending where zonesByID[id]?.enabled == true {
                onEvent(id, kind)
            }
        }

        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            lastError = "Geofence monitoring is unavailable on this device."
            monitoredZoneIDs = []
            return
        }

        let desired = Set(zones.filter(\.enabled).prefix(20).map(\.id))
        var restartIDs = Set<String>()
        for region in manager.monitoredRegions {
            guard let id = zoneID(from: region.identifier) else { continue }
            let configured = zonesByID[id]
            let circular = region as? CLCircularRegion
            let definitionChanged: Bool
            if let configured, let circular {
                definitionChanged = abs(circular.center.latitude - configured.latitude) > 0.000_001 ||
                    abs(circular.center.longitude - configured.longitude) > 0.000_001 ||
                    abs(circular.radius - min(configured.radiusMetres, manager.maximumRegionMonitoringDistance)) > 1
            } else {
                definitionChanged = configured != nil
            }
            if !desired.contains(id) || configured == nil || definitionChanged {
                if definitionChanged { restartIDs.insert(id) }
                manager.stopMonitoring(for: region)
                monitoredZoneIDs.remove(id)
            }
        }

        guard permissionState == .always else {
            monitoredZoneIDs = Set(manager.monitoredRegions.compactMap { zoneID(from: $0.identifier) })
            return
        }

        var currentlyMonitored = Set(manager.monitoredRegions.compactMap { zoneID(from: $0.identifier) })
            .subtracting(restartIDs)
        for zone in zones where zone.enabled && !currentlyMonitored.contains(zone.id) {
            guard currentlyMonitored.count < 20 else { break }
            let center = CLLocationCoordinate2D(latitude: zone.latitude, longitude: zone.longitude)
            guard CLLocationCoordinate2DIsValid(center) else {
                monitoringFailedZoneIDs.insert(zone.id)
                continue
            }
            let maximum = max(1, manager.maximumRegionMonitoringDistance)
            let radius = min(maximum, max(75, zone.radiusMetres))
            let region = CLCircularRegion(center: center, radius: radius, identifier: prefix + zone.id)
            region.notifyOnEntry = true
            region.notifyOnExit = true
            manager.startMonitoring(for: region)
            manager.requestState(for: region)
            currentlyMonitored.insert(zone.id)
            monitoringFailedZoneIDs.remove(zone.id)
        }
        monitoredZoneIDs = currentlyMonitored
    }

    func reconcileConfiguredZones(_ zones: [HighRiskZone]) {
        guard let eventHandler else {
            zonesByID = zones.reduce(into: [:]) { result, zone in result[zone.id] = zone }
            return
        }
        configure(zones: zones, onEvent: eventHandler)
    }

    /// Ask iOS to restate every existing Bull region. Call this on launch/foreground,
    /// rather than on every unrelated data save that happens to reconfigure the service.
    func requestMonitoredRegionStates() {
        for region in manager.monitoredRegions {
            guard let id = zoneID(from: region.identifier), zonesByID[id]?.enabled == true else { continue }
            manager.requestState(for: region)
        }
    }

    /// Reconciles the event-backed occupancy model with one current foreground fix.
    /// Region monitoring remains the background source; this closes the important gap
    /// where iOS has not delivered an entry transition or monitoring began while already
    /// inside a zone.
    @discardableResult
    func refreshCurrentZoneStates(timeoutSeconds: Double = 12) async -> Bool {
        await refreshPermissionState()
        let activeZones = zonesByID.values.filter(\.enabled)
        guard !activeZones.isEmpty else {
            lastError = nil
            return true
        }
        guard permissionState == .always || permissionState == .whileUsing else {
            lastError = LocationRequestError.permissionRequired.localizedDescription
            return false
        }
        do {
            let location = try await currentLocation(timeoutSeconds: timeoutSeconds)
            for zone in activeZones {
                let centre = CLLocation(latitude: zone.latitude, longitude: zone.longitude)
                let maximum = max(1, manager.maximumRegionMonitoringDistance)
                let effectiveRadius = min(maximum, max(75, zone.radiusMetres))
                let state: CLRegionState = location.distance(from: centre) <= effectiveRadius
                    ? .inside
                    : .outside
                regionStates[zone.id] = state
                deliverOrBuffer(
                    zoneID: zone.id,
                    kind: state == .inside ? .entered : .exited
                )
            }
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func regionState(for zoneID: String) -> CLRegionState {
        regionStates[zoneID] ?? .unknown
    }

    func stopMonitoring(zoneID: String) {
        for region in manager.monitoredRegions where region.identifier == prefix + zoneID {
            manager.stopMonitoring(for: region)
        }
        monitoredZoneIDs.remove(zoneID)
        monitoringFailedZoneIDs.remove(zoneID)
        regionStates.removeValue(forKey: zoneID)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus != .denied { locationServicesEnabled = true }
        Task { [weak self] in await self?.refreshPermissionState() }
        if locationContinuation != nil {
            switch permissionState {
            case .whileUsing, .always:
                manager.requestLocation()
            case .denied:
                finishLocationRequest(.failure(LocationRequestError.denied))
            case .restricted:
                finishLocationRequest(.failure(LocationRequestError.restricted))
            case .servicesOff:
                finishLocationRequest(.failure(LocationRequestError.servicesOff))
            case .notRequested:
                break
            case .unknown:
                finishLocationRequest(.failure(LocationRequestError.permissionRequired))
            }
        }
        if permissionState == .always, let eventHandler {
            configure(zones: Array(zonesByID.values), onEvent: eventHandler)
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let id = zoneID(from: region.identifier) else { return }
        regionStates[id] = .inside
        deliverOrBuffer(zoneID: id, kind: .entered)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let id = zoneID(from: region.identifier) else { return }
        regionStates[id] = .outside
        deliverOrBuffer(zoneID: id, kind: .exited)
    }

    func locationManager(
        _ manager: CLLocationManager,
        didDetermineState state: CLRegionState,
        for region: CLRegion
    ) {
        guard let id = zoneID(from: region.identifier), let zone = zonesByID[id] else { return }
        regionStates[id] = state
        if state == .inside, zone.enabled {
            deliverOrBuffer(zoneID: id, kind: .entered)
        } else if state == .outside {
            deliverOrBuffer(zoneID: id, kind: .exited)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let recentCutoff = Date().addingTimeInterval(-30)
        let usable = locations
            .filter {
                $0.timestamp >= recentCutoff && $0.horizontalAccuracy >= 0 &&
                $0.horizontalAccuracy <= 200 && CLLocationCoordinate2DIsValid($0.coordinate)
            }
            .min(by: { $0.horizontalAccuracy < $1.horizontalAccuracy })
        if let usable {
            finishLocationRequest(.success(usable))
        } else {
            finishLocationRequest(.failure(LocationRequestError.unusableFix))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let failure = LocationRequestError.failed(error.localizedDescription)
        lastError = failure.localizedDescription
        finishLocationRequest(.failure(failure))
    }

    func locationManager(
        _ manager: CLLocationManager,
        monitoringDidFailFor region: CLRegion?,
        withError error: Error
    ) {
        lastError = "Zone monitoring failed: \(error.localizedDescription)"
        if let region, let id = zoneID(from: region.identifier) {
            monitoringFailedZoneIDs.insert(id)
            monitoredZoneIDs.remove(id)
            regionStates[id] = .unknown
        }
        monitoredZoneIDs = Set(manager.monitoredRegions.compactMap { zoneID(from: $0.identifier) })
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        if let id = zoneID(from: region.identifier) {
            monitoredZoneIDs.insert(id)
            monitoringFailedZoneIDs.remove(id)
        }
    }

    private func finishLocationRequest(_ result: Result<CLLocation, Error>) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        locationRequestID = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        isFindingLocation = false
        if case .failure(let error) = result, (error as? LocationRequestError) != .superseded {
            lastError = error.localizedDescription
        }
        continuation.resume(with: result)
    }

    private func zoneID(from identifier: String) -> String? {
        guard identifier.hasPrefix(prefix) else { return nil }
        return String(identifier.dropFirst(prefix.count))
    }

    private func deliverOrBuffer(zoneID: String, kind: ZoneEventKind) {
        if let eventHandler, let zone = zonesByID[zoneID] {
            if zone.enabled { eventHandler(zoneID, kind) }
        } else if !pendingEvents.contains(where: { $0.0 == zoneID && $0.1 == kind }) {
            pendingEvents.append((zoneID, kind))
        }
    }
}
