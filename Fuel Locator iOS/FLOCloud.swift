//
//  FLOCloudInterface.swift
//  Fuel Locator OSX
//
//  Created by Owen Godfrey on 14/7/17.
//  Copyright © 2017 Owen Godfrey. All rights reserved.
//

import Foundation
import CloudKit
import UserNotifications
import UIKit
import os.log

class FLOCloud: NSObject {

    var identifier: String
    static let shared: FLOCloud = FLOCloud("iCloud.com.nomdejoye.Fuel-Locator-OSX")

    lazy var container = CKContainer(identifier: identifier)
    let queue = DispatchQueue(label: "Cloud Query Queue",
                              qos: .userInitiated,
                              attributes: .concurrent)

    init(_ identifier: String) {
        self.identifier = identifier
        super.init()
    }

    private let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "FLOCloud")

    var subscriptionIslocallyCached: Bool = false
    var sharedDBChangeToken: CKServerChangeToken? = nil
    let notifCentre = UNUserNotificationCenter.current()
    var timer: Timer!
    var t0: Timer!

    func setupNotifications() {
        notifCentre.delegate = self
    }

    func subscribe() {
        guard !subscriptionIslocallyCached else {
            return
        }
        let subscription = CKDatabaseSubscription(subscriptionID: "shared-changes")
        let notificationInfo = CKNotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
        operation.modifySubscriptionsCompletionBlock = { (savedSubscriptions, deletedIDs, error) -> Void in
            guard error == nil else {

                return
            } // Handle the error
            self.subscriptionIslocallyCached = true
        } as (([CKSubscription]?, [String]?, Error?) -> Void)
        operation.qualityOfService = .utility
        try? publicDatabase().add(operation)
    }

    func silentPush() {
        // Silent push
        let notificationInfo = CKNotificationInfo()
        // Set only this property
        notificationInfo.shouldSendContentAvailable = true
        // The device does NOT need to prompt for user acceptance!
        // Register for notifications via:
        UIApplication.shared.registerForRemoteNotifications()
    }

    func uiPush() {
        let notificationInfo = CKNotificationInfo()
        // Set any one of these three properties
        notificationInfo.shouldBadge = true
        notificationInfo.alertBody = NSLocalizedString("alertBody", comment: "")
        notificationInfo.soundName = "default"
        // The device needs to prompt for user acceptance via:
//        NSApplication.shared().registerForRemoteNotifications(matching: NSRemoteNotificationType.alert)
        // Register for notifications via:
        UIApplication.shared.registerForRemoteNotifications()
    }

    func subscribeToChanges() {
        let notificationInfo = CKNotificationInfo()
        // Set any one of these three properties
        notificationInfo.shouldBadge = true
        notificationInfo.alertBody = NSLocalizedString("alertBody", comment: "")
        notificationInfo.soundName = "default"
        // The device needs to prompt for user acceptance via:
//        NSApplication.shared().registerUserNotificationSettings(matching: NSRemoteNotificationType.alert)
        // Register for notifications via:
        UIApplication.shared.registerForRemoteNotifications()
    }

    func handleRemoteNotification(userInfo: [String : Any]) {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        if (notification.subscriptionID == "shared-changes") {
            fetchSharedChanges {
//                completionHandler(NSBackgroundFetchResult.newData)
            }
        }
    }

    func fetchSharedChanges(_ callback: @escaping () -> Void) {
        let changesOperation = CKFetchDatabaseChangesOperation(
            previousServerChangeToken: sharedDBChangeToken) // previously cached
        changesOperation.fetchAllChanges = true
        changesOperation.recordZoneWithIDChangedBlock = (((CKRecordZoneID) -> Void)?) { (recordZoneID) in
        } // collect zone IDs
        changesOperation.recordZoneWithIDWasDeletedBlock = (((CKRecordZoneID) -> Void)?) { (recordZoneID) in
        } // delete local cache
        changesOperation.changeTokenUpdatedBlock = (((CKServerChangeToken) -> Void)?) { (serverChangeToken) in
        } // cache new token
        changesOperation.fetchDatabaseChangesCompletionBlock = { (newToken, more, error) -> Void in
            // error handling here
            guard error == nil else {
                
                return
            }
            self.sharedDBChangeToken = newToken // cache new token
            self.fetchZoneChanges(callback) // using CKFetchRecordZoneChangesOperation
        } as ((CKServerChangeToken?, Bool, Error?) -> Void)
//        self.sharedDB.add(changesOperation)
    }

    var dateFromMessage: Date? = nil {
        didSet {
            if MapViewController.instance != nil {
//                MapViewController.instance!.globalDate = date
            }
        }
    }


    func fetchZoneChanges(_ callback: () -> Void) {

    }

    private(set) var isEnabled = false

    func alertUserToEnterICloudCredentials(controller: UIViewController, callBack: @escaping (Bool) -> Void) {
        container.accountStatus { (status, error) in
            guard error == nil else {
                return
            }
            if status == CKAccountStatus.noAccount {
                let alert = UIAlertController(title: "Sign in to iCloud",
                                              message: "Sign in to your iCloud account to write records. " +
                                                "On the Home screen, launch Settings, tap iCloud, and enter your Apple ID. " +
                    "Turn iCloud Drive on. If you don't have an iCloud account, tap Create a new Apple ID.",
                                              preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                controller.present(alert, animated: true) {
                    callBack(false)
                }
            } else {
                self.isEnabled = true
                callBack(true)
            }
        }
    }

    func publicDatabase() throws -> CKDatabase {
        guard isEnabled else {
            throw FLOError.cloudDatabaseNotAvailable
        }
        return container.publicCloudDatabase
    }
}

