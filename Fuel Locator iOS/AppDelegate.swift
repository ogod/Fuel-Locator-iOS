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
import UserNotifications
import Armchair
import os.log

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let locationManager = CLLocationManager()

    fileprivate let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "AppDelegate")

    var armchairTimer: Timer? = nil

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Armchair.appID("1389830186")
//        Armchair.debugEnabled(true)
        Armchair.significantEventsUntilPrompt(5)
        Armchair.usesUntilPrompt(7)
        locationManager.requestWhenInUseAuthorization()
        FLSettingsBundleHelper.registerSettings()
        FLOCloud.shared.setupNotifications()
        FLOCloud.shared.setupSubscription(application: application)
        if let notification = launchOptions?[.remoteNotification] {
            print(notification)
        }
        return true
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        application.applicationIconBadgeNumber = 1
        completionHandler(UIBackgroundFetchResult.noData)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        armchairTimer?.invalidate()
        armchairTimer = nil
        UserDefaults.standard.synchronize()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        armchairTimer?.invalidate()
        FLSettingsBundleHelper.checkSettings()
        FLSettingsBundleHelper.setVersion()
        application.applicationIconBadgeNumber = 0
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
                exit(0) // TODO: abort is not alowed
            })
        default:
            break
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        UserDefaults.standard.synchronize()
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
//        let tokens = deviceToken.map({String(format: "%02.2hhx", $0)})
//        let token = tokens.joined()
//        print("Device token: \(token)")
        FLOCloud.shared.didRegisterForRemoteNotifications()
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        os_log("Failed to register for Remote Notifications", log: logger, type: .fault, error.localizedDescription)
    }
}

