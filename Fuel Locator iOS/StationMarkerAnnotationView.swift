//
//  StationMarkerAnnotationView.swift
//  Fuel Locator iOS
//
//  Created by Owen Godfrey on 9/5/18.
//  Copyright © 2018 Owen Godfrey. All rights reserved.
//

import UIKit
import MapKit

class StationMarkerAnnotationView: MKMarkerAnnotationView {

    static var calendar = Calendar.current

    override var annotation: MKAnnotation? {
        willSet {
            guard let annot = newValue as? StationAnnotation else {
                return
            }
            glyphImage = annot.station.brand?.image
            clusteringIdentifier = "station"
            refresh()
        }
    }

    func refresh() {
        guard let annot = annotation as? StationAnnotation else {
            return
        }
        markerTintColor = UIColor.gray
        displayPriority = .defaultHigh
        if let price: PriceOnDay = PriceOnDay.all[annot.station.tradingName] {
            if annot.station.suburb?.region != nil {
                if let stats: Statistics = Statistics.all[(annot.station.suburb!.region!.first!)] {
                    if stats.median != nil {
                        switch price.adjustedPrice {
                        case stats.minimum!.int16Value ... stats.per10!.int16Value:
                            markerTintColor = UIColor(named: "per10")
                            displayPriority = MKFeatureDisplayPriority(900)
                        case stats.per10!.int16Value ... stats.per20!.int16Value:
                            markerTintColor = UIColor(named: "per20")
                            displayPriority = MKFeatureDisplayPriority(890)
                        case stats.per20!.int16Value ... stats.per30!.int16Value:
                            markerTintColor = UIColor(named: "per30")
                            displayPriority = MKFeatureDisplayPriority(870)
                        case stats.per30!.int16Value ... stats.per40!.int16Value:
                            markerTintColor = UIColor(named: "per40")
                            displayPriority = MKFeatureDisplayPriority(860)
                        case stats.per40!.int16Value ... stats.per50!.int16Value:
                            markerTintColor = UIColor(named: "per50")
                            displayPriority = MKFeatureDisplayPriority(850)
                        case stats.per50!.int16Value ... stats.per60!.int16Value:
                            markerTintColor = UIColor(named: "per60")
                            displayPriority = MKFeatureDisplayPriority(840)
                        case stats.per60!.int16Value ... stats.per70!.int16Value:
                            markerTintColor = UIColor(named: "per70")
                            displayPriority = MKFeatureDisplayPriority(830)
                        case stats.per70!.int16Value ... stats.per80!.int16Value:
                            markerTintColor = UIColor(named: "per80")
                            displayPriority = MKFeatureDisplayPriority(820)
                        case stats.per80!.int16Value ... stats.per90!.int16Value:
                            markerTintColor = UIColor(named: "per90")
                            displayPriority = MKFeatureDisplayPriority(810)
                        case stats.per90!.int16Value ... stats.maximum!.int16Value:
                            markerTintColor = UIColor(named: "per100")
                            displayPriority = MKFeatureDisplayPriority(800)
                        default:
                            markerTintColor = UIColor.gray
                            displayPriority = MKFeatureDisplayPriority.defaultLow
                        }
                    }
                }
            }
        }
    }
}
