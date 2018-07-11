//
//  Station.swift
//  FuelLocator
//
//  Created by Owen Godfrey on 9/10/2014.
//  Copyright (c) 2014 Owen Godfrey. All rights reserved.
//

import Foundation
import MapKit
import CloudKit
import os.log

class Station: FLODataEntity, Hashable {
    typealias `Self` = Station
    var hashValue: Int { return tradingName.hashValue }

    static func == (lhs: Station, rhs: Station) -> Bool {
        return lhs.tradingName == rhs.tradingName
    }

    static let calendar = Calendar.current

    init(tradingName: String, brand: Brand, address: String?, latitude: Double, longitude: Double, phone: String?, stationDescription: String?, siteFeatures: Set<String>? = nil, suburb: Suburb? = nil) {
        self.tradingName = tradingName
        self.brand = brand
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.phone = phone
        self.stationDescription = stationDescription
        self.siteFeatures = siteFeatures == nil ? nil : Set<String>(siteFeatures!)
    }

    init(record: CKRecord) {
        tradingName = Station.tradingName(from: record.recordID)
        address = record["address"] as? String
        let location = record["location"] as? CLLocation
        latitude = location?.coordinate.latitude ?? 0
        longitude = location?.coordinate.longitude ?? 0
        phone = record["phone"] as? String
        stationDescription = record["stationDescription"] as? String
        brand = Brand.all[Brand.ident(from: (record["brand"] as! CKReference).recordID)]
        suburb = Suburb.all[Suburb.ident(from: (record["suburb"] as! CKReference).recordID)]
        if let earliest = record["earliest"] as? Date, let latest = record["latest"] as? Date {
            dateRange = earliest ... Self.calendar.date(byAdding: .day, value: 7, to: latest)!
        }
        systemFields = Brand.archiveSystemFields(from: record)
    }

    public var address: String?
    public var latitude: Double
    public var longitude: Double
    public var phone: String?
    public var stationDescription: String?
    public var tradingName: String
    public var brand: Brand?
    public var priceOnDay: Set<PriceOnDay>?
    public var product: Set<Product>?
    public var siteFeatures: Set<String>?
    public var suburb: Suburb?
    public var systemFields: Data?
    public var dateRange: ClosedRange<Date>?

