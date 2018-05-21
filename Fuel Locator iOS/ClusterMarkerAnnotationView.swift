//
//  ClusterMarkerAnnotationView.swift
//  Fuel Locator iOS
//
//  Created by Owen Godfrey on 9/5/18.
//  Copyright © 2018 Owen Godfrey. All rights reserved.
//

import UIKit
import MapKit

class ClusterMarkerAnnotationView: MKMarkerAnnotationView {

    static let format: NumberFormatter = {
        let f = NumberFormatter()
        f.positiveFormat = "##0.# 'cpl'"
        return f
    }()

    override var annotation: MKAnnotation? {
        didSet {
            guard let cluster = annotation as? MKClusterAnnotation else {
                return
            }
            glyphText = "\(cluster.memberAnnotations.count)"
            guard let annot = cluster.memberAnnotations.first as? StationAnnotation else {
                return
            }
            switch annot.category {
            case 1:
                markerTintColor = UIColor(named: "per10")
            case 2:
                markerTintColor = UIColor(named: "per20")
            case 3:
                markerTintColor = UIColor(named: "per30")
            case 4:
                markerTintColor = UIColor(named: "per40")
            case 5:
                markerTintColor = UIColor(named: "per50")
            case 6:
                markerTintColor = UIColor(named: "per60")
            case 7:
                markerTintColor = UIColor(named: "per70")
            case 8:
                markerTintColor = UIColor(named: "per80")
            case 9:
                markerTintColor = UIColor(named: "per90")
            case 10:
                markerTintColor = UIColor(named: "per100")
            default:
                markerTintColor = UIColor.lightGray
            }
        }
    }

}
