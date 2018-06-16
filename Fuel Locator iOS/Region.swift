//
//  Region.swift
//  FuelLocator
//
//  Created by Owen Godfrey on 9/10/2014.
//  Copyright (c) 2014 Owen Godfrey. All rights reserved.
//

import Foundation
import MapKit
import AddressBook
import CloudKit
import os.log

class Region: FLODataEntity, Hashable {
    static var all = FLODataEntityAll<Int16, Region>()

    static func == (lhs: Region, rhs: Region) -> Bool {
        return lhs.ident == rhs.ident
    }

    var hashValue: Int { return Int(ident) }

    init(ident: Int16, name: String) {
        self.ident = ident
        self.name = name
    }
    
    enum Known: Int16 {
        case metropolitanArea = -1
        case gascoyne = 1
        case goldfieldsEsperance = 2
        case greatSouthern = 3
        case kimberley = 4
        case midWest  = 5
        case peel = 6
        case pilbara = 7
        case southWest = 8
        case wheatbelt = 9
        case northOfTheRiver = 25
        case southOfTheRiver = 26
        case eastHills = 27

        var name: String! {
            switch self {
            case .metropolitanArea:
                return "Metropolitan Area"
            case .gascoyne:
                return "Gascoyne"
            case .goldfieldsEsperance:
                return "Goldfields-Esperance"
            case .greatSouthern:
                return "Great Southern"
            case .kimberley:
                return "Kimberley"
            case .midWest:
                return "Mid West"
            case .peel:
                return "Peel"
            case .pilbara:
                return "Pilbara"
            case .southWest:
                return "South West"
            case .wheatbelt:
                return "Wheatbelt"
            case .northOfTheRiver:
                return "North of the River"
            case .southOfTheRiver:
                return "South of the River"
            case .eastHills:
                return "East/Hills"
            }
        }
        var recordId: CKRecordID {
            return Region.recordId(from: rawValue)
        }
}

    init(record: CKRecord) {
        ident = Brand.ident(from: record.recordID)
        name = record["name"] as! String
        latitude = record["latitude"] as? NSNumber ?? 0
        longitude = record["longitude"] as? NSNumber ?? 0
        radius = record["radius"] as? NSNumber ?? 0
        systemFields = Brand.archiveSystemFields(from: record)
    }

    public var ident: Int16
    public var latitude: NSNumber?
    public var longitude: NSNumber?
    public var name: String
    public var radius: NSNumber?
    public var statistics: Set<Statistics>?
    public var suburb: Set<Suburb>?
    public var systemFields: Data?

    var location: CLLocation? {
        get {
            return latitude != nil && longitude != nil ?
                CLLocation(latitude: latitude! as! Double, longitude: longitude! as! Double) :
                nil
        }
        set (newLocation) {
            latitude = newLocation?.coordinate.latitude as NSNumber?
            latitude = newLocation?.coordinate.latitude as NSNumber?
        }
    }

    var geographicRegion: CLCircularRegion? {
        get {
            if latitude != nil && longitude != nil && radius != nil {
                let loc = CLLocationCoordinate2D(latitude: latitude! as! Double, longitude: longitude! as! Double)
                return CLCircularRegion(center: loc, radius: radius! as! Double, identifier: name)
            } else {
                return nil
            }
        }
        set (newRegion) {
            latitude = newRegion?.center.latitude as NSNumber?
            longitude = newRegion?.center.longitude as NSNumber?
            radius = newRegion?.radius as NSNumber?
        }
    }

    class func contains(_ region: Region, suburb: Suburb) -> Bool {
        return region.suburb?.contains(suburb) ?? false
    }

