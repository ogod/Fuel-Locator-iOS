//
//  StationAnnotation.swift
//  Fuel Locator iOS
//
//  Created by Owen Godfrey on 9/5/18.
//  Copyright © 2018 Owen Godfrey. All rights reserved.
//

import MapKit

class StationAnnotation: MKPointAnnotation {

    let station: Station

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
        DispatchQueue.global().async {
            self.refresh()
        }
    }

    func refresh() {
        if let price: PriceOnDay = PriceOnDay.all[station.tradingName] {
            DispatchQueue.main.async {
                let price = Double(price.adjustedPrice) / 10.0
                self.title = StationAnnotation.format.string(from: price as NSNumber)
            }
        } else {
            DispatchQueue.main.async {
                self.title = ""
            }
        }
    }

}
