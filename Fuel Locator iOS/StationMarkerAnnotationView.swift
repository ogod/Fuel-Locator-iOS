//
//  StationMarkerAnnotationView.swift
//  Fuel Locator iOS
//
//  Created by Owen Godfrey on 9/5/18.
//  Copyright © 2018 Owen Godfrey. All rights reserved.
//

import UIKit
import MapKit
import CoreImage

class StationMarkerAnnotationView: MKMarkerAnnotationView {

    static var calendar = Calendar.current

    override var annotation: MKAnnotation? {
        didSet {
            guard let annot = annotation as? StationAnnotation else {
                return
            }
            clusteringIdentifier = "station"
            canShowCallout = true
            let mapsButton = UIButton(frame: CGRect(origin: CGPoint.zero,
                                                    size: CGSize(width: 30, height: 30)))
            mapsButton.setBackgroundImage(UIImage(named: "map_location"), for: UIControlState())
            rightCalloutAccessoryView = mapsButton
            let detailLabel = UILabel()
            detailLabel.numberOfLines = 0
            detailLabel.font = detailLabel.font.withSize(12)
            let features = annot.station.siteFeatures?.reduce("", { $0 + ($0 == "" ? "  " : "\n  ") + $1 })
            if let brand = annot.station.brand {
                if brand.brandIdent == Brand.Known.independent {
                    glyphText = "Ind"
                    glyphImage = nil
                    detailLabel.text = """
                                        \(annot.station.tradingName)
                                        \(annot.station.address ?? ""), \(annot.station.suburb?.name ?? "Unknown Suburb")
                                        \(annot.station.phone ?? "")
                                        \(features ?? "")
                                        """
                    leftCalloutAccessoryView = nil
                } else {
                    glyphImage = brand.glyph
                    glyphText = nil
                    detailLabel.text = """
                                        \(annot.station.tradingName)
                                        Brand: \(brand.name)
                                        \(annot.station.address ?? ""), \(annot.station.suburb?.name ?? "Unknown Suburb")
                                        \(annot.station.phone ?? "")
                                        Discount: \(brand.useDiscount ? String(brand.discount) + "c" : "Not") active
                                        \(features ?? "")
                                        """
                    leftCalloutAccessoryView = UIImageView(image: brand.image)
                }
            }
            detailCalloutAccessoryView = detailLabel
            refresh()
        }
    }

    func refresh() {
        guard let annot = annotation as? StationAnnotation else {
            return
        }
        switch annot.category {
        case 1:
            clusteringIdentifier = "per10"
            markerTintColor = UIColor(named: "per10")
            displayPriority = MKFeatureDisplayPriority(900)
        case 2:
            clusteringIdentifier = "per20"
            markerTintColor = UIColor(named: "per20")
            displayPriority = MKFeatureDisplayPriority(890)
        case 3:
            clusteringIdentifier = "per30"
            markerTintColor = UIColor(named: "per30")
            displayPriority = MKFeatureDisplayPriority(870)
        case 4:
            clusteringIdentifier = "per40"
            markerTintColor = UIColor(named: "per40")
            displayPriority = MKFeatureDisplayPriority(860)
        case 5:
            clusteringIdentifier = "per50"
            markerTintColor = UIColor(named: "per50")
            displayPriority = MKFeatureDisplayPriority(850)
        case 6:
            clusteringIdentifier = "per60"
            markerTintColor = UIColor(named: "per60")
            displayPriority = MKFeatureDisplayPriority(840)
        case 7:
            clusteringIdentifier = "per70"
            markerTintColor = UIColor(named: "per70")
            displayPriority = MKFeatureDisplayPriority(830)
        case 8:
            clusteringIdentifier = "per80"
            markerTintColor = UIColor(named: "per80")
            displayPriority = MKFeatureDisplayPriority(820)
        case 9:
            clusteringIdentifier = "per90"
            markerTintColor = UIColor(named: "per90")
            displayPriority = MKFeatureDisplayPriority(810)
        case 10:
            clusteringIdentifier = "per100"
            markerTintColor = UIColor(named: "per100")
            displayPriority = MKFeatureDisplayPriority(800)
        default:
            clusteringIdentifier = "per00"
            markerTintColor = UIColor.lightGray
            displayPriority = MKFeatureDisplayPriority(100)
        }
        setNeedsDisplay()
    }
}
