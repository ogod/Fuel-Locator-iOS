//
//  AppDelegate.swift
//  Fuel Locator iOS
//
//  Created by Owen Godfrey on 2/5/18.
//  Copyright © 2018 Owen Godfrey. All rights reserved.
//

import UIKit
import CoreLocation
import CloudKit
import MapKit
import UserNotifications
import Armchair
import os.log

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let locationManager = CLLocationManager()

    fileprivate let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "AppDelegate")

    var armchairTimer: Timer? = nil
    private(set) var overrideDate: Date? = nil
    private(set) var overrideProduct: CKRecord.Reference? = nil
    private(set) var overrideRegion: CKRecord.Reference? = nil
    private(set) var overrideStation: CKRecord.Reference? = nil
    private let calendar = Calendar.current

    
    /// Post launch initialisation
    ///
    /// - Parameters:
    ///   - application: The application object
    ///   - launchOptions: Theoptions used to launch the application
    /// - Returns: true if the application has launched successfully, false otherwise
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Armchair.appID("1389830186")
        Armchair.debugEnabled(false)
        Armchair.significantEventsUntilPrompt(5)
        Armchair.usesUntilPrompt(7)
        Armchair.tracksNewVersions(true)
        locationManager.requestWhenInUseAuthorization()
        FLSettingsBundleHelper.registerSettings()
        FLOCloud.shared.setupNotifications()
        FLOCloud.shared.setupSubscription(application: application)
        return true
    }

    /// Receieve remote notification
    ///
    /// - Parameters:
    ///   - application: The application object
    ///   - userInfo: A dictionary of notification information
    ///   - completionHandler: A completion handler to return results of handling the notification to
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        completionHandler(UIBackgroundFetchResult.newData)
        if UIApplication.shared.applicationState == .active {
            resetBadgeCounter()
        } else {
            incrementBadgeCounter()
        }
        switch UIApplication.shared.applicationState {
        case .active, .background:
            if let mapController = MapViewController.instance, mapController.mapView != nil {
                guard let ck = userInfo["ck"] as? [String: AnyObject],
                        let qry = ck["qry"] as? [String: AnyObject],
                        let af = qry["af"] as? [String: AnyObject] else {
                    break
                }
                if let offset = af[FLOCloud.NotifField.date.rawValue] as? TimeInterval {
                    let ref = calendar.date(from: DateComponents(timeZone: TimeZone(identifier: "Australia/Perth"),
                                                                 year: 2001,
                                                                 month: 1,
                                                                 day: 1))!
                    let date = Date(timeInterval: offset, since: ref)
                    mapController.globalDate = date
                }
                if let productRef = af[FLOCloud.NotifField.product.rawValue] as? String {
                    mapController.globalProduct = Product.all[Product.ident(from: CKRecord.ID(recordName: productRef))]
                }
                if let regionRef = af[FLOCloud.NotifField.region.rawValue] as? String {
                    let region = Region.all[Region.ident(from: CKRecord.ID(recordName: regionRef))]
                    if region?.location != nil && mapController.globalRegion != region {
                        mapController.mapView.setRegion(MKCoordinateRegion(center: region!.location!.coordinate,
                                                                           latitudinalMeters: region!.radius?.doubleValue ?? 5000,
                                                                           longitudinalMeters: region!.radius?.doubleValue ?? 5000),
                                                        animated: true)
                    }
                }
                if let stationRef = af[FLOCloud.NotifField.station.rawValue] as? CKRecord.Reference {
                    let station = Station.all[Station.tradingName(from: stationRef.recordID)]
                    if station?.coordinate != nil {
                        mapController.mapView.setRegion(MKCoordinateRegion(center: station!.coordinate,
                                                                           latitudinalMeters: 2000,
                                                                           longitudinalMeters: 2000),
                                                        animated: true)
                    }
                }
            }
        case .inactive:
            guard let ck = userInfo["ck"] as? [String: AnyObject],
                let qry = ck["qry"] as? [String: AnyObject],
                let af = qry["af"] as? [String: AnyObject] else {
                    break
            }
            if let offset = af[FLOCloud.NotifField.date.rawValue] as? TimeInterval {
                let ref = calendar.date(from: DateComponents(timeZone: TimeZone(identifier: "Australia/Perth"),
                                                             year: 2001,
                                                             month: 1,
                                                             day: 1))!
                let date = Date(timeInterval: offset, since: ref)
                overrideDate = date
            }
            if let productRef = af[FLOCloud.NotifField.product.rawValue] as? String {
                overrideProduct = CKRecord.Reference(recordID: CKRecord.ID(recordName: productRef), action: .deleteSelf)
            }
            if let regionRef = af[FLOCloud.NotifField.region.rawValue] as? String {
                overrideRegion = CKRecord.Reference(recordID: CKRecord.ID(recordName: regionRef), action: .deleteSelf)
            }
            if let stationRef = af[FLOCloud.NotifField.station.rawValue] as? String {
                overrideStation = CKRecord.Reference(recordID: CKRecord.ID(recordName: stationRef), action: .deleteSelf)
            }
        }
    }

    /// Prepare to resign active state
    ///
    /// - Parameter application: The application object
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        armchairTimer?.invalidate()
        armchairTimer = nil
        UserDefaults.standard.synchronize()
    }

    /// Notification that the app has entered background mode
    ///
    /// - Parameter application: The application object
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    /// Prepare for the applciation to become active
    ///
    /// - Parameter application: The application object
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    /// Perform actions due once theapplication has become active
    ///
    /// - Parameter application: application descriptionThe application object
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        armchairTimer?.invalidate()
        FLSettingsBundleHelper.checkSettings()
        FLSettingsBundleHelper.setVersion()
        resetBadgeCounter()
        let status = MapViewController.instance?.status ?? .uninitialised
        switch  status {
        case .ready:
            MapViewController.instance?.refreshData()
            armchairTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { (timer) in
                self.armchairTimer?.invalidate()
                Armchair.showPromptIfNecessary()
            }
        case .failed:
            os_log("Cloud database was not accessible", log: logger, type: .fault)
            let alert = UIAlertController(title: "Cloud Database",
                                          message: "The iCloud Database is not accessible. Please try again later.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            MapViewController.instance?.present(alert, animated: true, completion: {
            })
        default:
            break
        }
    }

    /// Prepare for application termination
    ///
    /// - Parameter application: The application object
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        UserDefaults.standard.synchronize()
    }

    /// Handle the case where the appication succeeeded in registering for remote notification
    ///
    /// - Parameters:
    ///   - application: The application object
    ///   - deviceToken: The token that represents this device
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
//        let tokens = deviceToken.map({String(format: "%02.2hhx", $0)})
//        let token = tokens.joined()
//        print("Device token: \(token)")
        FLOCloud.shared.didRegisterForRemoteNotifications()
    }

    /// Handle the case where the application did fail to register for remote notifications
    ///
    /// - Parameters:
    ///   - application: The application object
    ///   - error: The errorthat prevented registration
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        os_log("Failed to register for Remote Notifications", log: logger, type: .fault, error.localizedDescription)
    }

    /// Increment the application badge counter by one
    func incrementBadgeCounter() {
        let counter = UserDefaults.standard.integer(forKey: FLSettingsBundleHelper.Keys.badgeNumber.rawValue) + 1
        UserDefaults.standard.set(counter, forKey: FLSettingsBundleHelper.Keys.badgeNumber.rawValue)
        UserDefaults.standard.synchronize()
        UIApplication.shared.applicationIconBadgeNumber = counter
    }

    /// Reset the application badge counter
    func resetBadgeCounter() {
        let badgeResetOperation = CKModifyBadgeOperation(badgeValue: 0)
        badgeResetOperation.modifyBadgeCompletionBlock = { (error) -> Void in
            guard error == nil else {
                print("Error resetting badge: \(error!.localizedDescription)")
                return
            }
        }
        FLOCloud.shared.container.add(badgeResetOperation)
        UIApplication.shared.applicationIconBadgeNumber = 0
        UserDefaults.standard.removeObject(forKey: FLSettingsBundleHelper.Keys.badgeNumber.rawValue)
        UserDefaults.standard.synchronize()
    }
}

