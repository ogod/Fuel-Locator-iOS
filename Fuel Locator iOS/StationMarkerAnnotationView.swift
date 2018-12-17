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
import Armchair

class StationMarkerAnnotationView: MKMarkerAnnotationView {

    static var calendar = Calendar.current

    override var annotation: MKAnnotation? {
        didSet {
            guard let annot = annotation as? StationAnnotation else {
                return
            }
            let station = annot.station
            let suburb: Suburb! = {
                if station.suburb != nil {
                    return station.suburb
                }
                if let station = Station.all[station.tradingName] {
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

            clusteringIdentifier = "station"
            canShowCallout = true
            let mapsButton = UIButton(type: UIButton.ButtonType.detailDisclosure)
            mapsButton.addTarget(self, action: #selector(launchInMaps), for: UIControl.Event.touchUpInside)
            mapsButton.setImage(UIImage(named: "route-icon"), for: UIControl.State())
            mapsButton.isEnabled = true
            rightCalloutAccessoryView = mapsButton
            let detailLabel = UILabel()
            detailLabel.numberOfLines = 0
            detailLabel.font = detailLabel.font?.withSize(12) ?? UIFont(name: "Helvetica Neue", size: 12)
            let features = station.siteFeatures?.joined(separator: "\n  ") ?? "None"
            if let brand = station.brand {
                if brand.brandIdent == Brand.Known.independent {
                    glyphText = "Ind"
                    glyphImage = nil
                    detailLabel.text =  """
                                        Station: \(station.tradingName)
                                        Street: \(station.address ?? "--------")
                                        Suburb: \(suburb?.name ?? "--------")
                                        Region: \(region?.name ?? "--------")
                                        Phone: \(station.phone ?? "--------")
                                        Features: \(features)
                                        """
                    leftCalloutAccessoryView = nil
                } else {
                    glyphImage = brand.glyph
                    glyphText = nil
                    detailLabel.text =  """
                                        Station: \(station.tradingName)
                                        Brand: \(brand.name)
                                        Street: \(station.address ?? "--------")
                                        Suburb: \(suburb?.name ?? "--------")
                                        Region: \(region?.name ?? "--------")
                                        Phone: \(station.phone ?? "--------")
                                        Discount: \(brand.useDiscount ? String(brand.personalDiscount ?? brand.discount) + "c/l" : "Not") active
                                        Features: \(features)
                                        """
                    let image = brand.image
                    let view = UIImageView(image: image)
                    view.frame = CGRect(x: 0, y: 0, width: image.size.width * 2, height: image.size.height * 2)
                    leftCalloutAccessoryView = view
                }
            } else {
                glyphImage = nil
                glyphText = "?"
                detailLabel.text =  """
                                    Station: \(station.tradingName)
                                    Street: \(station.address ?? "--------")
                                    Suburb: \(suburb?.name ?? "--------")
                                    Region: \(region?.name ?? "--------")
                                    Phone: \(station.phone ?? "--------")
                                    Features: \(features)
                                    """
                leftCalloutAccessoryView = nil
            }
            detailCalloutAccessoryView = detailLabel
            refresh()
        }
    }

    @objc private func launchInMaps() {
        let launchOptions: [String: Any] = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
                                            MKLaunchOptionsShowsTrafficKey: true]
        Armchair.userDidSignificantEvent(true)
        (annotation as? StationAnnotation)?.mapItem().openInMaps(launchOptions: launchOptions)
    }

    func refresh() {
        guard let annot = annotation as? StationAnnotation else {
            return
        }
        switch annot.category {
        case .bottom10:
            clusteringIdentifier = "per10"
            markerTintColor = UIColor(named: "per10")
            displayPriority = MKFeatureDisplayPriority(900)
        case .bottom20:
            clusteringIdentifier = "per20"
            markerTintColor = UIColor(named: "per20")
            displayPriority = MKFeatureDisplayPriority(890)
        case .bottom30:
            clusteringIdentifier = "per30"
            markerTintColor = UIColor(named: "per30")
            displayPriority = MKFeatureDisplayPriority(870)
        case .bottom40:
            clusteringIdentifier = "per40"
            markerTintColor = UIColor(named: "per40")
            displayPriority = MKFeatureDisplayPriority(860)
        case .bottom50:
            clusteringIdentifier = "per50"
            markerTintColor = UIColor(named: "per50")
            displayPriority = MKFeatureDisplayPriority(850)
        case .top50:
            clusteringIdentifier = "per60"
            markerTintColor = UIColor(named: "per60")
            displayPriority = MKFeatureDisplayPriority(840)
        case .top40:
            clusteringIdentifier = "per70"
            markerTintColor = UIColor(named: "per70")
            displayPriority = MKFeatureDisplayPriority(830)
        case .top30:
            clusteringIdentifier = "per80"
            markerTintColor = UIColor(named: "per80")
            displayPriority = MKFeatureDisplayPriority(820)
        case .top20:
            clusteringIdentifier = "per90"
            markerTintColor = UIColor(named: "per90")
            displayPriority = MKFeatureDisplayPriority(810)
        case .top10:
            clusteringIdentifier = "per100"
            markerTintColor = UIColor(named: "per100")
            displayPriority = MKFeatureDisplayPriority(800)
        case .none:
            clusteringIdentifier = "per00"
            markerTintColor = UIColor(named: "per00")
            displayPriority = MKFeatureDisplayPriority(100)
        case .uncatergorizable:
            clusteringIdentifier = "perNone"
            markerTintColor = UIColor(named: "perNone")
            displayPriority = MKFeatureDisplayPriority(840)
        }
        self.setNeedsDisplay()
    }
}