    fileprivate let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "Station")

    var siteFeaturesList: String {
        return siteFeatures?.reduce("", { ($0 == "" ? $0 : $0 + ", ") + $1 }) ?? ""
    }

    var prices: [PriceOnDay] {
        return priceOnDay != nil ? Array<PriceOnDay>(priceOnDay!) : []
    }

    var products: [Product] {
        return product != nil ? Array<Product>(product!) : []
    }

    var coordinate: CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }

    func prices(_ product: Product, date: Date) -> PriceOnDay! {
        return prices.filter{$0.product == product && $0.date as Date == date}.first
    }

    static let lock = NSObject()

    public var description: String {
        return "Station \(tradingName)"
    }

    public var debugDescription: String {
        return "Station (\(tradingName), \(String(describing: brand)), \(String(describing: suburb)))"
    }
    
    class func fetch(withIdent tradingName: String, _ completionBlock: @escaping (Station?, Error?) -> Void) {
        let pred = NSPredicate(format: "tradingName == %@", tradingName)
        let query = CKQuery(recordType: "FWStation", predicate: pred)

        do {
            Station.download(fromDatabase: try FLOCloud.shared.publicDatabase(), withQuery: query) { (error, records) in
                let stat: Station? = (records == nil || records!.isEmpty ? nil : Station(record: records!.first!))
                completionBlock(stat, error)
            }
        } catch {
            print(error)
        }
    }

    class func fetchAll(_ completionBlock: @escaping (Set<Station>, Error?) -> Void) {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "FWStation", predicate: predicate)

        do {
            Station.download(fromDatabase: try FLOCloud.shared.publicDatabase(), withQuery: query) { (error, records) in
                let stats = Set<Station>(records?.map({ Station(record: $0) }) ?? [])
                completionBlock(stats, error)
            }
        } catch {
            print(error)
        }
    }

    static var all = FLODataEntityAll<String, Station>()

    var key: String {
        return tradingName
    }

    class func tradingName(from recordID: CKRecordID) -> String {
        let str = recordID.recordName
        let index = str.index(after: str.index(of: ":")!)
        return String(str[index...])
    }

    class func recordId(from tradingName: String) -> CKRecordID {
        return CKRecordID(recordName: "Station:" + tradingName)
    }

    var recordID: CKRecordID {
        return Station.recordId(from: tradingName)
    }

    func hasChanged(from record: CKRecord) -> Bool {
        if let ad = record["address"] as? String {
            if ad != address {
                return true
            }
        }
        if let br = record["brand"] as? CKReference {
            let brId = Brand.ident(from: br.recordID)
            if brId != brand?.ident {
                return true
            }
        }
        if let v = record["suburb"] as? CKReference {
            // Simply assert that this information won't change
            assert(suburb!.ident == Suburb.ident(from: v.recordID))
        }
        if let v = record["location"] as? CLLocation {
            if v.coordinate.latitude != latitude || v.coordinate.longitude != longitude {
                return true
            }
        }
        if let ph = record["phone"] as? String {
            if ph != phone {
                return true
            }
        }
        if let des = record["stationDescription"] as? String {
            if des != stationDescription {
                return true
            }
        }
        if let features = record["features"] as? Array<String> {
            for f in features {
                if !(siteFeatures?.contains(where: { $0 == f }) ?? false) {
                    return true
                }
            }
            if let sfs = siteFeatures {
                for sf in Array(sfs) {
                    if !features.contains(where: { $0 == sf }) {
                        return true
                    }
                }
            }
        }
        return false
    }

    var record: CKRecord {
        get {
            let r: CKRecord
            if systemFields == nil {
                r = CKRecord(recordType: "FWStation", recordID: Station.recordId(from: tradingName))
            } else {
                let unarchiver = NSKeyedUnarchiver(forReadingWith: systemFields!)
                unarchiver.requiresSecureCoding = true
                r = CKRecord(coder: unarchiver)!
            }
            if address != nil {
                r["address"] = address! as NSString
            }
            if brand != nil {
                r["brand"] = CKReference.init(record: brand!.record, action: CKReferenceAction.none)
            }
            if siteFeatures != nil {
                r["features"] = Array<String>(siteFeatures!.map({$0})) as NSArray
            }
            r["location"] = CLLocation(latitude: latitude, longitude: longitude)
            if phone != nil {
                r["phone"] = phone! as NSString
            }
            if stationDescription != nil {
                r["stationDescription"] = stationDescription! as NSString
            }
            if suburb != nil {
                r["suburb"] = CKReference.init(record: suburb!.record, action: CKReferenceAction.none)
            }
            return r
        }
        set {
            systemFields = Station.archiveSystemFields(from: newValue)
            tradingName = Station.tradingName(from: newValue.recordID)
            if let ad = newValue["address"] as? String {
                if ad != address {
                    address = ad
                }
            }
            if let br = newValue["brand"] as? CKReference {
                let brId = Brand.ident(from: br.recordID)
                if brId != brand?.ident {
                    let dg = DispatchGroup()
                    dg.enter()
                    Brand.fetch(withIdent: brId, { (br1, error) in
                        self.brand = br1
                        dg.leave()
                    })
                    _ = dg.wait(timeout: DispatchTime.now() + .seconds(4))
                }
            }
            if let v = newValue["suburb"] as? CKReference {
                // Simply assert that this information won't change
                assert(suburb!.ident == Suburb.ident(from: v.recordID))
            }
            if let v = newValue["location"] as? CLLocation {
                if v.coordinate.latitude != latitude || v.coordinate.longitude != longitude {
                    latitude = v.coordinate.latitude
                    longitude = v.coordinate.longitude
                }
            }
            if let ph = newValue["phone"] as? String {
                if ph != phone {
                    phone = ph
                }
            }
            if let des = newValue["stationDescription"] as? String {
                if des != stationDescription {
                    stationDescription = des
                }
            }
            if let features = newValue["features"] as? Array<String> {
                siteFeatures?.removeAll()
                siteFeatures?.formUnion(features)
            }
        }
    }
}

