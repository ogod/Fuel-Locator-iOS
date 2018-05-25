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
    @IBOutlet weak var titleButton: UIButton!
    @IBOutlet weak var titlePanelView: UIView!

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
        guard !refreshFlag && globalProduct != nil && !retrieving else {
            return
        }
        refreshFlag = true
        titleButton.setTitle("""
                                Prices for: \(formatter.string(from: globalDate))
                                \(globalProduct.knownType.fullName ?? globalProduct.name)
                                """, for: .normal)
        DispatchQueue.global().async {
            Statistics.all.retrieve({ (success, err) in
                guard err == nil else {
                    self.dataError(err!) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                            self.refresh()
                        }
                    }
                    return
                }
                if success {
                    PriceOnDay.all.retrieve({ (success, err) in
                        guard err == nil else {
                            self.dataError(err!) {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                                    self.refresh()
                                }
                            }
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
            UserDefaults.standard.set(globalProduct.ident, forKey: "Product.lastUsed")
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
        mapView.addSubview(button)
        NSLayoutConstraint.activate([button.bottomAnchor.constraint(equalTo: mapView.bottomAnchor, constant: -4),
                                     button.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -4)])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        locationManager.delegate = self
        mapView.showsUserLocation = true
        mapView.setRegion(initialRegion, animated: true)

        titleButton.titleLabel?.lineBreakMode = .byWordWrapping
        titleButton.titleLabel?.numberOfLines = 2
        titleButton.titleLabel?.adjustsFontForContentSizeCategory = true
        titleButton.titleLabel?.adjustsFontSizeToFitWidth = true
        titleButton.titleLabel?.minimumScaleFactor = 0.5
        titleButton.titleLabel?.textAlignment = .center

        let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        blurEffectView.frame = titlePanelView.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        titlePanelView.insertSubview(blurEffectView, at: 0)
        titlePanelView.superview?.layer.shadowColor = UIColor.gray.cgColor

        registerAnnotationClasses()
        addUserTrackingButton()
//        addCompassButton()

        self.globalDate = MapViewController.calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!
        self.globalProduct = Product.all[Int16(UserDefaults.standard.integer(forKey: "Product.lastUsed"))]

        status = .initialising
        FLOCloud.shared.alertUserToEnterICloudCredentials(controller: self) { (success) in
            guard success else {
                self.status = .failed
                let alert = UIAlertController(title: "iCloud CredentialsRequired", message: "This app cannot function without valid iCloud credentials", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
                    abort()
                }))
                return
            }
            self.status = .ready
            self.readData()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    var retrieving = false

    func refreshData(iteration: Int = 0) {
        guard !retrieving else {
            return
        }
        guard iteration < 5 else {
            self.dataError(nil) {
            }
            return
        }
        DispatchQueue.main.async {
            self.retrieving = true
            let increment: Float = 1.0 / 1.0
            self.displayProgressBar()
            self.advanceProgress(progress: 1 * increment)
            Station.all.retrieve({ (success, error) in
                guard error == nil else {
                    self.dataError(error!) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                            self.removeProgressBar()
                            self.refreshData(iteration: iteration + 1)
                        }
                    }
                    return
                }
                if MapViewController.instance != nil {
                    MapViewController.instance!.refresh()
                    self.retrieving = false
                }
                self.removeProgressBar()
            })
        }
    }

    func dataError(_ error: Error?, termin: @escaping ()->Void) {
        let message: String
        if let err = error {
            message = """
                    Communications failed while retrieving the setup data.
                    Please check your settings and try again later.
                    \(err.localizedDescription)
                    """
        } else {
            message = """
                    Communications failed while retrieving the setup data.
                    Please check your settings and try again later.
                    """
        }
        print(message)
        let alert = UIAlertController(title: "Cannot Retrieve Data",
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (a) in
            termin()
        }))
        present(alert, animated: true)
    }

    func readData(iteration: Int = 0) {
        guard !retrieving || iteration > 0 else {
            return
        }
        guard iteration < 10 else {
            self.dataError(nil) {
                abort()
            }
            return
        }
        DispatchQueue.main.async {
            self.retrieving = true
            let increment: Float = 1.0 / 5.0
            self.displayProgressBar()
            self.advanceProgress(progress: 1 * increment)
            Brand.all.retrieve({ (success1, error) in
                guard error == nil else {
                    self.dataError(error!) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                            self.retrieving = false
                            self.removeProgressBar()
                            self.readData(iteration: iteration + 1)
                        }
                    }
                    return
                }
                self.advanceProgress(progress: 2 * increment)
                Product.all.retrieve({ (success2, error) in
                    guard error == nil else {
                        self.dataError(error!) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                                self.retrieving = false
                                self.removeProgressBar()
                                self.readData(iteration: iteration + 1)
                            }
                        }
                        return
                    }
                    self.advanceProgress(progress: 3 * increment)
                    Region.all.retrieve({ (success3, error) in
                        guard error == nil else {
                            self.dataError(error!) {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                                    self.retrieving = false
                                    self.removeProgressBar()
                                    self.readData(iteration: iteration + 1)
                                }
                            }
                            return
                        }
                        self.advanceProgress(progress: 4 * increment)
                        Suburb.all.retrieve({ (success4, error) in
                            guard error == nil else {
                                self.dataError(error!) {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                                        self.retrieving = false
                                        self.removeProgressBar()
                                        self.readData(iteration: iteration + 1)
                                    }
                                }
                                return
                            }
                            self.advanceProgress(progress: 5 * increment)
                            Station.all.retrieve({ (success5, error) in
                                guard error == nil else {
                                    self.dataError(error!) {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                                            self.retrieving = false
                                            self.removeProgressBar()
                                            self.readData(iteration: iteration + 1)
                                        }
                                    }
                                    return
                                }
                                self.globalProduct = Product.all[Int16(UserDefaults.standard.integer(forKey: "Product.lastUsed"))]
                                self.retrieving = false
                                self.removeProgressBar()
                                self.refresh()
                            })
                        })
                    })
                })
            })
        }
    }

    var progressView: UIView! = nil
    var progressBar: UIProgressView! = nil

    func displayProgressBar() {
        DispatchQueue.main.async {
            guard self.progressView == nil && self.progressBar == nil else {
                return
            }

            self.progressView = UIView.init(frame: self.view.bounds)
            self.progressView.backgroundColor = .clear
            self.progressBar = UIProgressView(progressViewStyle: .bar)
            self.progressBar.center = self.progressView.center

            let blurEffect = UIBlurEffect(style: .light)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.translatesAutoresizingMaskIntoConstraints = false
            blurView.frame = self.view.frame

            self.progressView.insertSubview(blurView, at: 0)
            self.progressView.addSubview(self.progressBar)
            self.view.addSubview(self.progressView)
        }
    }

    func advanceProgress(progress: Float) {
        DispatchQueue.main.async {
            guard self.progressView != nil && self.progressBar != nil else {
                return
            }

            self.progressBar?.setProgress(progress, animated: true)
        }
    }

    func removeProgressBar() {
        DispatchQueue.main.async {
            guard self.progressView != nil && self.progressBar != nil else {
                return
            }

            self.progressView.removeFromSuperview()
            self.progressBar = nil
            self.progressView = nil
        }
    }
}