    static let lock = NSObject()
    let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "Region")

    public var description: String {
        return "Region \(name)"
    }

    public var debugDescription: String {
        return "Region (\(ident), \(name))"
    }

    class func fetch(withIdent ident: Int16, _ completionBlock: @escaping (Region?, Error?) -> Void) {
        let pred = NSPredicate(format: "ident == %@", ident)
        let query = CKQuery(recordType: "FWRegion", predicate: pred)

        do {
            Region.download(fromDatabase: try FLOCloud.shared.publicDatabase(), withQuery: query) { (error, records) in
                let reg: Region? = (records == nil || records!.isEmpty ? nil : Region(record: records!.first!))
                completionBlock(reg, error)
            }
        } catch {
            print(error)
        }
    }

    class func fetchAll(_ completionBlock: @escaping (Set<Region>, Error?) -> Void) {
        let pred = NSPredicate(value: true)
        let query = CKQuery(recordType: "FWRegion", predicate: pred)

        do {
            Region.download(fromDatabase: try FLOCloud.shared.publicDatabase(), withQuery: query) { (error, records) in
                let regions = Set<Region>(records?.map({ Region(record: $0) }) ?? [])
                completionBlock(regions, error)
            }
        } catch {
            print(error)
        }
    }

    var key: Int16 {
        return ident
    }

    class func ident(from recordID: CKRecordID) -> Int16 {
        let str = recordID.recordName
        let index = str.index(after: str.index(of: ":")!)
        return Int16(String(str[index...]))!
    }

    class func recordId(from ident: Int16) -> CKRecordID {
        return CKRecordID(recordName: "Region:" + String(ident))
    }

    class func recordId(from ident: Known) -> CKRecordID {
        return recordId(from: ident.rawValue)
    }

    var recordID: CKRecordID {
        return Region.recordId(from: ident)
    }

    func hasChanged(from record: CKRecord) -> Bool {
        if let n = record["name"] as? String {
            if n != name {
                return true
            }
        }
        let loc = record["location"] as? CLLocation
        if loc?.coordinate.latitude != latitude?.doubleValue || loc?.coordinate.longitude != longitude?.doubleValue {
            return true
        }
        let rad = record["radius"] as? Double
        if rad != radius?.doubleValue {
            return true
        }
        return false
    }

    var record: CKRecord {
        get {
            let r: CKRecord
            if systemFields == nil {
                r = CKRecord(recordType: "FWRegion", recordID: recordID)
            } else {
                let unarchiver = NSKeyedUnarchiver(forReadingWith: systemFields!)
                unarchiver.requiresSecureCoding = true
                r = CKRecord(coder: unarchiver)!
            }
            r["name"] = name as NSString
            if latitude != nil && longitude != nil {
                r["location"] = CLLocation.init(latitude: CLLocationDegrees(truncating: latitude!), longitude: CLLocationDegrees(truncating: longitude!))
            }
            if radius != nil {
                r["radius"] = radius!.doubleValue as NSNumber
            }
            return r
        }
        set {
            systemFields = Region.archiveSystemFields(from: newValue)
            ident = Region.ident(from: newValue.recordID)
            if let n = newValue["name"] as? String {
                if n != name {
                    name = n
                }
            }
            let loc = newValue["location"] as? CLLocation
            if loc?.coordinate.latitude != latitude?.doubleValue || loc?.coordinate.longitude != longitude?.doubleValue {
                latitude = loc?.coordinate.latitude as NSNumber?
                longitude = loc?.coordinate.longitude as NSNumber?
            }
            let rad = newValue["radius"] as? Double
            if rad != radius?.doubleValue {
                radius = rad as NSNumber?
            }
        }
    }
}

