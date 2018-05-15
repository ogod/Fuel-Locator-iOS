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
            canShowCallout = true
            let mapsButton = UIButton(frame: CGRect(origin: CGPoint.zero,
                                                    size: CGSize(width: 30, height: 30)))
            mapsButton.setBackgroundImage(UIImage(named: "map_location"), for: UIControlState())
            rightCalloutAccessoryView = mapsButton
            refresh()
        }
    }

    func refresh() {
        guard let annot = annotation as? StationAnnotation else {
            return
        }
        markerTintColor = UIColor.gray
        displayPriority = .defaultHigh
        DispatchQueue.global().async {
            if let price: PriceOnDay = PriceOnDay.all[annot.station.tradingName] {
                if annot.station.suburb?.region != nil {
                    if let stats: Statistics = Statistics.all[(annot.station.suburb!.region!.first!.ident)] {
                        if stats.median != nil {
                            DispatchQueue.main.async {
                                switch price.adjustedPrice {
                                case 0 ..< stats.per10!.int16Value:
                                    self.markerTintColor = UIColor(named: "per10")
                                    self.displayPriority = MKFeatureDisplayPriority(900)
                                case stats.per10!.int16Value ..< stats.per20!.int16Value:
                                    self.markerTintColor = UIColor(named: "per20")
                                    self.displayPriority = MKFeatureDisplayPriority(890)
                                case stats.per20!.int16Value ..< stats.per30!.int16Value:
                                    self.markerTintColor = UIColor(named: "per30")
                                    self.displayPriority = MKFeatureDisplayPriority(870)
                                case stats.per30!.int16Value ..< stats.per40!.int16Value:
                                    self.markerTintColor = UIColor(named: "per40")
                                    self.displayPriority = MKFeatureDisplayPriority(860)
                                case stats.per40!.int16Value ..< stats.per50!.int16Value:
                                    self.markerTintColor = UIColor(named: "per50")
                                    self.displayPriority = MKFeatureDisplayPriority(850)
                                case stats.per50!.int16Value ..< stats.per60!.int16Value:
                                    self.markerTintColor = UIColor(named: "per60")
                                    self.displayPriority = MKFeatureDisplayPriority(840)
                                case stats.per60!.int16Value ..< stats.per70!.int16Value:
                                    self.markerTintColor = UIColor(named: "per70")
                                    self.displayPriority = MKFeatureDisplayPriority(830)
                                case stats.per70!.int16Value ..< stats.per80!.int16Value:
                                    self.markerTintColor = UIColor(named: "per80")
                                    self.displayPriority = MKFeatureDisplayPriority(820)
                                case stats.per80!.int16Value ..< stats.per90!.int16Value:
                                    self.markerTintColor = UIColor(named: "per90")
                                    self.displayPriority = MKFeatureDisplayPriority(810)
                                case stats.per90!.int16Value ... Int16.max:
                                    self.markerTintColor = UIColor(named: "per100")
                                    self.displayPriority = MKFeatureDisplayPriority(800)
                                default:
                                    self.markerTintColor = UIColor.gray
                                    self.displayPriority = MKFeatureDisplayPriority.defaultLow
                                }
                            }
                        }
                    }
                }
            }
        }
        DispatchQueue.main.async {
            self.setNeedsDisplay()
        }
    }
}
