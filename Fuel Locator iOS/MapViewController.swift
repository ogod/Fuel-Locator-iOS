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
    private var clippingOffset: CGFloat = 0
    private var panelHeight: CGFloat = 0
    private var clippingHeight: CGFloat = 0

    private var products = Product.all.values.sorted(by: { $0.ident < $1.ident })
    private var regions = Region.all.values.sorted(by: { $0.ident < $1.ident })

    var refreshFlag = false

    /// Refresh the annotations and display
    func refresh() {
        guard !refreshFlag && globalProduct != nil && !retrieving else {
            return
        }
        refreshFlag = true
        titleLabel.text = """
                            Prices for: \(formatter.string(from: globalDate))
                            Product: \(globalProduct.knownType.fullName ?? globalProduct.name)
                            Region: \(globalRegion?.name ?? "Unknown")
                            """
        MainThread.async {
//            self.tabMaskPanel.bounds = self.tabPanel.bounds
            self.pullDownPanelView.layoutSubviews()
//            self.tabMaskPanel.layoutSubviews()
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
                            MainThread.async{
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
        resetFoldupTimer()
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
        let mapRegion = mapView.region
        let mapLocation = CLLocation(latitude: mapRegion.center.latitude, longitude: mapRegion.center.longitude)
        let dist = mapLocation.distance(from: CLLocation(latitude: mapLocation.coordinate.latitude + mapRegion.span.latitudeDelta,
                                                         longitude: mapLocation.coordinate.longitude + mapRegion.span.longitudeDelta))

        let regions = Region.all.values.filter({$0.location != nil && mapLocation.distance(from: $0.location!) < ($0.radius?.doubleValue ?? 0) + dist})
        guard regions.count > 1 else {
            return regions.first
        }
        let allAnnotations = Array(mapView.annotations(in: mapView.visibleMapRect))
        let stationAnnotions = allAnnotations.compactMap({$0 as? MKClusterAnnotation}).flatMap({$0.memberAnnotations}).compactMap({$0 as? StationAnnotation}) +
            allAnnotations.compactMap({$0 as? StationAnnotation})
        let stations = stationAnnotions.map({$0.station})
        let statRegs = stations.compactMap({$0.suburb?.region}).flatMap({$0})

        var counts = Array<Int>(repeating: 0, count: regions.count)
        var currentHighestCountIndex = -1
        for i in 0 ..< regions.count {
            for r in statRegs {
                if r == regions[i] {
                    counts[i] += 1
                }
            }
            if currentHighestCountIndex == -1 {
                currentHighestCountIndex = i
            } else if counts[i] >= counts[currentHighestCountIndex] {
                currentHighestCountIndex = i
            }
        }
        return currentHighestCountIndex == -1 ? nil : regions[currentHighestCountIndex]
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
            print("Beginning add annotations")
            self.mapView.addAnnotations(stations.filter({ st in
                guard st.latitude != 0 && st.longitude != 0 else {
                    return false
                }
                guard st.dateRange == nil || st.dateRange! ~= globalDate else {
                    print("Station \(st.tradingName) excluded because \(self.formatter.string(from: globalDate)) is not in \(self.formatter.string(from: st.dateRange!.lowerBound)) ... \(self.formatter.string(from: st.dateRange!.upperBound))")
                    return false
                }
                return true
            }).map({StationAnnotation($0)}))
            print("Added annotations")
        }
    }

    func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
        products = Product.all.values.sorted(by: { $0.ident < $1.ident })
        resetAnnotations()
    }

    /// Function to handle a callout accessory tap by activating a map route
    ///
    /// This function doesn't seem to get called with annotation class registration.
    /// As such, see the annotation object code for direct button action to launch
    /// maps.
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
        panelHeight = pullDownPanelView.frame.height
        panelMaskView.removeFromSuperview()
        panelMaskView.frame = panelView.frame
        panelVisualEffects.mask = panelMaskView

        let range = foldedPanelHeight - panelHeight - 8 ... -8
        let offset = range.lowerBound
        let flag = (offset - range.lowerBound) - (range.upperBound - range.lowerBound) / 2 < 0
        let outerSize = CGSize(width: self.clippingView.frame.width, height: flag ? self.foldedPanelHeight : self.panelHeight)
        let innerOrigin = CGPoint(x: self.pullDownPanelView.frame.minX, y: outerSize.height - panelHeight - 6)
        let finalOuterFrame = CGRect(origin: self.clippingView.frame.origin, size: outerSize)
        let finalinnerFrame = CGRect(origin: innerOrigin, size: self.pullDownPanelView.frame.size)
        panelConstraint.constant = offset
        self.clippingView.layoutIfNeeded()
        let animation = UIViewPropertyAnimator(duration: 0.2, curve: UIView.AnimationCurve.easeInOut) {
            self.clippingView.frame = finalOuterFrame
            self.pullDownPanelView.frame = finalinnerFrame
            self.panelConstraint.constant = flag ? range.lowerBound : range.upperBound
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

        let today = Self.calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!
        let tomorrow = Self.calendar.date(byAdding: .day, value: 1, to: today)!
        datePicker.date = MapViewController.instance!.globalDate
        datePicker.maximumDate = tomorrow

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
        MainThread.async{
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
        MainThread.async{
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
                                self.refresh()
                                self.removeProgressBar()
//                                DispatchQueue.global().async {
//                                    print("Fetching past dates")
//                                    let finalOp = BlockOperation(block: {
//                                        print("Past Date fetch complete")
//                                        self.refresh()
//                                    })
//                                    for station in Station.all.values {
//                                        var first: Date!
//                                        var last: Date!
//                                        let pred = NSPredicate(format: "station == %@", CKReference(recordID: station.recordID, action: .none))
//                                        let queryFirst = CKQuery(recordType: "FWPrice", predicate: pred)
//                                        queryFirst.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
//                                        let opFirst = CKQueryOperation(query: queryFirst)
//                                        opFirst.resultsLimit = 1
//                                        opFirst.queuePriority = .veryLow
//                                        opFirst.recordFetchedBlock = { record in
//                                            if let l = record["date"] as? Date {
//                                                first = l
//                                            } else {
//                                                print("Station '\(station.tradingName)', has no first")
//                                            }
//                                        }
//                                        let queryLast = CKQuery(recordType: "FWPrice", predicate: pred)
//                                        queryLast.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
//                                        let opLast = CKQueryOperation(query: queryLast)
//                                        opLast.resultsLimit = 1
//                                        opLast.queuePriority = .veryLow
//                                        opLast.recordFetchedBlock = { record in
//                                            if let l = record["date"] as? Date {
//                                                last = l
//                                            } else {
//                                                print("Station '\(station.tradingName)', has no last")
//                                            }
//                                        }
//                                        let opComplete = BlockOperation(block: {
//                                            if first != nil && last != nil {
//                                                station.dateRange = first ... Self.calendar.date(byAdding: .day, value: 7, to: last)!
//                                            }
//                                        })
//                                        opComplete.queuePriority = .veryLow
//                                        opComplete.addDependency(opFirst)
//                                        opComplete.addDependency(opLast)
//                                        finalOp.addDependency(opComplete)
//                                        opFirst.queryCompletionBlock = { (cursor, error) in
//                                            guard error == nil else {
//                                                print("Query error: \(error!.localizedDescription)")
//                                                switch error! {
//                                                case let error as CKError:
//                                                    let retryAfter = error.userInfo[CKErrorRetryAfterKey] as? Double ?? 30.0
//                                                    switch error.code {
//                                                    case .networkFailure, .networkUnavailable, .internalError, .serverRejectedRequest:
//                                                        // An error that is returned when the network is available but cannot be accessed.
//                                                        // An error that is returned when the network is not available.
//                                                        print("Error on cloud read: \(error.localizedDescription)")
//                                                        fallthrough
//
//                                                    case .requestRateLimited:
//                                                        // Transfers to and from the server are being rate limited for the client at this time.
//                                                        print("rate limited")
//                                                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + retryAfter) {
//                                                            let op = CKQueryOperation(query: queryFirst)
//                                                            op.recordFetchedBlock = opFirst.recordFetchedBlock
//                                                            op.queryCompletionBlock = opFirst.queryCompletionBlock
//                                                            op.resultsLimit = 1
//                                                            op.queuePriority = .veryLow
//                                                            opComplete.addDependency(op)
//                                                            do {
//                                                                try FLOCloud.shared.publicDatabase().add(op)
//                                                            } catch {
//                                                                print("Database error: \(error.localizedDescription)")
//                                                            }
//                                                        }
//
//                                                    default:
//                                                        print("Error on cloud read: \(error.localizedDescription)")
//                                                    }
//
//                                                default:
//                                                    print("Error on cloud read: \(error!.localizedDescription)")
//                                                }
//
//                                                return
//                                            }
//                                        }
//                                        opLast.queryCompletionBlock = { (cursor, error) in
//                                            guard error == nil else {
//                                                guard error == nil else {
//                                                    print("Query error: \(error!.localizedDescription)")
//                                                    switch error! {
//                                                    case let error as CKError:
//                                                        let retryAfter = error.userInfo[CKErrorRetryAfterKey] as? Double ?? 30.0
//                                                        switch error.code {
//                                                        case .networkFailure, .networkUnavailable, .internalError, .serverRejectedRequest:
//                                                            // An error that is returned when the network is available but cannot be accessed.
//                                                            // An error that is returned when the network is not available.
//                                                            print("Error on cloud read: \(error.localizedDescription)")
//                                                            fallthrough
//
//                                                        case .requestRateLimited:
//                                                            // Transfers to and from the server are being rate limited for the client at this time.
//                                                            print("rate limited")
//                                                            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + retryAfter) {
//                                                                let op = CKQueryOperation(query: queryLast)
//                                                                op.recordFetchedBlock = opLast.recordFetchedBlock
//                                                                op.queryCompletionBlock = opLast.queryCompletionBlock
//                                                                op.resultsLimit = 1
//                                                                op.queuePriority = .veryLow
//                                                                opComplete.addDependency(op)
//                                                                do {
//                                                                    try FLOCloud.shared.publicDatabase().add(op)
//                                                                } catch {
//                                                                    print("Database error: \(error.localizedDescription)")
//                                                                }
//                                                            }
//
//                                                        default:
//                                                            print("Error on cloud read: \(error.localizedDescription)")
//                                                        }
//
//                                                    default:
//                                                        print("Error on cloud read: \(error!.localizedDescription)")
//                                                    }
//                                                    return
//                                                }
//                                                return
//                                            }
//                                        }
//                                        do {
//                                            try FLOCloud.shared.publicDatabase().add(opFirst)
//                                            try FLOCloud.shared.publicDatabase().add(opLast)
//                                            OperationQueue.main.addOperation(opComplete)
//                                        } catch {
//                                            print("Database error: \(error.localizedDescription)")
//                                        }
//                                    }
//                                    OperationQueue.main.addOperation(finalOp)
//                                }
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

    var foldupTimer: Timer?

    func resetFoldupTimer() {
        cancelFoldupTimer()
        foldupTimer = Timer.scheduledTimer(timeInterval: 20.0, target: self, selector: #selector(fold), userInfo: nil, repeats: false)
    }

    func cancelFoldupTimer() {
        foldupTimer?.invalidate()
        foldupTimer = nil
    }

    @objc func fold() {
        cancelFoldupTimer()
        let range = foldedPanelHeight - self.pullDownPanelView.frame.height - 8 ... -8
        let position = ((self.panelConstraint.constant - range.lowerBound) / (range.upperBound - range.lowerBound))
        guard position == 1 else {
            return
        }
        let outerSize = CGSize(width: self.clippingView.frame.width, height: self.foldedPanelHeight)
        let innerOrigin = CGPoint(x: self.pullDownPanelView.frame.minX, y: outerSize.height - panelHeight - 6)
        let finalOuterFrame = CGRect(origin: self.clippingView.frame.origin, size: outerSize)
        let finalinnerFrame = CGRect(origin: innerOrigin, size: self.pullDownPanelView.frame.size)
        self.clippingView.layoutIfNeeded()
        let animation = UIViewPropertyAnimator(duration: 0.2, curve: UIView.AnimationCurve.easeInOut) {
            self.clippingView.frame = finalOuterFrame
            self.pullDownPanelView.frame = finalinnerFrame
            self.panelConstraint.constant = range.lowerBound
            self.clippingView.layoutIfNeeded()
        }
        animation.startAnimation()
    }

    @IBAction func newDateSelected(_ sender: UIDatePicker) {
        MapViewController.instance!.globalDate = sender.date
        resetFoldupTimer()
    }

    @IBAction func detectTap(_ recogniser: UITapGestureRecognizer) {
        let range = foldedPanelHeight - self.pullDownPanelView.frame.height - 8 ... -8 // Range for pull-down view offset, folded ... unfolded
        let position = ((self.panelConstraint.constant - range.lowerBound) / (range.upperBound - range.lowerBound))  // 0 ==> folded, 1 ==> unfolded
        let outerSize = CGSize(width: self.clippingView.frame.width, height: position > 0.5 ? self.foldedPanelHeight : self.pullDownPanelView.frame.height)
        let innerOrigin = CGPoint(x: self.pullDownPanelView.frame.minX, y: outerSize.height - panelHeight - 6)
        let finalOuterFrame = CGRect(origin: self.clippingView.frame.origin, size: outerSize)
        let finalinnerFrame = CGRect(origin: innerOrigin, size: self.pullDownPanelView.frame.size)
        self.clippingView.layoutIfNeeded()
        let animation = UIViewPropertyAnimator(duration: 0.2, curve: UIView.AnimationCurve.easeInOut) {
            self.clippingView.frame = finalOuterFrame
            self.pullDownPanelView.frame = finalinnerFrame
            self.panelConstraint.constant = position > 0.5 ? range.lowerBound : range.upperBound
            self.clippingView.layoutIfNeeded()
        }
        animation.startAnimation()
        if position > 0.5 {
            cancelFoldupTimer()
        } else {
            resetFoldupTimer()
        }
    }

    @IBAction func detectPan(_ recogniser: UIPanGestureRecognizer) {
        let translation = recogniser.translation(in: view)
        let range = foldedPanelHeight - panelHeight - 8 ... -8
        switch recogniser.state {
        case .began:
            self.clippingOffset = self.panelConstraint.constant
            self.panelHeight = self.pullDownPanelView.frame.height
            self.clippingHeight = self.clippingView.frame.height

        case .changed:
            self.panelConstraint.constant = (self.clippingOffset + translation.y).clamped(to: range)
            self.clipTopConstraint.constant = 0
            self.clippingView.layoutIfNeeded()

        case .possible:
            self.panelConstraint.constant = (self.clippingOffset + translation.y).clamped(to: range)
            self.clipTopConstraint.constant = 0
            self.clippingView.layoutIfNeeded()

        case .cancelled, .failed:
            let offset = (self.clippingOffset).clamped(to: range)
            let position = ((self.clippingOffset - range.lowerBound) / (range.upperBound - range.lowerBound))  // 0 ==> folded, 1 ==> unfolded
            let outerSize = CGSize(width: self.clippingView.frame.width, height: position < 0.5 ? self.foldedPanelHeight : self.panelHeight)
            let innerOrigin = CGPoint(x: self.pullDownPanelView.frame.minX, y: outerSize.height - panelHeight - 6)
            let finalOuterFrame = CGRect(origin: self.clippingView.frame.origin, size: outerSize)
            let finalinnerFrame = CGRect(origin: innerOrigin, size: self.pullDownPanelView.frame.size)
            self.panelConstraint.constant = offset
            self.clippingView.layoutIfNeeded()
            let animation = UIViewPropertyAnimator(duration: 2, curve: UIView.AnimationCurve.easeInOut) {
                self.clippingView.frame = finalOuterFrame
                self.pullDownPanelView.frame = finalinnerFrame
                self.panelConstraint.constant = position < 0.5 ? range.lowerBound : range.upperBound
                self.clippingView.layoutIfNeeded()
            }
            animation.startAnimation()
            if position < 0.5 {
                cancelFoldupTimer()
            } else {
                resetFoldupTimer()
            }

        case .ended:
            let offset = (self.clippingOffset + translation.y).clamped(to: range)
            let position = ((self.panelConstraint.constant - range.lowerBound) / (range.upperBound - range.lowerBound))  // 0 ==> folded, 1 ==> unfolded
            let outerSize = CGSize(width: self.clippingView.frame.width, height: position < 0.5 ? self.foldedPanelHeight : self.panelHeight)
            let innerOrigin = CGPoint(x: self.pullDownPanelView.frame.minX, y: outerSize.height - panelHeight - 6)
            let finalOuterFrame = CGRect(origin: self.clippingView.frame.origin, size: outerSize)
            let finalinnerFrame = CGRect(origin: innerOrigin, size: self.pullDownPanelView.frame.size)
            panelConstraint.constant = offset
            self.clippingView.layoutIfNeeded()
            let animation = UIViewPropertyAnimator(duration: 0.2, curve: UIView.AnimationCurve.easeInOut) {
                self.clippingView.frame = finalOuterFrame
                self.pullDownPanelView.frame = finalinnerFrame
                self.panelConstraint.constant = position < 0.5 ? range.lowerBound : range.upperBound
                self.clippingView.layoutIfNeeded()
            }
            animation.startAnimation()
            if position > 0.5 {
                cancelFoldupTimer()
            } else {
                resetFoldupTimer()
            }
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
        resetFoldupTimer()
    }

    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let pickerLabel: UILabel
        if let v = view as? UILabel {
            pickerLabel = v
        } else {
            pickerLabel = UILabel()
            pickerLabel.font = UIFont.systemFont(ofSize: UIFont.systemFontSize * 1.5, weight: UIFont.Weight.thin)
            pickerLabel.textAlignment = .center
        }
        pickerLabel.text = self.pickerView(pickerView, titleForRow: row, forComponent: component)
        return pickerLabel
    }
}


