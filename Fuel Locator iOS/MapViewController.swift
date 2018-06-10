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
import Armchair

class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, UIGestureRecognizerDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var titleButton: UIButton!
    @IBOutlet weak var titlePanelView: UIView!

    @IBAction func done(_ segue: UIStoryboardSegue) {
        print(segue)
    }

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

    /// Refresh the annotations and display
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
                                self.mapView.setNeedsDisplay()
                            }
                        }
                    })
                }
            })
        }
    }

    /// The current date being observed, shared with entire application
    var globalDate: Date! = nil {
        didSet {
            refresh()
        }
    }

    /// The current product being observed, shared with the entire application
    var globalProduct: Product! = nil {
        didSet {
            guard globalProduct != nil else {
                return
            }
            UserDefaults.standard.set(globalProduct.ident, forKey: "Product.lastUsed")
            refresh()
        }
    }

    typealias AccType = (count: Int, prev: Int, reg: Region?, prevReg: Region?)

    /// The current global region.
    /// This method polls the visible annotations as to a concensus of what region is being viewed. First majority wins.
    /// If the region has no visible annotations, nil is returned.
    var globalRegion: Region! {
        let allAnnotations = Array(mapView.annotations(in: mapView.visibleMapRect))
        let stationAnnotions = allAnnotations.compactMap({$0 as? MKClusterAnnotation}).flatMap({$0.memberAnnotations}).compactMap({$0 as? StationAnnotation}) +
            allAnnotations.compactMap({$0 as? StationAnnotation})
        let regions = stationAnnotions.compactMap({$0.station.suburb?.region}).flatMap({$0}).sorted(by: {$0.ident < $1.ident})
        let modal = regions.reduce((count: 0 as Int, prev: 0 as Int, reg: nil as Region?, prevReg: nil as Region?)) { (part, region) -> AccType in
            guard region.ident == (part.reg?.ident ?? -2) else {
                if part.count > part.prev {
                    return (count: 1, prev: part.count, reg: region, prevReg: part.reg)
                } else {
                    return (count: 1, prev: part.prev, reg: region, prevReg: part.prevReg)
                }
            }
            return (count: part.count+1, prev: part.prev, reg: part.reg, prevReg: part.prevReg)
        }
        return modal.prevReg
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

    /// Resets the annotations by siply removing them and adding them fresh
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

    /// Function to handle a callout accessory tap by activating a map route
    ///
    /// - Parameters:
    ///   - mapView: The map view
    ///   - view: The annotation view that initiated the call
    ///   - control: The control within the annotation view that was tapped
    func mapView(_ mapView: MKMapView,
                 annotationView view: MKAnnotationView,
                 calloutAccessoryControlTapped control: UIControl) {
        if let location = view.annotation as? StationAnnotation {
            let launchOptions: [String: Any] = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
                                                MKLaunchOptionsShowsTrafficKey: true]
            Armchair.userDidSignificantEvent(true)
            location.mapItem().openInMaps(launchOptions: launchOptions)
        }
    }

    fileprivate func registerAnnotationClasses() {
        mapView.register(StationMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        mapView.register(ClusterMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
    }

    fileprivate func addUserTrackingButton() {
        let trackingButton = MKUserTrackingButton(mapView: mapView)
        trackingButton.translatesAutoresizingMaskIntoConstraints = false
        titlePanelView.addSubview(trackingButton)
        NSLayoutConstraint.activate([trackingButton.bottomAnchor.constraint(equalTo: titlePanelView.bottomAnchor, constant: -4),
                                     trackingButton.centerXAnchor.constraint(equalTo: titlePanelView.centerXAnchor)])
    }

    fileprivate func setupTitlePanel() {
        titleButton.titleLabel?.lineBreakMode = .byWordWrapping
        titleButton.titleLabel?.numberOfLines = 2
        titleButton.titleLabel?.adjustsFontForContentSizeCategory = true
        titleButton.titleLabel?.adjustsFontSizeToFitWidth = true
        titleButton.titleLabel?.minimumScaleFactor = 0.5
        titleButton.titleLabel?.textAlignment = .center
    }

    fileprivate func checkCloudCredentials() {
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

    override func viewDidLoad() {
        super.viewDidLoad()

        locationManager.delegate = self
        mapView.showsUserLocation = true
        mapView.setRegion(initialRegion, animated: true)

        setupTitlePanel()
        registerAnnotationClasses()
        addUserTrackingButton()

        self.globalDate = MapViewController.calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!
        self.globalProduct = Product.all[Int16(UserDefaults.standard.integer(forKey: "Product.lastUsed"))]

        checkCloudCredentials()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    var retrieving = false

    func refreshData(iteration: Int = 0) {
        guard !retrieving || iteration > 0 else {
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
            self.displayProgressBar(label: """
                                            Refeshing data…
                                            please wait
                                            """)
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
            self.displayProgressBar(label: """
                                            Reading prices…
                                            please wait
                                            """)
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

    private lazy var progressView = self.storyboard!.instantiateViewController(withIdentifier: "progressView") as! ProgressViewController
    private var progressActive = false

    /// Adds the progress bar overlay to the display
    ///
    /// - Parameter label: The label to display on the progress indicator
    func displayProgressBar(label: String) {
        guard !self.progressActive else {
            return
        }

        self.progressActive = true
        self.progressView.progress = 0
        self.progressView.heading = label
        self.progressView.view.alpha = 0
        self.progressView.view.frame = self.view.bounds
        self.view.addSubview(self.progressView.view)
        UIView.animate(withDuration: 0.5) {
            self.progressView.view.alpha = 1
        }
        NSLayoutConstraint.activate([self.progressView.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
                                     self.progressView.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                                     self.progressView.view.topAnchor.constraint(equalTo: self.view.topAnchor),
                                     self.progressView.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor)])
    }

    /// Davances the progress bar
    ///
    /// - Parameter progress: the position of the bar
    func advanceProgress(progress: Float) {
        guard self.progressActive else {
            return
        }

        self.progressView.progress = progress
    }

    /// Removes the progress bar overlay
    func removeProgressBar() {
        guard self.progressActive else {
            return
        }

        UIView.animate(withDuration: 0.5, animations: {
            self.progressView.view.alpha = 0
        }, completion: { (complete) in
            self.progressView.view.removeFromSuperview()
            self.progressActive = false
        })
    }

//    @IBAction func edgePanDetected(_ sender: Any) {
//        performSegue(withIdentifier: "graph", sender: self)
//    }
//
//    @IBOutlet var edgePanRecogniser: UIScreenEdgePanGestureRecognizer!
//
//    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
//        if gestureRecognizer == edgePanRecogniser {
//            return true
//        }
//        return false
//    }
//
}

