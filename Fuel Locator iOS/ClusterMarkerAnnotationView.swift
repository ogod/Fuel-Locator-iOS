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
            case .bottom10:
                markerTintColor = UIColor(named: "per10")
            case .bottom20:
                markerTintColor = UIColor(named: "per20")
            case .bottom30:
                markerTintColor = UIColor(named: "per30")
            case .bottom40:
                markerTintColor = UIColor(named: "per40")
            case .bottom50:
                markerTintColor = UIColor(named: "per50")
            case .top50:
                markerTintColor = UIColor(named: "per60")
            case .top40:
                markerTintColor = UIColor(named: "per70")
            case .top30:
                markerTintColor = UIColor(named: "per80")
            case .top20:
                markerTintColor = UIColor(named: "per90")
            case .top10:
                markerTintColor = UIColor(named: "per100")
            case .none:
                markerTintColor = UIColor(named: "per00")
            case .uncatergorizable:
                markerTintColor = UIColor(named: "perNone")
            }
        }
    }

}
