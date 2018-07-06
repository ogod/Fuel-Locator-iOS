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

class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    typealias `Self` = MapViewController

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var titlePanelView: UIView!
    @IBOutlet weak var pullDownPanelView: UIView!
    @IBOutlet weak var panelVisualEffects: UIVisualEffectView!
    @IBOutlet weak var panelView: UIView!
    @IBOutlet weak var panelMaskView: UIView!
    @IBOutlet weak var mapTypeButton: UISegmentedControl!
    @IBOutlet weak var productPicker: UIPickerView!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var panelConstraint: NSLayoutConstraint!
    @IBOutlet weak var tabPanel: UIView!
    @IBOutlet weak var tabMaskPanel: UIView!
    @IBOutlet weak var clippingView: UIView!
    @IBOutlet weak var clipTopConstraint: NSLayoutConstraint!

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
    private static let calendar = Calendar.current
    private let foldedPanelHeight: CGFloat = 74
    private static let defaults = UserDefaults.standard

    private var products = Product.all.values.sorted(by: { $0.ident < $1.ident })
    private var regions = Region.all.values.sorted(by: { $0.ident < $1.ident })

    var refreshFlag = false

    @IBAction func newDateSelected(_ sender: UIDatePicker) {
        MapViewController.instance!.globalDate = sender.date
    }

    /// Refresh the annotations and display
    func refresh() {
        guard !refreshFlag && globalProduct != nil && !retrieving else {
            return
        }
        refreshFlag = true
        titleLabel.text = """
                            Prices for: \(formatter.string(from: globalDate))
                            \(globalProduct.knownType.fullName ?? globalProduct.name)
                            """
        DispatchQueue.main.async {
//            self.tabMaskPanel.bounds = self.tabPanel.bounds
            self.pullDownPanelView.layoutSubviews()
            self.tabMaskPanel.layoutSubviews()
        }
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
            Self.defaults.set(globalProduct.ident, forKey: "Product.lastUsed")
            refresh()
        }
    }

    @IBAction func mapTypeSelected(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 1:
            mapView.mapType = .satellite
            Self.defaults.set(1, forKey: FLSettingsBundleHelper.Keys.mapType.rawValue)
            Self.defaults.synchronize()
        case 2:
            mapView.mapType = .hybrid
            Self.defaults.set(2, forKey: FLSettingsBundleHelper.Keys.mapType.rawValue)
            Self.defaults.synchronize()
        default:
            mapView.mapType = .mutedStandard
            Self.defaults.set(0, forKey: FLSettingsBundleHelper.Keys.mapType.rawValue)
            Self.defaults.synchronize()
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
        products = Product.all.values.sorted(by: { $0.ident < $1.ident })
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
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.5
        titleLabel.textAlignment = .center
        panelMaskView.removeFromSuperview()
        panelMaskView.frame = panelView.frame
        panelVisualEffects.mask = panelMaskView
        let animation = UIViewPropertyAnimator(duration: 2, curve: UIViewAnimationCurve.easeInOut) {
            self.panelConstraint.constant = self.foldedPanelHeight
            self.clippingView.layoutIfNeeded()
        }
        animation.startAnimation()

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

        switch Self.defaults.integer(forKey: FLSettingsBundleHelper.Keys.mapType.rawValue) {
        case 1:
            mapView.mapType = .satellite
            mapTypeButton.selectedSegmentIndex = 1
        case 2:
            mapView.mapType = .hybrid
            mapTypeButton.selectedSegmentIndex = 2
        default:
            mapView.mapType = .mutedStandard
            mapTypeButton.selectedSegmentIndex = 0
        }

        setupTitlePanel()
        registerAnnotationClasses()
        addUserTrackingButton()

        globalDate = MapViewController.calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!
        globalProduct = Product.all[Int16(UserDefaults.standard.integer(forKey: "Product.lastUsed"))]

        datePicker.date = MapViewController.instance!.globalDate

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
                                self.products = Product.all.values.sorted(by: { $0.ident < $1.ident })
                                self.regions = Region.all.values.sorted(by: { $0.ident < $1.ident })
                                self.productPicker.reloadAllComponents()
                                if let i = self.products.index(of: self.globalProduct) {
                                    self.productPicker.selectRow(i, inComponent: 0, animated: true)
                                }
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

    private var clippingHeight: CGFloat = 0
    private var panelHeight: CGFloat = 0

    @IBAction func detectPan(_ recogniser: UIPanGestureRecognizer) {
        let translation = recogniser.translation(in: view)
        switch recogniser.state {
        case .began:
            self.clippingHeight = self.clippingView.frame.height
            self.panelHeight = self.pullDownPanelView.frame.height

        case .changed:
            let height = min(max(self.clippingHeight + translation.y, self.foldedPanelHeight), self.panelHeight - 8)
            panelConstraint.constant = height
            clipTopConstraint.constant = 0
            self.clippingView.layoutIfNeeded()

        case .possible:
            let height = min(max(self.clippingHeight + translation.y, self.foldedPanelHeight), self.panelHeight - 8)
            panelConstraint.constant = height
            clipTopConstraint.constant = 0
            self.clippingView.layoutIfNeeded()

        case .cancelled, .failed:
            self.clipTopConstraint.constant = 0
            self.clippingView.layoutIfNeeded()
            let animation = UIViewPropertyAnimator(duration: 0.2, curve: UIViewAnimationCurve.easeInOut) {
                self.panelConstraint.constant = self.clippingHeight
                self.clipTopConstraint.constant = 0
                self.clippingView.layoutIfNeeded()
            }
            animation.startAnimation()

        case .ended:
            let height = min(max(self.clippingHeight + translation.y, self.foldedPanelHeight), self.panelHeight - 8)
            let flag = (height - self.foldedPanelHeight) - (self.panelHeight - foldedPanelHeight) / 2 < 0
            panelConstraint.constant = height
            self.clippingView.center = CGPoint(x: self.clippingView.center.x, y: self.clippingView.bounds.height/2)
            self.clippingView.layoutIfNeeded()
            let animation = UIViewPropertyAnimator(duration: 2, curve: UIViewAnimationCurve.easeInOut) {
                self.clippingView.center = CGPoint(x: self.clippingView.center.x, y: self.clippingView.bounds.height/2)
                self.panelConstraint.constant = flag ? self.foldedPanelHeight : self.panelHeight - 8
                self.clippingView.layoutIfNeeded()
            }
            animation.startAnimation()
        }
    }
}

extension MapViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return products.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return products[row].knownType.fullName ?? products[row].name
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        globalProduct = products[row]
    }
}
