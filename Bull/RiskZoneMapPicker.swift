import SwiftUI
import MapKit
import Combine

/// A small UIKit-backed map gives Bull reliable tap-to-place and draggable-pin behaviour
/// while retaining an exact visible radius circle on iOS 17.
struct RiskZoneMapPicker: UIViewRepresentable {
    @Binding var coordinate: CLLocationCoordinate2D?
    var radiusMetres: Double
    var onManualCoordinateChange: () -> Void = { }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.pointOfInterestFilter = .includingAll
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.mapTapped(_:)))
        tap.cancelsTouchesInView = false
        map.addGestureRecognizer(tap)
        context.coordinator.map = map
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateAnnotation(on: map, coordinate: coordinate, radius: radiusMetres)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RiskZoneMapPicker
        weak var map: MKMapView?
        private let annotation = MKPointAnnotation()
        private var lastCoordinate: CLLocationCoordinate2D?
        private var lastRadius: Double?

        init(parent: RiskZoneMapPicker) { self.parent = parent }

        @objc func mapTapped(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, let map else { return }
            let point = gesture.location(in: map)
            let coordinate = map.convert(point, toCoordinateFrom: map)
            guard CLLocationCoordinate2DIsValid(coordinate) else { return }
            annotation.coordinate = coordinate
            parent.coordinate = coordinate
            parent.onManualCoordinateChange()
            updateCircle(on: map, coordinate: coordinate, radius: parent.radiusMetres)
        }

        func updateAnnotation(
            on map: MKMapView,
            coordinate: CLLocationCoordinate2D?,
            radius: Double
        ) {
            guard let coordinate, CLLocationCoordinate2DIsValid(coordinate) else {
                if map.annotations.contains(where: { $0 === annotation }) { map.removeAnnotation(annotation) }
                map.removeOverlays(map.overlays)
                lastCoordinate = nil
                return
            }
            if !map.annotations.contains(where: { $0 === annotation }) {
                annotation.coordinate = coordinate
                map.addAnnotation(annotation)
            }
            let changed = lastCoordinate.map {
                abs($0.latitude - coordinate.latitude) > 0.000_001 ||
                abs($0.longitude - coordinate.longitude) > 0.000_001
            } ?? true
            if changed {
                annotation.coordinate = coordinate
                let region = MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: max(700, radius * 4),
                    longitudinalMeters: max(700, radius * 4)
                )
                map.setRegion(region, animated: lastCoordinate != nil)
            }
            if changed || lastRadius != radius {
                updateCircle(on: map, coordinate: coordinate, radius: radius)
            }
            lastCoordinate = coordinate
            lastRadius = radius
        }

        private func updateCircle(on map: MKMapView, coordinate: CLLocationCoordinate2D, radius: Double) {
            map.removeOverlays(map.overlays)
            map.addOverlay(MKCircle(center: coordinate, radius: max(75, radius)))
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation === self.annotation else { return nil }
            let identifier = "bull-risk-zone-pin"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            view.isDraggable = true
            view.markerTintColor = .systemOrange
            view.glyphImage = UIImage(systemName: "shield.fill")
            return view
        }

        func mapView(
            _ mapView: MKMapView,
            annotationView view: MKAnnotationView,
            didChange newState: MKAnnotationView.DragState,
            fromOldState oldState: MKAnnotationView.DragState
        ) {
            guard (newState == .ending || newState == .canceling),
                  let coordinate = view.annotation?.coordinate else { return }
            annotation.coordinate = coordinate
            parent.coordinate = coordinate
            parent.onManualCoordinateChange()
            lastCoordinate = coordinate
            updateCircle(on: mapView, coordinate: coordinate, radius: parent.radiusMetres)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let circle = overlay as? MKCircle else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKCircleRenderer(circle: circle)
            renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.14)
            renderer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.75)
            renderer.lineWidth = 2
            return renderer
        }
    }
}

@MainActor
final class RiskZonePlaceSearch: ObservableObject {
    @Published private(set) var results: [MKMapItem] = []
    @Published private(set) var isSearching = false
    @Published var lastError: String?

    func clear() { results = [] }

    func search(_ query: String, near coordinate: CLLocationCoordinate2D?) async {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { results = []; return }
        isSearching = true
        lastError = nil
        defer { isSearching = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = clean
        if let coordinate {
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 20_000,
                longitudinalMeters: 20_000
            )
        }
        do {
            let response = try await MKLocalSearch(request: request).start()
            results = Array(response.mapItems.prefix(6))
            if results.isEmpty { lastError = "No matching place found. You can tap the map instead." }
        } catch {
            results = []
            lastError = "Place search failed: \(error.localizedDescription)"
        }
    }
}
