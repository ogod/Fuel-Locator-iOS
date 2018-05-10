//
//  FirstViewController.swift
//  Fuel Locator iOS
//
//  Created by Owen Godfrey on 2/5/18.
//  Copyright © 2018 Owen Godfrey. All rights reserved.
//

import UIKit
import MapKit
import CloudKit

class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {

    @IBOutlet weak var mapView: MKMapView!

    static var instance: MapViewController? = nil
    static let calendar = Calendar.current

    var globalDate: Date! = nil {
        didSet {
            print("reset for date \(globalDate)")
            Statistics.reset()
            PriceOnDay.reset()
        }
    }

    var globalProduct: Product! = nil {
        didSet {
            print("reset for product \(globalProduct?.name ?? "none")")
            Statistics.reset()
            PriceOnDay.reset()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        if MapViewController.instance == nil {
            MapViewController.instance = self
        }
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        if MapViewController.instance == nil {
            MapViewController.instance = self
        }
    }

    private let locationManager = CLLocationManager()
    private let initialRegion =
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: -31.956289,
                                                          longitude: 115.862838),
                           span: MKCoordinateSpan(latitudeDelta: 0.2,
                                                  longitudeDelta: 0.2))

    fileprivate func addAnnotations() {
        var annotations = [MKPointAnnotation]()
        for st in Station.all.map({ $0.value }) {
            if st.latitude != 0 && st.longitude != 0 {
                let annot = StationAnnotation(st)
                annotations.append(annot)
            }
        }
        self.mapView.addAnnotations(annotations)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        print("View for annotation")
        if let station = annotation as? StationAnnotation {
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: "station") as? MKMarkerAnnotationView
            if view == nil {
                view = StationMarkerAnnotationView(annotation: nil, reuseIdentifier: "station")
            }
            view?.annotation = station
            view?.glyphImage = station.station.brand?.image
            view?.markerTintColor = UIColor.gray
            view?.displayPriority = .defaultHigh
           return view
        } else if let cluster = annotation as? MKClusterAnnotation {
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: "cluster") as? MKMarkerAnnotationView
            if view == nil {
                view = ClusterMarkerAnnotationView(annotation: nil, reuseIdentifier: "cluster")
            }
            view?.annotation = cluster
            view?.glyphText = "\(cluster.memberAnnotations.count)"
            view?.markerTintColor = UIColor.darkGray
            return view
        } else {
            return nil
        }
    }

    func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
        mapView.register(StationMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "station")
        mapView.register(ClusterMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "cluster")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        locationManager.delegate = self
        mapView.showsUserLocation = true
        mapView.setRegion(initialRegion, animated: true)

        let button = MKUserTrackingButton(mapView: mapView)
        button.translatesAutoresizingMaskIntoConstraints = false
        mapView.addSubview(button)
        NSLayoutConstraint.activate([button.bottomAnchor.constraint(equalTo: mapView.bottomAnchor, constant: -4),
                                     button.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -4)])

        FLOCloud.shared.alertUserToEnterICloudCredentials(controller: self)

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            _ = Brand.all
            _ = Product.all
            _ = Suburb.all
            _ = Region.all
            _ = Station.all
            self.globalDate = MapViewController.calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!
            self.globalProduct = Product.all[1]!
            _ = PriceOnDay.all
            _ = Statistics.all
            DispatchQueue.main.async {
                self.addAnnotations()
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

