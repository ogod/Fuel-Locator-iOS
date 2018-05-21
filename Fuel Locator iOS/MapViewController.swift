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
    @IBOutlet weak var panelView: UIView!
    @IBOutlet weak var titleLabel: UILabel!

    enum Status {
        case uninitialised
        case initialising
        case ready
        case failed
    }

    var status = Status.uninitialised
    let formatter: DateFormatter = {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = true
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static var instance: MapViewController? = nil
    static let calendar = Calendar.current

    var refreshFlag = false

    func refresh() {
        guard !refreshFlag && globalProduct != nil else {
            return
        }
        refreshFlag = true
        titleLabel.text = """
                    Prices for: \(formatter.string(from: globalDate))
                    Product: \(globalProduct.name)
                    """
        DispatchQueue.global().async {
            Statistics.all.retrieve({ (success, err) in
                guard err == nil else {
                    print(err!)
                    return
                }
                if success {
                    PriceOnDay.all.retrieve({ (success, err) in
                        guard err == nil else {
                            print(err!)
                            return
                        }
                        if success {
                            DispatchQueue.main.async {
                                self.resetAnnotations()
                                self.refreshFlag = false
                            }
                        }
                    })
                }
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
        if let stations = Station.all.values {
            self.mapView.addAnnotations(stations.filter({$0.latitude != 0 && $0.longitude != 0}).map({StationAnnotation($0)}))
        }
    }

    func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
        resetAnnotations()
    }

    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView,
                 calloutAccessoryControlTapped control: UIControl) {
        if let location = view.annotation as? StationAnnotation {
            let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
            location.mapItem().openInMaps(launchOptions: launchOptions)
        }
    }

    fileprivate func registerAnnotationClasses() {
        mapView.register(StationMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        mapView.register(ClusterMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
    }

    fileprivate func addUserTrackingButton() {
        let button = MKUserTrackingButton(mapView: mapView)
        button.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(button)
        NSLayoutConstraint.activate([button.bottomAnchor.constraint(equalTo: panelView.bottomAnchor, constant: -4),
                                     button.centerXAnchor.constraint(equalTo: panelView.centerXAnchor)])
    }

    fileprivate func addCompassButton() {
        let compass = MKCompassButton(mapView: mapView)
        compass.translatesAutoresizingMaskIntoConstraints = false
        mapView.addSubview(compass)
        NSLayoutConstraint.activate([compass.topAnchor.constraint(equalTo: panelView.bottomAnchor, constant: 8),
                                     compass.centerXAnchor.constraint(equalTo: panelView.centerXAnchor)])
        mapView.showsCompass = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        locationManager.delegate = self
        mapView.showsUserLocation = true
        mapView.setRegion(initialRegion, animated: true)

        registerAnnotationClasses()
        addUserTrackingButton()
        addCompassButton()

        self.globalDate = MapViewController.calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!
        self.globalProduct = Product.all[1]

        panelView.layer.shadowColor = UIColor.gray.cgColor

        status = .initialising
        FLOCloud.shared.alertUserToEnterICloudCredentials(controller: self) { (success) in
            guard success else {
                self.status = .failed
                return
            }
            self.status = .ready
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
        DispatchQueue.main.async {
            self.retrieving = true
            let increment: Float = 1.0 / 5.0
            self.displayProgressBar()
            self.advanceProgress(progress: 1 * increment)
            DispatchQueue.global().async {
                Brand.all.retrieve({ (success1, error1) in
                    self.advanceProgress(progress: 2 * increment)
                    DispatchQueue.global().async {
                        Product.all.retrieve({ (success2, error2) in
                            self.advanceProgress(progress: 3 * increment)
                            DispatchQueue.global().async {
                                Region.all.retrieve({ (success3, error3) in
                                    self.advanceProgress(progress: 4 * increment)
                                    DispatchQueue.global().async {
                                        Suburb.all.retrieve({ (success4, error4) in
                                            self.advanceProgress(progress: 5 * increment)
                                            DispatchQueue.global().async {
                                                Station.all.retrieve({ (success5, error5) in
                                                    if MapViewController.instance != nil {
                                                        MapViewController.instance!.globalProduct = Product.all[1]
                                                        MapViewController.instance!.refresh()
                                                        self.retrieving = false
                                                    }
                                                    self.removeProgressBar()
                                                })
                                            }
                                        })
                                    }
                                })
                            }
                        })
                    }
                })
            }
        }
    }

    var progressView: UIView! = nil
    var progressBar: UIProgressView! = nil

    func displayProgressBar() {
        guard progressView == nil && progressBar == nil else {
            return
        }

        DispatchQueue.main.async {
//            let blurEffect = UIBlurEffect(style: .extraLight)
//            self.progressView = UIVisualEffectView(effect: blurEffect)
//            self.progressBar = UIProgressView(progressViewStyle: .bar)
//            self.progressView.frame = self.view.frame
//            self.progressView.translatesAutoresizingMaskIntoConstraints = false
//            self.progressBar.center = self.progressView.center
            //self.view.insertSubview(progressView, at: 0)

//            self.progressView.view.addSubview(self.progressBar)
//            self.view.addSubview(self.progressView)

//            self.view.insertSubview(blurEffectView, atIndex: 0)
            let blurEffect = UIBlurEffect(style: .light)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.translatesAutoresizingMaskIntoConstraints = false
            blurView.frame = self.view.frame

            self.progressView = UIView.init(frame: self.view.bounds)
            self.progressView.backgroundColor = .clear
            self.progressBar = UIProgressView(progressViewStyle: .bar)
            self.progressBar.center = self.progressView.center

            self.progressView.insertSubview(blurView, at: 0)
            self.progressView.addSubview(self.progressBar)
            self.view.addSubview(self.progressView)
        }
    }

    func advanceProgress(progress: Float) {
        DispatchQueue.main.async {
            self.progressBar?.setProgress(progress, animated: true)
        }
    }

    func removeProgressBar() {
        DispatchQueue.main.async {
            self.progressView.removeFromSuperview()
            self.progressBar = nil
            self.progressView = nil
        }
    }

}

