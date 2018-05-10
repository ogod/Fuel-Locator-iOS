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

    override var annotation: MKAnnotation? {
        willSet {
            if let cluster = annotation as? MKClusterAnnotation {
                glyphText = "\(cluster.memberAnnotations.count)"
                markerTintColor = UIColor.darkGray
            }
        }
    }

}
