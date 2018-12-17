//
//  FLSettingsBundleHelper.swift
//  Fuel Locator iOS
//
//  Created by Owen Godfrey on 30/6/18.
//  Copyright © 2018 Owen Godfrey. All rights reserved.
//

import Foundation

class FLSettingsBundleHelper {
    typealias `Self` = FLSettingsBundleHelper
    static let defaults = UserDefaults.standard
    static let notificationCentre = NotificationCenter.default

    static func registerSettings() {
        defaults.register(defaults: [
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
            Keys.mapType.rawValue : 0,
            Keys.notificationProduct.rawValue: Product.Known.ulp.rawValue,
            Keys.notificationRegion.rawValue: Region.Known.metropolitanArea.rawValue,
            Keys.notificationPriceChange.rawValue: 0.05,
            Keys.productLastUsed.rawValue: Product.Known.ulp.rawValue,
            Keys.versionNumber.rawValue: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String,
            Keys.buildNumber.rawValue: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String])
        notificationCentre.addObserver(self, selector: #selector(settingsChanged), name: UserDefaults.didChangeNotification, object: nil)
    }

    @objc static func settingsChanged(not: Notification) {
        if not.name == UserDefaults.didChangeNotification {
            if FLOCloud.shared.isEnabled {
                FLOCloud.shared.changeSubscription()
            }
            MapViewController.instance?.refreshAnnotations()
        }
    }

    enum Keys: String {
        case notificationProduct = "notification.product"
        case notificationRegion = "notification.region"
        case notificationStation = "notification.station"
        case notificationPriceChange = "notification.priceChange"
        case productLastUsed = "Product.lastUsed"
        case versionNumber = "versionNumber"
        case buildNumber = "buildNumber"
        case mapType = "mapType"
    }

    static func checkSettings() {

    }

    static func setVersion() {
        defaults.set(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String, forKey: Keys.versionNumber.rawValue)
        defaults.set(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String, forKey: Keys.buildNumber.rawValue)
        defaults.synchronize()
    }
}