extension FLOCloud: UNUserNotificationCenterDelegate {
    // This extension ensures that the petrol prices are kept up to date.


//    func startTimer() {
//        let calendar = Calendar.current
//        let date = calendar.date(bySettingHour: 14, minute: 30, second: 0, of: Date())!
//        os_log("Setting timer to %@", log: logger, type: .default, date as NSDate)
//        timer = Timer(fireAt: date, interval: 24 * 60 * 60, target: self, selector: #selector(checkSite), userInfo: nil, repeats: true)
//        RunLoop.main.add(timer, forMode: .defaultRunLoopMode)
//    }
//
//    @objc func checkSite(timer: Timer) {
//        os_log("Timer triggered", log: logger, type: .default)
//        let calendar = Calendar.current
//        let today = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!
//        let past = calendar.date(byAdding: .day, value: -8, to: today)
//        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
//        let context = PersistentStore.instance.context
//        let dates = try! DateSequence(start: tomorrow, end: past, interval: -1, unit: .day, calendar: calendar).filter { (date) -> Bool in
//            PriceOnDay.count(day: tomorrow, from: context) < 300
//        }
//        os_log("Checking site", log: self.logger, type: .error)
//
//        guard dates.count != 0 else {
//            os_log("No need to check", log: self.logger, type: .error)
//            return
//        }
//
//        FuelWatchInfo.read(regions: Region.fetchAll(from: context), dates: dates) { (error) in
//            DispatchQueue.main.async {
//                guard error == nil else {
//                    os_log("Error occured during fuel price read: %@", log: self.logger, type: .error, error!.localizedDescription)
//                    let notification = NSUserNotification()
//                    notification.identifier = "automaticPriceRead"
//                    notification.title = "Error during fuel price read"
//                    notification.informativeText = error!.localizedDescription
//                    NSUserNotificationCenter.default.deliver(notification)
//                    self.t0 = Timer.init(timeInterval: 10 * 60, target: self, selector: #selector(self.checkSite), userInfo: nil, repeats: false)
//                    RunLoop.main.add(self.t0, forMode: .defaultRunLoopMode)
//                    return
//                }
//
//                guard PriceOnDay.count(day: tomorrow, from: context) != 0 else {
//                    self.t0 = Timer.init(timeInterval: 10 * 60, target: self, selector: #selector(self.checkSite), userInfo: nil, repeats: false)
//                    RunLoop.main.add(self.t0, forMode: .defaultRunLoopMode)
//                    return
//                }
//
//                let notification = NSUserNotification()
//                notification.identifier = "automaticPriceRead"
//                notification.title = "Automatic Fuel price read successfully complete"
//                NSUserNotificationCenter.default.deliver(notification)
//            }
//        }
//    }

