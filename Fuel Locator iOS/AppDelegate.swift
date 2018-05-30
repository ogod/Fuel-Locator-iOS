//
//  AppDelegate.swift
//  Fuel Locator iOS
//
//  Created by Owen Godfrey on 2/5/18.
//  Copyright © 2018 Owen Godfrey. All rights reserved.
//

import UIKit
import CoreLocation
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let locationManager = CLLocationManager()

    fileprivate func registerUserDefaults() {
        UserDefaults.standard.register(defaults: [
            Brand.Known.ampol.key : false,
            Brand.Known.betterChoice.key : false,
            Brand.Known.blackWhite.key : false,
            Brand.Known.boc.key : false,
            Brand.Known.bp.key : false,
            Brand.Known.caltex.key : false,
            Brand.Known.caltexWoolworths.key : false,
            Brand.Known.colesExpress.key : false,
            Brand.Known.eagle.key : false,
            Brand.Known.fastfuel24_7.key : false,
            Brand.Known.fuelsWest.key : false,
            Brand.Known.gull.key : false,
            Brand.Known.kleenheat.key : false,
            Brand.Known.kwikfuel.key : false,
            Brand.Known.liberty.key : false,
            Brand.Known.mobil.key : false,
            Brand.Known.peak.key : false,
            Brand.Known.pumaEnergy.key : false,
            Brand.Known.sevenEleven.key : false,
            Brand.Known.shell.key : false,
            Brand.Known.united.key : false,
            Brand.Known.vibe.key : false,
            Brand.Known.wesco.key : false,
            "Product.lastUsed" : Product.Known.ulp.rawValue])
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        locationManager.requestWhenInUseAuthorization()
        application.applicationIconBadgeNumber = 0
        registerUserDefaults()
        FLOCloud.shared.setupNotifications()
        FLOCloud.shared.setupSubscription(application: application)
        if let notification = launchOptions?[.remoteNotification] {
            print(notification)
//            FLOCloud.shared.dateFromMessage = 
        }
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        UserDefaults.standard.synchronize()    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        switch MapViewController.instance?.status ?? .uninitialised {
        case .ready:
            MapViewController.instance?.refreshData()
        case .failed:
            let alert = UIAlertController(title: "Cloud Database",
                                          message: "The iCloud Database is not accessible. Please try again later.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            MapViewController.instance?.present(alert, animated: true, completion: {
                abort()
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
        let tokens = deviceToken.map({String(format: "%02.2hhx", $0)})
        let token = tokens.joined()
        print("Device token: \(token)")
        FLOCloud.shared.didRegisterForRemoteNotifications()
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register: \(error)")
    }
}