extension Region {
//    fileprivate struct Static {
//        static let lock = NSObject()
//        static let mainQueue = ProcessingQueue(queue: DispatchQueue.main, interval: 30)
//        static let geocoder = CLGeocoder()
//        static let sourceItems: [IIElement] = [
//            IIElement(ident: -1, value: "Metropolitan Area"),
//            IIElement(ident: 25, value: "North of River"),
//            IIElement(ident: 26, value: "South of River"),
//            IIElement(ident: 27, value: "East/Hills"),
//            IIElement(ident: 15, value: "Albany"),
//            IIElement(ident: 28, value: "Augusta / Margaret River"),
//            IIElement(ident: 30, value: "Bridgetown / Greenbushes"),
//            IIElement(ident: 1, value: "Boulder"),
//            IIElement(ident: 2, value: "Broome"),
//            IIElement(ident: 16, value: "Bunbury"),
//            IIElement(ident: 3, value: "Busselton (Townsite)"),
//            IIElement(ident: 29, value: "Busselton (Shire)"),
//            IIElement(ident: 19, value: "Capel"),
//            IIElement(ident: 4, value: "Carnarvon"),
//            IIElement(ident: 33, value: "Cataby"),
//            IIElement(ident: 5, value: "Collie"),
//            IIElement(ident: 34, value: "Coolgardie"),
//            IIElement(ident: 35, value: "Cunderdin"),
//            IIElement(ident: 31, value: "Donnybrook / Balingup"),
//            IIElement(ident: 36, value: "Dalwallinu"),
//            IIElement(ident: 6, value: "Dampier"),
//            IIElement(ident: 20, value: "Dardanup"),
//            IIElement(ident: 37, value: "Denmark"),
//            IIElement(ident: 38, value: "Derby"),
//            IIElement(ident: 39, value: "Dongara"),
//            IIElement(ident: 7, value: "Esperance"),
//            IIElement(ident: 40, value: "Exmouth"),
//            IIElement(ident: 41, value: "Fitzroy Crossing"),
//            IIElement(ident: 17, value: "Geraldton"),
//            IIElement(ident: 21, value: "Greenough"),
//            IIElement(ident: 22, value: "Harvey"),
//            IIElement(ident: 42, value: "Jurien"),
//            IIElement(ident: 8, value: "Kalgoorlie"),
//            IIElement(ident: 43, value: "Kambalda"),
//            IIElement(ident: 9, value: "Karratha"),
//            IIElement(ident: 44, value: "Kellerberrin"),
//            IIElement(ident: 45, value: "Kojonup"),
//            IIElement(ident: 10, value: "Kununurra"),
//            IIElement(ident: 18, value: "Mandurah"),
//            IIElement(ident: 32, value: "Manjimup"),
//            IIElement(ident: 46, value: "Meekatharra"),
//            IIElement(ident: 47, value: "Moora"),
//            IIElement(ident: 48, value: "Mt Barker"),
//            IIElement(ident: 23, value: "Murray"),
//            IIElement(ident: 11, value: "Narrogin"),
//            IIElement(ident: 49, value: "Newman"),
//            IIElement(ident: 50, value: "Norseman"),
//            IIElement(ident: 12, value: "Northam"),
//            IIElement(ident: 13, value: "Port Hedland"),
//            IIElement(ident: 51, value: "Ravensthorpe"),
//            IIElement(ident: 14, value: "South Hedland"),
//            IIElement(ident: 53, value: "Tammin"),
//            IIElement(ident: 24, value: "Waroona"),
//            IIElement(ident: 54, value: "Williams"),
//            IIElement(ident: 55, value: "Wubin"),
//            IIElement(ident: 56, value: "York "),
//            IIElement(ident: 0, value: "Mullalyup")
//        ]
//    }
//
//    var updateLocationString: String {
//        if latitude != nil && longitude != nil && radius != nil {
//            return "Region.fetch(ident: \"\(ident)\", context: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: \(latitude!), longitude: \(longitude!)), radius: \(radius!), identifier: \"\(name)\")"
//        } else if latitude != nil && longitude != nil {
//            return "Region.fetch(ident: \"\(ident)\", context: context)?.location = CLLocation(latitude: \(latitude!), longitude: \(longitude!))"
//        } else {
//            return ""
//        }
//    }
//
//    func determineLocation(iterator: AnyIterator<Region>?, completion: @escaping (Error?)->Void) {
//        guard location == nil else {
//            if let region = iterator?.next() {
//                region.determineLocation(iterator: iterator, completion: completion)
//            } else {
//                completion(nil)
//            }
//            return
//        }
//
//        var address = [
//            kABAddressCountryKey as String: "Australia",
//            kABAddressStateKey as String: "Western Australia",
//            kABAddressCityKey as String: name as String]
//        os_log("Beginning geocode region %@", name)
//        Static.geocoder.geocodeAddressDictionary(address) { (placeMarks, error) -> Void in
//            defer {
//                if let region = iterator?.next() {
//                    region.determineLocation(iterator: iterator, completion: completion)
//                } else {
//                    completion(nil)
//                }
//            }
//
//            guard error == nil  else {
//                os_log("Error during geocoding for locations: %@", log: self.logger, type: .error, error!.localizedDescription)
//                return
//            }
//
//            if let placemark = (placeMarks)?.first {
//                if let r = placemark.region as? CLCircularRegion {
//                    self.geographicRegion = r
//                    do {
//                        try self.managedObjectContext!.save()
//                    } catch {
//                        os_log("Error during saving region locations: %@", log: self.logger, type: .error, error.localizedDescription)
//                    }
//                    os_log("Location update: %@", log: self.logger, type: .info, self.updateLocationString)
//                }
//            }
//        }
//    }
//
//    class func determineAllLocations(completion: @escaping (Error?)->Void) {
//        Static.mainQueue.enqueue(delay: 0, {
//            let iterator = AnySequence<Suburb>(Suburb.fetchAll(from: PersistentStore.instance.context)).makeIterator()
//            iterator.next()?.determineLocation(iterator: iterator, completion: completion)
//        })
//    }
//
//    class func updateStatic(to context: NSManagedObjectContext) {
//        objc_sync_enter(Static.lock)
//        for item in Static.sourceItems {
//            var region = fetch(withIdent: Int16(item.ident), from: context) ?? fetch(withName: item.value, from: context)
//            if region == nil {
//                region = create(in: context)
//                region!.name = item.value
//                region!.ident = Int16(item.ident)
//            }
//            if region!.name != item.value {
//                region!.name = item.value
//            }
//            if region!.ident != Int16(item.ident) {
//                region!.ident = Int16(item.ident)
//            }
//        }
//        do {
//            try context.save()
//        } catch {
//            do {
//                try context.save()
//            } catch {
//                os_log("Error on managed object save: %@", type: .error, error.localizedDescription)
//            }
//        }
//        objc_sync_exit(Static.lock)
//    }
}