    // Sent to the delegate when a notification delivery date has arrived. At this time, the notification
    // has either been presented to the user or the notification center has decided not to
    // present it because your application was already frontmost.
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didDeliver notification: UNNotification) {

    }


    // Sent to the delegate when a user clicks on a notification in the notification center.
    // This would be a good time to take action in response to user interacting with a specific notification.
    // Important: If want to take an action when your application is launched as a result of a
    // user clicking on a notification, be sure to implement the applicationDidFinishLaunching: method
    // on your NSApplicationDelegate. The notification parameter to that method has a userInfo dictionary,
    // and that dictionary has the NSApplicationLaunchUserNotificationKey key. The value of that key is the
    // NSUserNotification that caused the application to launch. The NSUserNotification is delivered to the
    // NSApplication delegate because that message will be sent before your application has a chance to set
    // a delegate for the NSUserNotificationCenter.
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didActivate notification: UNNotification) {
        print(notification)
//        self.dateFromMessage = 
    }

    // Sent to the delegate when the Notification Center has decided not to present your notification, for example when your application is front most. If you want the notification to be displayed anyway, return YES.
    public func userNotificationCenter(_ center: UNUserNotificationCenter, shouldPresent notification: UNNotification) -> Bool {
        return true
    }

    public func setupSubscription(application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (authorised, error) in
            guard error == nil else {
                print(error!)
                return
            }
            if authorised {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
    }

    func didRegisterForRemoteNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            print("Notification settings : \(settings)")
            guard settings.authorizationStatus == .authorized else {
                return
            }
        }

        let normalSuscription = CKQuerySubscription(recordType: "GlobalNotification",
                                               predicate: NSPredicate(value: true),
                                               options: .firesOnRecordCreation)
        let normalInfo = CKNotificationInfo()
        normalInfo.alertBody = "Tomorrow's fuel prices have been posted."
        normalInfo.shouldBadge = false
        normalInfo.soundName = "default"

        normalSuscription.notificationInfo = normalInfo

        do {
            try publicDatabase().save(normalSuscription, completionHandler: { (subscrip, error) in
                guard error == nil else {
                    switch error! {
                    case let err as CKError where err.code == .serverRejectedRequest:
                        break
                    default:
                        print(error!)
                    }
                    return
                }
                print("subscription saved successfuly")
            })
        } catch {
            print(error)
        }

        let risingSubscription = CKQuerySubscription(recordType: "GlobalNotification",
                                               predicate: NSPredicate(format: "priceRise = %@", NSNumber(integerLiteral: 1)),
                                               options: .firesOnRecordCreation)
        let risingInfo = CKNotificationInfo()
        risingInfo.alertBody = "Median fuel prices are rising tomorrow!"
        risingInfo.shouldBadge = true
        risingInfo.soundName = "Bloom"

        risingSubscription.notificationInfo = risingInfo

        do {
            try publicDatabase().save(risingSubscription, completionHandler: { (subscrip, error) in
                guard error == nil else {
                    switch error! {
                    case let err as CKError where err.code == .serverRejectedRequest:
                        break
                    default:
                        print(error!)
                    }
                    return
                }
                print("subscription saved successfuly")
            })
        } catch {
            print(error)
        }
    }

}
