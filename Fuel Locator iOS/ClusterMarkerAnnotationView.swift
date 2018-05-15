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
        willSet {
            if let cluster = annotation as? MKClusterAnnotation {
                glyphText = "\(cluster.memberAnnotations.count)"
                markerTintColor = UIColor(named: "clusterColour")
//                let stations = cluster.memberAnnotations.map({$0 as? StationAnnotation}).filter({$0 != nil && $0!.title != nil}).map({$0!})
//                if let st = stations.first?.station {
//                    let prices = stations.map({Double($0.title!) ?? -1}).filter({$0 != -1})
//                    if let avPrice = prices.min() {
//                        cluster.title = ClusterMarkerAnnotationView.format.string(from: avPrice as NSNumber)
//                        if st.suburb?.region != nil {
//                            if let stats: Statistics = Statistics.all[(st.suburb!.region!.first!.ident)] {
//                                if stats.median != nil {
//                                    DispatchQueue.main.async {
//                                        switch Int16(avPrice*10) {
//                                        case 0 ..< stats.per10!.int16Value:
//                                            self.markerTintColor = UIColor(named: "per10c")
//                                            self.displayPriority = MKFeatureDisplayPriority(900)
//                                        case stats.per10!.int16Value ..< stats.per20!.int16Value:
//                                            self.markerTintColor = UIColor(named: "per20c")
//                                            self.displayPriority = MKFeatureDisplayPriority(890)
//                                        case stats.per20!.int16Value ..< stats.per30!.int16Value:
//                                            self.markerTintColor = UIColor(named: "per30c")
//                                            self.displayPriority = MKFeatureDisplayPriority(870)
//                                        case stats.per30!.int16Value ..< stats.per40!.int16Value:
//                                            self.markerTintColor = UIColor(named: "per40c")
//                                            self.displayPriority = MKFeatureDisplayPriority(860)
//                                        case stats.per40!.int16Value ..< stats.per50!.int16Value:
//                                            self.markerTintColor = UIColor(named: "per50c")
//                                            self.displayPriority = MKFeatureDisplayPriority(850)
//                                        case stats.per50!.int16Value ..< stats.per60!.int16Value:
//                                            self.markerTintColor = UIColor(named: "per60c")
//                                            self.displayPriority = MKFeatureDisplayPriority(840)
//                                        case stats.per60!.int16Value ..< stats.per70!.int16Value:
//                                            self.markerTintColor = UIColor(named: "per70c")
//                                            self.displayPriority = MKFeatureDisplayPriority(830)
//                                        case stats.per70!.int16Value ..< stats.per80!.int16Value:
//                                            self.markerTintColor = UIColor(named: "per80c")
//                                            self.displayPriority = MKFeatureDisplayPriority(820)
//                                        case stats.per80!.int16Value ..< stats.per90!.int16Value:
//                                            self.markerTintColor = UIColor(named: "per90c")
//                                            self.displayPriority = MKFeatureDisplayPriority(810)
//                                        case stats.per90!.int16Value ... Int16.max:
//                                            self.markerTintColor = UIColor(named: "per100c")
//                                            self.displayPriority = MKFeatureDisplayPriority(800)
//                                        default:
//                                            self.markerTintColor = UIColor.gray
//                                        }
//                                    }
//                                }
//                            }
//                        }
//                    }
//                }
            }
        }
    }

}
