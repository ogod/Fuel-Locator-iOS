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

    var refreshFlag = false

    func refresh() {
        guard !refreshFlag && globalProduct != nil else {
            return
        }
        refreshFlag = true
        DispatchQueue.global().async {
            Statistics.all.retrieve({ (success, err) in
                PriceOnDay.all.retrieve({ (success, err) in
                    DispatchQueue.main.async {
                        self.resetAnnotations()
                        self.refreshFlag = false
                    }
                })
            })
        }
    }

    var globalDate: Date! = nil {
        didSet {
            refresh()
        }
    }

    var globalProduct: Product! = nil {
        didSet {
            guard globalProduct != nil else {
                return
            }
            print("reset for product \(globalProduct!.name)")
            refresh()
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

    func resetAnnotations() {
        self.mapView.removeAnnotations(self.mapView.annotations)
        guard globalProduct != nil else {
            return
        }
        displaySpinner()
        var annotations = [MKPointAnnotation]()
        for st in Station.all.values {
            if st.latitude != 0 && st.longitude != 0 {
                let annot = StationAnnotation(st)
                annotations.append(annot)
            }
        }
        self.mapView.addAnnotations(annotations)
        removeSpinner()
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let station = annotation as? StationAnnotation {
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: "station") as? MKMarkerAnnotationView
            if view == nil {
                view = StationMarkerAnnotationView(annotation: nil, reuseIdentifier: "station")
            }
            view?.annotation = station
           return view
        } else if let cluster = annotation as? MKClusterAnnotation {
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: "cluster") as? MKMarkerAnnotationView
            if view == nil {
                view = ClusterMarkerAnnotationView(annotation: nil, reuseIdentifier: "cluster")
            }
            view?.annotation = cluster
            return view
        } else {
            return nil
        }
    }

    func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
        mapView.register(StationMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "station")
        mapView.register(ClusterMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "cluster")
        resetAnnotations()
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
        self.globalDate = MapViewController.calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!
        self.globalProduct = Product.all[1]

        FLOCloud.shared.alertUserToEnterICloudCredentials(controller: self) { (success) in
            self.refreshData()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    var retrieving = false

    func refreshData() {
        guard !retrieving else {
            return
        }
        retrieving = true
        displaySpinner()
        DispatchQueue.global().async {
            Brand.all.retrieve({ (success1, error1) in
                Product.all.retrieve({ (success2, error2) in
                    Region.all.retrieve({ (success3, error3) in
                        Suburb.all.retrieve({ (success4, error4) in
                            Station.all.retrieve({ (success5, error5) in
                                if MapViewController.instance != nil {
                                    MapViewController.instance!.globalProduct = Product.all[1]
                                    MapViewController.instance!.refresh()
                                    self.removeSpinner()
                                    self.retrieving = false
                                }
                            })
                        })
                    })
                })
            })
        }
    }

    var spinnerView: UIView! = nil

    func displaySpinner() {
        guard spinnerView == nil else {
            return
        }

        DispatchQueue.main.async {
            self.spinnerView = UIView.init(frame: self.view.bounds)
            self.spinnerView.backgroundColor = UIColor.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
            let ai = UIActivityIndicatorView.init(activityIndicatorStyle: .whiteLarge)
            ai.startAnimating()
            ai.center = self.spinnerView.center
            self.spinnerView.addSubview(ai)
            self.view.addSubview(self.spinnerView)
        }
    }

    func removeSpinner() {
        DispatchQueue.main.async {
            self.spinnerView.removeFromSuperview()
            self.spinnerView = nil
        }
    }   

}

