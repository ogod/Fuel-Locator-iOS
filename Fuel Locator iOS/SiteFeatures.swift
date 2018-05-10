//
//  SiteFeatures.swift
//  FuelLocator
//
//  Created by Owen Godfrey on 9/10/2014.
//  Copyright (c) 2014 Owen Godfrey. All rights reserved.
//

import Foundation
import CoreData

class SiteFeatures: Hashable {
    var hashValue: Int { return feature.hashValue ^ (station.hashValue << 8) }

    static func == (lhs: SiteFeatures, rhs: SiteFeatures) -> Bool {
        return lhs.feature == rhs.feature && lhs.station == rhs.station
    }


    public var feature: String
    public var station: Station
    public var systemFields: Data?

    init(feature: String, station: Station) {
        self.feature = feature
        self.station = station
    }
    
    static let lock = NSObject()

    public var description: String {
        return "\(feature)"
    }

    public var debugDescription: String {
        return "\(feature)"
    }
}