extension Station {
//    class func update(item: FuelWatchItem, product: Product?, region: Region?, suburb: Suburb?, context: NSManagedObjectContext) throws {
//        let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "Station.update")
//
//        guard !item.tradingName.isEmpty else {
//            throw FLOError.stationUpdateBlankName
//        }
//
//        /**
//         * Have encountered a station that has no location, address, phone, latitude or longitude data.
//         * It has a price, date, tradingName, brand and a description that includes only address and phone number
//         * "Trader 5", "Caltex", 76.9, "Address: Cnr Beach Rd & Crocker Dr, MALAGA, Phone: (08) 9249 3200"
//         * It is possible to parse out the details.
//         */
//
//        objc_sync_enter(Static.lock)
//        var station = fetch(withTradingName: item.tradingName, from: context)
//        var brand = (item.brand != nil ? Brand.fetch(withName: item.brand!, from: context) : nil)
//        let date = item.date
//        let price: Int16? = item.price
//        var suburbObj = (item.location != nil ? Suburb.fetch(withName: item.location!.capitalized, from: context) : nil)
//        if brand == nil && item.brand != nil {
//            brand = Brand.create(in: context)
//            brand!.name = item.brand!
//        }
//        if suburbObj == nil {
//            if item.location != nil {
//
//                /// The problem here is that we lack vital information
//                /// about the suburb that has just been created, such as
//                /// its location and neighbouring suburbs. We can infer the region,
//                /// but we can't be sure if it doesn't occur in other regions.
//                /// Basically, we don't want to learn about suburbs this way.
//                suburbObj = Suburb.create(in: context)
//                suburbObj!.name = item.location!.capitalized
//                suburbObj!.ident = Suburb.identify(item.location!)
//
//                /// Schedule suburb for upload to cloudKit
//
//            } else if item.stationDescription != nil {
//
//                let regex = try! NSRegularExpression(pattern: "(\\bAddress\\b|\\bPhone\\b):\\s+(.+)(?=,\\s*\\b\\S+\\b:\\s+|$)", options: NSRegularExpression.Options.caseInsensitive)
//                let nstr = item.stationDescription! as NSString
//                let allRange = NSMakeRange(0, nstr.length)
//                regex.enumerateMatches(in: item.stationDescription!, range: allRange) { (result, flags, stop) in
//                    if result != nil {
////                        let element = nstr.substring(with: result!.range)
//                        let keyword = nstr.substring(with: result!.range(at: 1))
//                        let value = nstr.substring(with: result!.range(at: 2))
//                        print("Key is '\(keyword)', value is '\(value)'")
//                        os_log("Station Description: Key is %@, Value is %@", log: logger, type: .debug, keyword, value)
//                    }
//                }
//
//            } else {
//                print()
//                return
//            }
//        }
//        if station == nil {
//            guard brand != nil && item.tradingName != "" && suburbObj != nil else {
//                let brandName = brand?.name ?? "No Brand"
//                let suburbName = suburbObj?.name ?? "No Suburb"
//                throw FLOError.stationNotEnoughDataToCreate(item.tradingName, brandName, suburbName)
//            }
//            station = create(in: context)
//            station!.tradingName = item.tradingName
//            station!.brand = brand
//            station!.stationDescription = item.stationDescription
//            station!.suburb = suburb ?? suburbObj
//            station!.address = item.address
//            station!.phone = item.phone
//            station!.latitude = item.latitude ?? 0
//            station!.longitude = item.longitude ?? 0
//            station!.priceOnDay = Set<PriceOnDay>()
//            station!.product = Set<Product>()
//            station!.siteFeatures = Set<SiteFeatures>()
//
//        }
//        if station!.suburb != suburbObj {
//            station!.suburb = suburbObj
//        }
//        if suburb != nil && suburbObj != nil && suburb != suburbObj {
//            if !(suburbObj!.surround?.contains(suburb!) ?? false) {
//                suburbObj!.addToSurround(suburb!)
////                suburbObj!.mutableSetValue(forKey: "surround").add(suburb!)
//            }
//        }
//
//        if station!.brand != brand {
//            station!.brand = brand
//        }
//        if suburbObj != nil && region != nil {
//            if !(suburbObj!.region?.contains(region!) ?? false) {
//                suburbObj!.addToRegion(region!)
////                suburbObj!.mutableSetValue(forKey: "region").add(region!)
//            }
//        }
//
//        /// If suburb has changed, set it to upload to cloud
//
//        if item.stationDescription != nil && (station!.stationDescription == nil || station!.stationDescription != item.stationDescription!) {
//            station!.stationDescription = item.stationDescription!
//        }
//        if item.address != nil && (station!.address == nil || station!.address! != item.address!) {
//            station!.address = item.address!
//        }
//        if item.phone != nil && (station!.phone == nil || station!.phone! != item.phone!) {
//            station!.phone = item.phone!
//        }
//        if item.latitude != nil && (station!.latitude != item.latitude!) {
//            station!.latitude = item.latitude!
//        }
//        if item.longitude != nil && (station!.longitude != item.longitude!) {
//            station!.longitude = item.longitude!
//        }
//        if item.stationDescription != nil && (station!.stationDescription == nil || station!.stationDescription! != item.stationDescription!) {
//            station!.stationDescription = item.stationDescription!
//        }
//        SiteFeatures.update(from: item.siteFeatures, with: station!, to: context)
//        if date != nil && price != nil && product != nil {
//            PriceOnDay.update(price: price!, day: date!, product: product!, station: station!, to: context)
//        }
//
//        /// if price on day and/or station are modified, upload to cloud
//        
//        if item.latitude != nil && item.longitude != nil && item.latitude! != 0.0 && item.longitude! != 0.0 && (station!.latitude != item.latitude! && station!.longitude != item.longitude!) {
//            station!.latitude = item.latitude!
//            station!.longitude = item.longitude!
//        }
//        if station!.latitude == 0 && station!.longitude == 0 {
//            if station?.suburb?.ident == "ROTTNEST+ISLAND" {
//                // Patch for missing coordinate data
//                station!.latitude = -31.9965944444
//                station!.longitude = 115.5425916667
//            } else if station?.suburb?.ident == "ALBANY" && station?.address == "634 Menang Dr" {
//                station?.latitude = -34.96054200
//                station?.longitude = 117.85654800
//            } else if item.address != nil && item.location != nil {
//                print("Station \(String(describing: station?.tradingName)) has no coordinate")
//                print("  Address is \(String(describing: station?.address)), location \(String(describing: station?.suburb?.name))")
//                let geocoder = CLGeocoder()
//                let tName = station!.tradingName
//                geocoder.geocodeAddressString(item.address! + ", " + item.location!.capitalized + ", Western Australia") { (placeMarks: [CLPlacemark]!, error: Error!) in
//                    guard error == nil else {
//                        os_log("Geocoding error: %@", log: logger, type: .error, error!.localizedDescription)
//                        return
//                    }
//                    if let placeMark: CLPlacemark = placeMarks.first {
//                        let managedObjectContext = PersistentStore.instance.context
//                        let st = Station.fetch(withTradingName: tName, from: managedObjectContext)
//                        st!.latitude = (placeMark.location?.coordinate.latitude)!
//                        st!.longitude = (placeMark.location?.coordinate.longitude)!
//                        do {
//                            try managedObjectContext.save()
//                        } catch {
//                            os_log("Save error after gecoding: %@", log: logger, type: .error, error.localizedDescription)
//                        }
//                    }
//                }
//            }
//        }
//        do {
//            try context.save()
//        } catch {
//            throw FLOError.stationUpdateSaveError(error)
//        }
//        objc_sync_exit(Static.lock)
//    }
}
