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

    @objc enum Category: Int {
        case none = 0
        case bottom10 = 1
        case bottom20 = 2
        case bottom30 = 3
        case bottom40 = 4
        case bottom50 = 5
        case top50 = 6
        case top40 = 7
        case top30 = 8
        case top20 = 9
        case top10 = 10
        case uncatergorizable = -1
    }

    let station: Station
    @objc dynamic var category: Category = .none

    static let format: NumberFormatter = {
        let f = NumberFormatter()
        f.positiveFormat = "##0.0 'c/l'"
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
        let suburb: Suburb! = {
            if station.suburb != nil {
                return station.suburb
            }
            if let station = Station.all[self.station.tradingName] {
                return station.suburb
            }
            return nil
        }()
        let region: Region! = {
            guard suburb != nil else {
                return nil
            }
            return suburb?.majorRegion ?? Suburb.all[suburb!.ident]?.majorRegion
        }()
        let stats: Statistics! = (region != nil ? Statistics.all[(region.ident)] : nil)
        if let price: PriceOnDay = PriceOnDay.all[station.tradingName] {
            let p = Double(price.adjustedPrice) / 10.0
            self.title = StationAnnotation.format.string(from: p as NSNumber)
            if let d: Int16 = station.brand?.useDiscount ?? false ? (station.brand?.personalDiscount ?? station.brand?.discount) : nil {
                self.title = "\(StationAnnotation.format.string(from: p as NSNumber)!) (\(d)c)"
            }

            if region != nil && stats?.median != nil {
                switch price.adjustedPrice {
                case 0 ..< stats.per10!.int16Value:
                    category = .bottom10
                case stats.per10!.int16Value ..< stats.per20!.int16Value:
                    category = .bottom20
                case stats.per20!.int16Value ..< stats.per30!.int16Value:
                    category = .bottom30
                case stats.per30!.int16Value ..< stats.per40!.int16Value:
                    category = .bottom40
                case stats.per40!.int16Value ..< stats.per50!.int16Value:
                    category = .bottom50
                case stats.per50!.int16Value ..< stats.per60!.int16Value:
                    category = .top50
                case stats.per60!.int16Value ..< stats.per70!.int16Value:
                    category = .top40
                case stats.per70!.int16Value ..< stats.per80!.int16Value:
                    category = .top30
                case stats.per80!.int16Value ..< stats.per90!.int16Value:
                    category = .top20
                case stats.per90!.int16Value ... Int16.max:
                    category = .top10
                default:
                    // Shouldn't happen
                    category = .none
                }
            } else {
                // has price, but no category
                category = .uncatergorizable
            }
        } else if stats?.median != nil {
            // Has no price, but stats exist
            self.title = "— none —"
            category = .none
        } else {
            // No price and no statistics
            self.title = "— no data —"
            category = .uncatergorizable
        }
    }

}
