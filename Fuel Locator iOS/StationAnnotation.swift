//
//  StationAnnotation.swift
//  Fuel Locator iOS
//
//  Created by Owen Godfrey on 9/5/18.
//  Copyright © 2018 Owen Godfrey. All rights reserved.
//

import MapKit
import Contacts

class StationAnnotation: MKPointAnnotation {

    let station: Station
    var category = 0

    static let format: NumberFormatter = {
        let f = NumberFormatter()
        f.positiveFormat = "##0.# 'cpl'"
        return f
    }()

    init(_ station: Station) {
        self.station = station
        super.init()
        coordinate = station.coordinate
        subtitle = station.tradingName
        self.refresh()
    }

    func mapItem() -> MKMapItem {
        var addressDict = [CNPostalAddressStateKey: "Western Australia"]
        if station.address != nil {
            addressDict[CNPostalAddressStreetKey] = station.address!
        }
        if station.suburb?.name != nil {
            addressDict[CNPostalAddressCityKey] = station.suburb!.name
        }

        let placemark = MKPlacemark(coordinate: station.coordinate, addressDictionary: addressDict)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.phoneNumber = station.phone
        mapItem.timeZone = TimeZone(identifier: "Australia/Perth")
        mapItem.name = station.tradingName
        return mapItem
    }

    func refresh() {
        if let price: PriceOnDay = PriceOnDay.all[station.tradingName] {
            let p = Double(price.adjustedPrice) / 10.0
            self.title = StationAnnotation.format.string(from: p as NSNumber)
            if let d: Int16 = station.brand?.useDiscount ?? false ? station.brand?.discount : nil {
                self.title = "\(StationAnnotation.format.string(from: p as NSNumber)!) (\(d)c)"
            }

            if let region = station.suburb?.region?.first {
                if let stats: Statistics = Statistics.all[(region.ident)] {
                    if stats.median != nil {
                        switch price.adjustedPrice {
                        case 0 ..< stats.per10!.int16Value:
                            category = 1
                        case stats.per10!.int16Value ..< stats.per20!.int16Value:
                            category = 2
                        case stats.per20!.int16Value ..< stats.per30!.int16Value:
                            category = 3
                        case stats.per30!.int16Value ..< stats.per40!.int16Value:
                            category = 4
                        case stats.per40!.int16Value ..< stats.per50!.int16Value:
                            category = 5
                        case stats.per50!.int16Value ..< stats.per60!.int16Value:
                            category = 6
                        case stats.per60!.int16Value ..< stats.per70!.int16Value:
                            category = 7
                        case stats.per70!.int16Value ..< stats.per80!.int16Value:
                            category = 8
                        case stats.per80!.int16Value ..< stats.per90!.int16Value:
                            category = 9
                        case stats.per90!.int16Value ... Int16.max:
                            category = 10
                        default:
                            break
                        }
                    }
                }
            }
        } else {
            self.title = ""
        }
    }

}
