//
//  Suburb.swift
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

class Suburb: FLODataEntity, Hashable {
    var hashValue: Int { return ident.hashValue }

    static func == (lhs: Suburb, rhs: Suburb) -> Bool {
        return lhs.ident == rhs.ident
    }


    init(ident: String, name: String, latitude: Double? = nil, longitude: Double? = nil, radius: Double? = nil) {
        self.ident = ident
        self.name = name
        self.latitude = latitude as NSNumber?
        self.longitude = longitude as NSNumber?
        self.radius = radius as NSNumber?
    }

    init(record: CKRecord) {
        ident = Suburb.ident(from: record.recordID)
        name = record["name"] as! String
        latitude = record["latitude"] as? NSNumber ?? 0
        longitude = record["longitude"] as? NSNumber ?? 0
        radius = record["radius"] as? NSNumber ?? 0
        if let ref = record["regions"] as? Array<CKReference> {
            region = Set<Region>(ref.map({Region.all[Region.ident(from: $0.recordID)]!}))
        } else if let ref = record["region"] as? CKReference {
            region = Set<Region>(arrayLiteral: Region.all[Region.ident(from: ref.recordID)]!)
        }
        if let fts = record["features"] as? NSArray {
            for f in fts {
                if let feature = f as? String {
                    features.append(feature)
                }
            }
        }
        if let ref = record["surround"] as? Array<CKReference> {
            let subs = ref.map({Suburb.all[Suburb.ident(from: $0.recordID)]})
            surround = Set<Suburb>(subs.filter({$0 != nil}).map({$0!}))
            if subs.count != ref.count {
                DispatchQueue.main.async {
                    let subs = ref.map({Suburb.all[Suburb.ident(from: $0.recordID)]})
                    self.surround = Set<Suburb>(subs.filter({$0 != nil}).map({$0!}))
                }
            }
        }
        systemFields = Brand.archiveSystemFields(from: record)
    }

    public var ident: String
    public var latitude: NSNumber?
    public var longitude: NSNumber?
    public var name: String
    public var radius: NSNumber?
    public var features: [String] = []
    public var region: Set<Region>?
    public var station: Set<Station>?
    public var surround: Set<Suburb>?
    public var systemFields: Data?

    var location: CLLocation! {
        get {
            guard latitude != nil && longitude != nil else {
                return nil
            }
            return CLLocation(latitude: latitude!.doubleValue, longitude: longitude!.doubleValue)
        }
        set {
            latitude = newValue?.coordinate.latitude as NSNumber?
            latitude = newValue?.coordinate.latitude as NSNumber?
        }
    }

    var geographicRegion: CLCircularRegion! {
        get {
            guard latitude != nil && longitude != nil && radius != nil else {
                return nil
            }
            let loc = CLLocationCoordinate2D(latitude: latitude!.doubleValue, longitude: longitude!.doubleValue)
            return CLCircularRegion(center: loc, radius: radius!.doubleValue, identifier: name)
        }
        set {
            latitude = newValue?.center.latitude as NSNumber?
            longitude = newValue?.center.longitude as NSNumber?
            radius = newValue?.radius as NSNumber?
        }
    }

    static let lock = NSObject()
    static let geocoder = CLGeocoder()

    public var description: String {
        return "Suburb \(name)"
    }

    public var debugDescription: String {
        return "Suburb (\(ident), \(name))"
    }
    
    let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "Suburb")

    class func fetch(withIdent ident: String, _ completionBlock: @escaping (Suburb?, Error?) -> Void) {
        let pred = NSPredicate(format: "ident == %@", ident)
        let query = CKQuery(recordType: "FWSuburb", predicate: pred)

        do {
            Suburb.download(fromDatabase: try FLOCloud.shared.publicDatabase(), withQuery: query) { (error, records) in
                let sub: Suburb? = (records == nil || records!.isEmpty ? nil : Suburb(record: records!.first!))
                completionBlock(sub, error)
            }
        } catch {
            print(error)
        }
    }

    class func fetchAll(_ completionBlock: @escaping (Set<Suburb>, Error?) -> Void) {
        let pred = NSPredicate(value: true)
        let query = CKQuery(recordType: "FWSuburb", predicate: pred)

        do {
            Suburb.download(fromDatabase: try FLOCloud.shared.publicDatabase(), withQuery: query) { (error, records) in
                let subs = Set<Suburb>(records?.map({ Suburb(record: $0) }) ?? [])
                completionBlock(subs, error)
            }
        } catch {
            print(error)
        }
    }

    static var all = FLODataEntityAll<String, Suburb>()

    var key: String {
        return ident
    }

    class func ident(from recordID: CKRecordID) -> String {
        let str = recordID.recordName
        let index = str.index(after: str.index(of: ":")!)
        return String(str[index...])
    }

    class func recordId(from ident: String) -> CKRecordID {
        return CKRecordID(recordName: "Suburb:" + ident)
    }

    var recordID: CKRecordID {
        return Suburb.recordId(from: ident)
    }

    func hasChanged(from record: CKRecord) -> Bool {
        if let n = record["name"] as? String {
            if n != name {
                return true
            }
        }
        return false
    }

    var record: CKRecord {
        get {
            let r: CKRecord
            if systemFields == nil {
                r = CKRecord(recordType: "FWSuburb", recordID: recordID)
            } else {
                let unarchiver = NSKeyedUnarchiver(forReadingWith: systemFields!)
                unarchiver.requiresSecureCoding = true
                r = CKRecord(coder: unarchiver)!
            }
            r["name"] = name as CKRecordValue
            return r
        }
        set {
            systemFields = Suburb.archiveSystemFields(from: newValue)
            ident = Suburb.ident(from: newValue.recordID)
            if let n = newValue["name"] as? String {
                if n != name {
                    name = n
                }
            }
        }
    }
}

extension Suburb {
//    class func update(from sourceItems: [SIElement]?, withRegion region: Region?, to context: NSManagedObjectContext) {
//        objc_sync_enter(Static.lock)
//        if sourceItems != nil {
//            for item in sourceItems! {
//                var suburb = fetch(withIdent: item.ident, from: context) ?? fetch(withName: item.value, from: context)
//                if suburb != nil {
//                    let name = item.value.capitalized
//                    if suburb!.name != name {
//                        suburb!.name = name
//                    }
//                    let ident = Suburb.identify(item.ident)
//                    if suburb!.ident != ident {
//                        suburb!.ident = ident
//                    }
//                } else {
//                    suburb = create(in: context)
//                    suburb!.name = item.value.capitalized
//                    suburb!.ident = Suburb.identify(item.ident)
//                }
//                if region != nil {
//                    if !(suburb!.region?.contains(region!) ?? false) {
//                        suburb!.mutableSetValue(forKey: "region").add(region!)
//                    }
//                }
//            }
//        }
//        objc_sync_exit(Static.lock)
//    }
//
//    class func update(from sourceItems: [SIElement]?, withRegions regions: [Region], to context: NSManagedObjectContext) {
//        objc_sync_enter(Static.lock)
//        if sourceItems != nil {
//            for item in sourceItems! {
//                var suburb = fetch(withIdent: item.ident, from: context) ?? fetch(withName: item.value, from: context)
//                if suburb != nil {
//                    let name = item.value.capitalized
//                    if suburb!.name != name {
//                        suburb!.name = name
//                    }
//                    let ident = Suburb.identify(item.ident)
//                    if suburb!.ident != ident {
//                        suburb!.ident = ident
//                    }
//                } else {
//                    suburb = create(in: context)
//                    suburb!.name = item.value.capitalized
//                    suburb!.ident = Suburb.identify(item.ident)
//                }
//                for region in regions {
//                    if !(suburb!.region?.contains(region) ?? false) {
//                        suburb!.mutableSetValue(forKey: "region").add(region)
//                    }
//                }
//            }
//        }
//        do {
//            try context.save()
//        } catch  {
//            print("Error during update of Suburb")
//        }
//        objc_sync_exit(Static.lock)
//    }
//
//    class func updateStatic(to context: NSManagedObjectContext) {
//        Suburb.update(from: [SIElement(ident: "ALBANY", value: "Albany")], withRegions: [Region.fetch(withIdent: 15, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "ALEXANDER+HEIGHTS", value: "Alexander Heights")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "ALFRED+COVE", value: "Alfred Cove")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "APPLECROSS", value: "Applecross")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "ARMADALE", value: "Armadale")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "ASCOT", value: "Ascot")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "ASHBY", value: "Ashby")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "ATTADALE", value: "Attadale")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "AUGUSTA", value: "Augusta")], withRegions: [Region.fetch(withIdent: 28, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "AUSTRALIND", value: "Australind")], withRegions: [Region.fetch(withIdent: 22, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BALCATTA", value: "Balcatta")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BALDIVIS", value: "Baldivis")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BALGA", value: "Balga")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BALINGUP", value: "Balingup")], withRegions: [Region.fetch(withIdent: 31, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BALLAJURA", value: "Ballajura")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BARRAGUP", value: "Barragup")], withRegions: [Region.fetch(withIdent: 23, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BASKERVILLE", value: "Baskerville")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BASSENDEAN", value: "Bassendean")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BAYSWATER", value: "Bayswater")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BECKENHAM", value: "Beckenham")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BEDFORDALE", value: "Bedfordale")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BEECHBORO", value: "Beechboro")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BEELIAR", value: "Beeliar")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BELDON", value: "Beldon")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BELLEVUE", value: "Bellevue")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BELMONT", value: "Belmont")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BENTLEY", value: "Bentley")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BERTRAM", value: "Bertram")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BIBRA+LAKE", value: "Bibra Lake")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BICTON", value: "Bicton")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BINNINGUP", value: "Binningup")], withRegions: [Region.fetch(withIdent: 22, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BOULDER", value: "Boulder")], withRegions: [Region.fetch(withIdent: 1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BRENTWOOD", value: "Brentwood")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BRIDGETOWN", value: "Bridgetown")], withRegions: [Region.fetch(withIdent: 30, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BROOME", value: "Broome")], withRegions: [Region.fetch(withIdent: 2, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BRUNSWICK+JUNCTION", value: "Brunswick Junction")], withRegions: [Region.fetch(withIdent: 22, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BULL+CREEK", value: "Bull Creek")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BULLSBROOK", value: "Bullsbrook")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BUNBURY", value: "Bunbury")], withRegions: [Region.fetch(withIdent: 16, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BURSWOOD", value: "Burswood")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BUSSELTON", value: "Busselton")], withRegions: [Region.fetch(withIdent: 3, from: context)!, Region.fetch(withIdent: 29, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BUTLER", value: "Butler")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "BYFORD", value: "Byford")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "CANNING+VALE", value: "Canning Vale")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "CANNINGTON", value: "Cannington")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "CAPEL", value: "Capel")], withRegions: [Region.fetch(withIdent: 19, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "CARBUNUP+RIVER", value: "Carbunup River")], withRegions: [Region.fetch(withIdent: 29, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "CARINE", value: "Carine")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "CARLISLE", value: "Carlisle")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "CARNARVON", value: "Carnarvon")], withRegions: [Region.fetch(withIdent: 4, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "CATABY", value: "Cataby")], withRegions: [Region.fetch(withIdent: 33, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "CAVERSHAM", value: "Caversham")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "CHIDLOW", value: "Chidlow")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "CLAREMONT", value: "Claremont")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "CLARKSON", value: "Clarkson")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "CLOVERDALE", value: "Cloverdale")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "COCKBURN+CENTRAL", value: "Cockburn Central")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "COLLIE", value: "Collie")], withRegions: [Region.fetch(withIdent: 5, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "COMO", value: "Como")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "COOLGARDIE", value: "Coolgardie")], withRegions: [Region.fetch(withIdent: 34, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "COOLUP", value: "Coolup")], withRegions: [Region.fetch(withIdent: 23, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "COTTESLOE", value: "Cottesloe")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "COWARAMUP", value: "Cowaramup")], withRegions: [Region.fetch(withIdent: 28, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "CUNDERDIN", value: "Cunderdin")], withRegions: [Region.fetch(withIdent: 35, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "CURRAMBINE", value: "Currambine")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "DALWALLINU", value: "Dalwallinu")], withRegions: [Region.fetch(withIdent: 36, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "DAMPIER", value: "Dampier")], withRegions: [Region.fetch(withIdent: 6, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "DARDANUP", value: "Dardanup")], withRegions: [Region.fetch(withIdent: 20, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "DENMARK", value: "Denmark")], withRegions: [Region.fetch(withIdent: 37, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "DERBY", value: "Derby")], withRegions: [Region.fetch(withIdent: 38, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "DIANELLA", value: "Dianella")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "DONGARA", value: "Dongara")], withRegions: [Region.fetch(withIdent: 39, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "DONNYBROOK", value: "Donnybrook")], withRegions: [Region.fetch(withIdent: 31, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "DOUBLEVIEW", value: "Doubleview")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "DUNCRAIG", value: "Duncraig")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "DUNSBOROUGH", value: "Dunsborough")], withRegions: [Region.fetch(withIdent: 29, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "DWELLINGUP", value: "Dwellingup")], withRegions: [Region.fetch(withIdent: 23, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "EAST+FREMANTLE", value: "East Fremantle")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "EAST+PERTH", value: "East Perth")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "EAST+VICTORIA+PARK", value: "East Victoria Park")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "EATON", value: "Eaton")], withRegions: [Region.fetch(withIdent: 20, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "EDGEWATER", value: "Edgewater")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "ELLENBROOK", value: "Ellenbrook")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "ERSKINE", value: "Erskine")], withRegions: [Region.fetch(withIdent: 18, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "ESPERANCE", value: "Esperance")], withRegions: [Region.fetch(withIdent: 7, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "EXMOUTH", value: "Exmouth")], withRegions: [Region.fetch(withIdent: 40, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "FALCON", value: "Falcon")], withRegions: [Region.fetch(withIdent: 18, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "FITZROY+CROSSING", value: "Fitzroy Crossing")], withRegions: [Region.fetch(withIdent: 41, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "FLOREAT", value: "Floreat")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "FORRESTDALE", value: "Forrestdale")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "FORRESTFIELD", value: "Forrestfield")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "FREMANTLE", value: "Fremantle")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "GELORUP", value: "Gelorup")], withRegions: [Region.fetch(withIdent: 19, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "GERALDTON", value: "Geraldton")], withRegions: [Region.fetch(withIdent: 17, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "GIDGEGANNUP", value: "Gidgegannup")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "GIRRAWHEEN", value: "Girrawheen")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "GLEN+FORREST", value: "Glen Forrest")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "GLENDALOUGH", value: "Glendalough")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "GLENFIELD", value: "Glenfield")], withRegions: [Region.fetch(withIdent: 21, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "GNANGARA", value: "Gnangara")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "GOLDEN+BAY", value: "Golden Bay")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "GOSNELLS", value: "Gosnells")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "GRACETOWN", value: "Gracetown")], withRegions: [Region.fetch(withIdent: 28, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "GREENBUSHES", value: "Greenbushes")], withRegions: [Region.fetch(withIdent: 30, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "GREENOUGH", value: "Greenough")], withRegions: [Region.fetch(withIdent: 21, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "GREENWOOD", value: "Greenwood")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "GUILDFORD", value: "Guildford")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "GWELUP", value: "Gwelup")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "HALLS+HEAD", value: "Halls Head")], withRegions: [Region.fetch(withIdent: 18, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "HAMILTON+HILL", value: "Hamilton Hill")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "HARVEY", value: "Harvey")], withRegions: [Region.fetch(withIdent: 22, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "HENLEY+BROOK", value: "Henley Brook")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "HERNE+HILL", value: "Herne Hill")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "HIGH+WYCOMBE", value: "High Wycombe")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "HIGHGATE", value: "Highgate")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "HILLARYS", value: "Hillarys")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "HUNTINGDALE", value: "Huntingdale")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "INNALOO", value: "Innaloo")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "JANDAKOT", value: "Jandakot")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "JOLIMONT", value: "Jolimont")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "JOONDALUP", value: "Joondalup")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "JURIEN+BAY", value: "Jurien Bay")], withRegions: [Region.fetch(withIdent: 42, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "KALAMUNDA", value: "Kalamunda")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "KALGOORLIE", value: "Kalgoorlie")], withRegions: [Region.fetch(withIdent: 8, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "KAMBALDA", value: "Kambalda")], withRegions: [Region.fetch(withIdent: 43, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "KAMBALDA+WEST", value: "Kambalda West")], withRegions: [Region.fetch(withIdent: 43, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "KARAWARA", value: "Karawara")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "KARDINYA", value: "Kardinya")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "KARRAGULLEN", value: "Karragullen")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "KARRATHA", value: "Karratha")], withRegions: [Region.fetch(withIdent: 9, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "KARRIDALE", value: "Karridale")], withRegions: [Region.fetch(withIdent: 28, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "KARRINYUP", value: "Karrinyup")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "KELLERBERRIN", value: "Kellerberrin")], withRegions: [Region.fetch(withIdent: 44, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "KELMSCOTT", value: "Kelmscott")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "KEWDALE", value: "Kewdale")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "KIARA", value: "Kiara")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "KINGSLEY", value: "Kingsley")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "KIRUP", value: "Kirup")], withRegions: [Region.fetch(withIdent: 31, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "KOJONUP", value: "Kojonup")], withRegions: [Region.fetch(withIdent: 45, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "KOONDOOLA", value: "Koondoola")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "KUNUNURRA", value: "Kununurra")], withRegions: [Region.fetch(withIdent: 10, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "KWINANA", value: "Kwinana")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "LAKELANDS", value: "Lakelands")], withRegions: [Region.fetch(withIdent: 18, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "LANGFORD", value: "Langford")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "LEDA", value: "Leda")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "LEEDERVILLE", value: "Leederville")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "LEEMING", value: "Leeming")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "LESMURDIE", value: "Lesmurdie")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "LEXIA", value: "Lexia")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "LYNWOOD", value: "Lynwood")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MADDINGTON", value: "Maddington")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MADELEY", value: "Madeley")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MAIDA+VALE", value: "Maida Vale")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MALAGA", value: "Malaga")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MANDURAH", value: "Mandurah")], withRegions: [Region.fetch(withIdent: 18, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MANJIMUP", value: "Manjimup")], withRegions: [Region.fetch(withIdent: 32, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MANNING", value: "Manning")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MANYPEAKS", value: "Manypeaks")], withRegions: [Region.fetch(withIdent: 15, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MARGARET+RIVER", value: "Margaret River")], withRegions: [Region.fetch(withIdent: 28, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MEADOW+SPRINGS", value: "Meadow Springs")], withRegions: [Region.fetch(withIdent: 18, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MEEKATHARRA", value: "Meekatharra")], withRegions: [Region.fetch(withIdent: 46, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MERRIWA", value: "Merriwa")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MIDDLE+SWAN", value: "Middle Swan")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MIDVALE", value: "Midvale")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MINDARIE", value: "Mindarie")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MIRRABOOKA", value: "Mirrabooka")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MOONYOONOOKA", value: "Moonyoonooka")], withRegions: [Region.fetch(withIdent: 21, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MOORA", value: "Moora")], withRegions: [Region.fetch(withIdent: 47, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MORLEY", value: "Morley")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MOSMAN+PARK", value: "Mosman Park")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MOUNT+BARKER", value: "Mount Barker")], withRegions: [Region.fetch(withIdent: 48, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MT+LAWLEY", value: "Mt Lawley")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MT+PLEASANT", value: "Mt Pleasant")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MULLALOO", value: "Mullaloo")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MULLALYUP", value: "Mullalyup")], withRegions: [Region.fetch(withName: "Mullalyup", from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MUNDARING", value: "Mundaring")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MUNDIJONG", value: "Mundijong")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MUNSTER", value: "Munster")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MURDOCH", value: "Murdoch")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MYALUP", value: "Myalup")], withRegions: [Region.fetch(withIdent: 22, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "MYAREE", value: "Myaree")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "NARROGIN", value: "Narrogin")], withRegions: [Region.fetch(withIdent: 11, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "NAVAL+BASE", value: "Naval Base")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "NEDLANDS", value: "Nedlands")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "NEERABUP", value: "Neerabup")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "NEWMAN", value: "Newman")], withRegions: [Region.fetch(withIdent: 49, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "NOLLAMARA", value: "Nollamara")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "NORANDA", value: "Noranda")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "NORSEMAN", value: "Norseman")], withRegions: [Region.fetch(withIdent: 50, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "NORTH+DANDALUP", value: "North Dandalup")], withRegions: [Region.fetch(withIdent: 23, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "NORTH+FREMANTLE", value: "North Fremantle")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "NORTH+PERTH", value: "North Perth")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "NORTH+YUNDERUP", value: "North Yunderup")], withRegions: [Region.fetch(withIdent: 23, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "NORTHAM", value: "Northam")], withRegions: [Region.fetch(withIdent: 12, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "NORTHBRIDGE", value: "Northbridge")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "NORTHCLIFFE", value: "Northcliffe")], withRegions: [Region.fetch(withIdent: 32, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "NOWERGUP", value: "Nowergup")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "O'CONNOR", value: "O'connor")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "OCEAN+REEF", value: "Ocean Reef")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "OSBORNE+PARK", value: "Osborne Park")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "PADBURY", value: "Padbury")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "PALMYRA", value: "Palmyra")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "PARMELIA", value: "Parmelia")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "PEARSALL", value: "Pearsall")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "PEMBERTON", value: "Pemberton")], withRegions: [Region.fetch(withIdent: 32, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "PERTH", value: "Perth")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "PICTON", value: "Picton")], withRegions: [Region.fetch(withIdent: 16, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "PINJARRA", value: "Pinjarra")], withRegions: [Region.fetch(withIdent: 23, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "PORT+HEDLAND", value: "Port Hedland")], withRegions: [Region.fetch(withIdent: 13, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "PORT+KENNEDY", value: "Port Kennedy")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "PRESTON+BEACH", value: "Preston Beach")], withRegions: [Region.fetch(withIdent: 24, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "QUINNS+ROCKS", value: "Quinns Rocks")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "RAVENSTHORPE", value: "Ravensthorpe")], withRegions: [Region.fetch(withIdent: 51, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "REDCLIFFE", value: "Redcliffe")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "REDMOND", value: "Redmond")], withRegions: [Region.fetch(withIdent: 15, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "RIDGEWOOD", value: "Ridgewood")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "RIVERTON", value: "Riverton")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "RIVERVALE", value: "Rivervale")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "ROCKINGHAM", value: "Rockingham")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "ROLEYSTONE", value: "Roleystone")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "ROSA+BROOK", value: "Rosa Brook")], withRegions: [Region.fetch(withIdent: 28, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "ROTTNEST+ISLAND", value: "Rottnest Island")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "SAWYERS+VALLEY", value: "Sawyers Valley")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "SCARBOROUGH", value: "Scarborough")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "SECRET+HARBOUR", value: "Secret Harbour")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "SERPENTINE", value: "Serpentine")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "SEVILLE+GROVE", value: "Seville Grove")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "SINGLETON", value: "Singleton")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "SORRENTO", value: "Sorrento")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "SOUTH+FREMANTLE", value: "South Fremantle")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "SOUTH+HEDLAND", value: "South Hedland")], withRegions: [Region.fetch(withIdent: 14, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "SOUTH+LAKE", value: "South Lake")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "SOUTH+PERTH", value: "South Perth")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "SOUTH+YUNDERUP", value: "South Yunderup")], withRegions: [Region.fetch(withIdent: 23, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "SOUTHERN+RIVER", value: "Southern River")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "SPEARWOOD", value: "Spearwood")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "STRATHAM+DOWNS", value: "Stratham Downs")], withRegions: [Region.fetch(withIdent: 19, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "STRATTON", value: "Stratton")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "SUBIACO", value: "Subiaco")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "SUCCESS", value: "Success")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "SWAN+VIEW", value: "Swan View")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "SWANBOURNE", value: "Swanbourne")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "TAMMIN", value: "Tammin")], withRegions: [Region.fetch(withIdent: 53, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "THE+LAKES", value: "The Lakes")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "THORNLIE", value: "Thornlie")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "TUART+HILL", value: "Tuart Hill")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "UPPER+SWAN", value: "Upper Swan")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "VASSE", value: "Vasse")], withRegions: [Region.fetch(withIdent: 29, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "VICTORIA+PARK", value: "Victoria Park")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WAIKIKI", value: "Waikiki")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WALKAWAY", value: "Walkaway")], withRegions: [Region.fetch(withIdent: 21, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WALPOLE", value: "Walpole")], withRegions: [Region.fetch(withIdent: 32, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WANGARA", value: "Wangara")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WANNEROO", value: "Wanneroo")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WARNBRO", value: "Warnbro")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WAROONA", value: "Waroona")], withRegions: [Region.fetch(withIdent: 24, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WARWICK", value: "Warwick")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WATERLOO", value: "Waterloo")], withRegions: [Region.fetch(withIdent: 20, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WATTLE+GROVE", value: "Wattle Grove")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WEDGEFIELD", value: "Wedgefield")], withRegions: [Region.fetch(withIdent: 14, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WELLSTEAD", value: "Wellstead")], withRegions: [Region.fetch(withIdent: 15, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WELSHPOOL", value: "Welshpool")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WEMBLEY", value: "Wembley")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WEST+PERTH", value: "West Perth")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WEST+SWAN", value: "West Swan")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WESTMINSTER", value: "Westminster")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WILLETTON", value: "Willetton")], withRegions: [Region.fetch(withIdent: 26, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WILLIAMS", value: "Williams")], withRegions: [Region.fetch(withIdent: 54, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WITCHCLIFFE", value: "Witchcliffe")], withRegions: [Region.fetch(withIdent: 28, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WOKALUP", value: "Wokalup")], withRegions: [Region.fetch(withIdent: 22, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WOODVALE", value: "Woodvale")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WOOROLOO", value: "Wooroloo")], withRegions: [Region.fetch(withIdent: 27, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "WUBIN", value: "Wubin")], withRegions: [Region.fetch(withIdent: 55, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "YANCHEP", value: "Yanchep")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "YOKINE", value: "Yokine")], withRegions: [Region.fetch(withIdent: 25, from: context)!, Region.fetch(withIdent: -1, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "YORK", value: "York")], withRegions: [Region.fetch(withIdent: 56, from: context)!], to: context)
//        Suburb.update(from: [SIElement(ident: "YOUNG+SIDING", value: "Young Siding")], withRegions: [Region.fetch(withIdent: 15, from: context)!], to: context)
//
//        Suburb.fetch(withIdent: "ALBANY", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "ALEXANDER+HEIGHTS", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BALLAJURA", from: context)!,
//            Suburb.fetch(withIdent: "KOONDOOLA", from: context)!,
//            Suburb.fetch(withIdent: "GIRRAWHEEN", from: context)!])
//        Suburb.fetch(withIdent: "ALFRED+COVE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "APPLECROSS", from: context)!,
//            Suburb.fetch(withIdent: "MYAREE", from: context)!,
//            Suburb.fetch(withIdent: "ATTADALE", from: context)!])
//        Suburb.fetch(withIdent: "APPLECROSS", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "ALFRED+COVE", from: context)!, 
//            Suburb.fetch(withIdent: "MT+PLEASANT", from: context)!, 
//            Suburb.fetch(withIdent: "ATTADALE", from: context)!])
//        Suburb.fetch(withIdent: "ARMADALE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "KELMSCOTT", from: context)!, 
//            Suburb.fetch(withIdent: "SOUTHERN+RIVER", from: context)!, 
//            Suburb.fetch(withIdent: "BEDFORDALE", from: context)!, 
//            Suburb.fetch(withIdent: "FORRESTDALE", from: context)!, 
//            Suburb.fetch(withIdent: "SEVILLE+GROVE", from: context)!])
//        Suburb.fetch(withIdent: "ASCOT", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "REDCLIFFE", from: context)!, 
//            Suburb.fetch(withIdent: "BELMONT", from: context)!])
//        Suburb.fetch(withIdent: "ASHBY", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "ATTADALE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "ALFRED+COVE", from: context)!, 
//            Suburb.fetch(withIdent: "BICTON", from: context)!, 
//            Suburb.fetch(withIdent: "APPLECROSS", from: context)!])
//        Suburb.fetch(withIdent: "AUGUSTA", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "AUSTRALIND", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "BALCATTA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "CARINE", from: context)!, 
//            Suburb.fetch(withIdent: "NOLLAMARA", from: context)!, 
//            Suburb.fetch(withIdent: "WESTMINSTER", from: context)!, 
//            Suburb.fetch(withIdent: "GWELUP", from: context)!, 
//            Suburb.fetch(withIdent: "TUART+HILL", from: context)!, 
//            Suburb.fetch(withIdent: "BALGA", from: context)!])
//        Suburb.fetch(withIdent: "BALDIVIS", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "PORT+KENNEDY", from: context)!, 
//            Suburb.fetch(withIdent: "KWINANA", from: context)!, 
//            Suburb.fetch(withIdent: "LEDA", from: context)!, 
//            Suburb.fetch(withIdent: "WARNBRO", from: context)!, 
//            Suburb.fetch(withIdent: "WAIKIKI", from: context)!])
//        Suburb.fetch(withIdent: "BALGA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "WARWICK", from: context)!, 
//            Suburb.fetch(withIdent: "KOONDOOLA", from: context)!, 
//            Suburb.fetch(withIdent: "GIRRAWHEEN", from: context)!, 
//            Suburb.fetch(withIdent: "BALCATTA", from: context)!, 
//            Suburb.fetch(withIdent: "WESTMINSTER", from: context)!, 
//            Suburb.fetch(withIdent: "MIRRABOOKA", from: context)!])
//        Suburb.fetch(withIdent: "BALINGUP", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "BALLAJURA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "MIRRABOOKA", from: context)!, 
//            Suburb.fetch(withIdent: "ALEXANDER+HEIGHTS", from: context)!, 
//            Suburb.fetch(withIdent: "MALAGA", from: context)!, 
//            Suburb.fetch(withIdent: "KOONDOOLA", from: context)!, 
//            Suburb.fetch(withIdent: "BEECHBORO", from: context)!])
//        Suburb.fetch(withIdent: "BARRAGUP", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "SOUTH+YUNDERUP", from: context)!, 
//            Suburb.fetch(withIdent: "NORTH+YUNDERUP", from: context)!])
//        Suburb.fetch(withIdent: "BASKERVILLE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "HERNE+HILL", from: context)!, 
//            Suburb.fetch(withIdent: "UPPER+SWAN", from: context)!])
//        Suburb.fetch(withIdent: "BASSENDEAN", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BAYSWATER", from: context)!, 
//            Suburb.fetch(withIdent: "CAVERSHAM", from: context)!, 
//            Suburb.fetch(withIdent: "GUILDFORD", from: context)!])
//        Suburb.fetch(withIdent: "BAYSWATER", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "MORLEY", from: context)!, 
//            Suburb.fetch(withIdent: "BASSENDEAN", from: context)!])
//        Suburb.fetch(withIdent: "BECKENHAM", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "LANGFORD", from: context)!, 
//            Suburb.fetch(withIdent: "CANNINGTON", from: context)!])
//        Suburb.fetch(withIdent: "BEDFORDALE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "KELMSCOTT", from: context)!, 
//            Suburb.fetch(withIdent: "ARMADALE", from: context)!, 
//            Suburb.fetch(withIdent: "BYFORD", from: context)!])
//        Suburb.fetch(withIdent: "BEECHBORO", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "MALAGA", from: context)!, 
//            Suburb.fetch(withIdent: "KIARA", from: context)!, 
//            Suburb.fetch(withIdent: "WEST+SWAN", from: context)!, 
//            Suburb.fetch(withIdent: "BALLAJURA", from: context)!, 
//            Suburb.fetch(withIdent: "CAVERSHAM", from: context)!, 
//            Suburb.fetch(withIdent: "MORLEY", from: context)!, 
//            Suburb.fetch(withIdent: "NORANDA", from: context)!])
//        Suburb.fetch(withIdent: "BEELIAR", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "SUCCESS", from: context)!, 
//            Suburb.fetch(withIdent: "MUNSTER", from: context)!, 
//            Suburb.fetch(withIdent: "COCKBURN+CENTRAL", from: context)!])
//        Suburb.fetch(withIdent: "BELDON", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "OCEAN+REEF", from: context)!, 
//            Suburb.fetch(withIdent: "EDGEWATER", from: context)!, 
//            Suburb.fetch(withIdent: "MULLALOO", from: context)!, 
//            Suburb.fetch(withIdent: "WOODVALE", from: context)!])
//        Suburb.fetch(withIdent: "BELLEVUE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "MIDVALE", from: context)!])
//        Suburb.fetch(withIdent: "BELMONT", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "ASCOT", from: context)!, 
//            Suburb.fetch(withIdent: "REDCLIFFE", from: context)!, 
//            Suburb.fetch(withIdent: "RIVERVALE", from: context)!, 
//            Suburb.fetch(withIdent: "KEWDALE", from: context)!, 
//            Suburb.fetch(withIdent: "CLOVERDALE", from: context)!])
//        Suburb.fetch(withIdent: "BENTLEY", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "EAST+VICTORIA+PARK", from: context)!, 
//            Suburb.fetch(withIdent: "WELSHPOOL", from: context)!, 
//            Suburb.fetch(withIdent: "COMO", from: context)!, 
//            Suburb.fetch(withIdent: "CANNINGTON", from: context)!, 
//            Suburb.fetch(withIdent: "KARAWARA", from: context)!])
//        Suburb.fetch(withIdent: "BERTRAM", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "KWINANA", from: context)!, 
//            Suburb.fetch(withIdent: "PARMELIA", from: context)!])
//        Suburb.fetch(withIdent: "BIBRA+LAKE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "SOUTH+LAKE", from: context)!, 
//            Suburb.fetch(withIdent: "MURDOCH", from: context)!, 
//            Suburb.fetch(withIdent: "LEEMING", from: context)!, 
//            Suburb.fetch(withIdent: "SPEARWOOD", from: context)!])
//        Suburb.fetch(withIdent: "BICTON", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "PALMYRA", from: context)!, 
//            Suburb.fetch(withIdent: "EAST+FREMANTLE", from: context)!, 
//            Suburb.fetch(withIdent: "ATTADALE", from: context)!])
//        Suburb.fetch(withIdent: "BINNINGUP", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "MYALUP", from: context)!])
//        Suburb.fetch(withIdent: "BOULDER", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "BRENTWOOD", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "MT+PLEASANT", from: context)!, 
//            Suburb.fetch(withIdent: "BULL+CREEK", from: context)!])
//        Suburb.fetch(withIdent: "BRIDGETOWN", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "BROOME", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "BRUNSWICK+JUNCTION", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "BULL+CREEK", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BRENTWOOD", from: context)!, 
//            Suburb.fetch(withIdent: "MURDOCH", from: context)!, 
//            Suburb.fetch(withIdent: "LEEMING", from: context)!, 
//            Suburb.fetch(withIdent: "WILLETTON", from: context)!])
//        Suburb.fetch(withIdent: "BULLSBROOK", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "GIDGEGANNUP", from: context)!, 
//            Suburb.fetch(withIdent: "UPPER+SWAN", from: context)!])
//        Suburb.fetch(withIdent: "BUNBURY", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "PICTON", from: context)!])
//        Suburb.fetch(withIdent: "BURSWOOD", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "RIVERVALE", from: context)!, 
//            Suburb.fetch(withIdent: "VICTORIA+PARK", from: context)!, 
//            Suburb.fetch(withIdent: "CARLISLE", from: context)!])
//        Suburb.fetch(withIdent: "BUSSELTON", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "BUTLER", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "MERRIWA", from: context)!, 
//            Suburb.fetch(withIdent: "NOWERGUP", from: context)!])
//        Suburb.fetch(withIdent: "BYFORD", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BEDFORDALE", from: context)!])
//        Suburb.fetch(withIdent: "CANNING+VALE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "LEEMING", from: context)!, 
//            Suburb.fetch(withIdent: "JANDAKOT", from: context)!, 
//            Suburb.fetch(withIdent: "WILLETTON", from: context)!, 
//            Suburb.fetch(withIdent: "SOUTHERN+RIVER", from: context)!, 
//            Suburb.fetch(withIdent: "FORRESTDALE", from: context)!, 
//            Suburb.fetch(withIdent: "HUNTINGDALE", from: context)!, 
//            Suburb.fetch(withIdent: "THORNLIE", from: context)!])
//        Suburb.fetch(withIdent: "CANNINGTON", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BECKENHAM", from: context)!, 
//            Suburb.fetch(withIdent: "BENTLEY", from: context)!, 
//            Suburb.fetch(withIdent: "WELSHPOOL", from: context)!])
//        Suburb.fetch(withIdent: "CAPEL", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "CARBUNUP+RIVER", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "CARINE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "KARRINYUP", from: context)!, 
//            Suburb.fetch(withIdent: "WARWICK", from: context)!, 
//            Suburb.fetch(withIdent: "BALCATTA", from: context)!, 
//            Suburb.fetch(withIdent: "DUNCRAIG", from: context)!, 
//            Suburb.fetch(withIdent: "GWELUP", from: context)!])
//        Suburb.fetch(withIdent: "CARLISLE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "EAST+VICTORIA+PARK", from: context)!, 
//            Suburb.fetch(withIdent: "BURSWOOD", from: context)!, 
//            Suburb.fetch(withIdent: "RIVERVALE", from: context)!, 
//            Suburb.fetch(withIdent: "KEWDALE", from: context)!, 
//            Suburb.fetch(withIdent: "VICTORIA+PARK", from: context)!, 
//            Suburb.fetch(withIdent: "WELSHPOOL", from: context)!])
//        Suburb.fetch(withIdent: "CARNARVON", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "CATABY", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "CAVERSHAM", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "WEST+SWAN", from: context)!, 
//            Suburb.fetch(withIdent: "BASSENDEAN", from: context)!, 
//            Suburb.fetch(withIdent: "GUILDFORD", from: context)!, 
//            Suburb.fetch(withIdent: "KIARA", from: context)!, 
//            Suburb.fetch(withIdent: "BEECHBORO", from: context)!])
//        Suburb.fetch(withIdent: "CHIDLOW", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "GIDGEGANNUP", from: context)!, 
//            Suburb.fetch(withIdent: "WOOROLOO", from: context)!])
//        Suburb.fetch(withIdent: "CLAREMONT", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "COTTESLOE", from: context)!, 
//            Suburb.fetch(withIdent: "SWANBOURNE", from: context)!, 
//            Suburb.fetch(withIdent: "NEDLANDS", from: context)!])
//        Suburb.fetch(withIdent: "CLARKSON", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "NEERABUP", from: context)!, 
//            Suburb.fetch(withIdent: "MERRIWA", from: context)!, 
//            Suburb.fetch(withIdent: "MINDARIE", from: context)!, 
//            Suburb.fetch(withIdent: "RIDGEWOOD", from: context)!, 
//            Suburb.fetch(withIdent: "NOWERGUP", from: context)!])
//        Suburb.fetch(withIdent: "CLOVERDALE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "REDCLIFFE", from: context)!, 
//            Suburb.fetch(withIdent: "RIVERVALE", from: context)!, 
//            Suburb.fetch(withIdent: "KEWDALE", from: context)!, 
//            Suburb.fetch(withIdent: "BELMONT", from: context)!])
//        Suburb.fetch(withIdent: "COCKBURN+CENTRAL", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "SOUTH+LAKE", from: context)!, 
//            Suburb.fetch(withIdent: "BEELIAR", from: context)!, 
//            Suburb.fetch(withIdent: "JANDAKOT", from: context)!, 
//            Suburb.fetch(withIdent: "SUCCESS", from: context)!])
//        Suburb.fetch(withIdent: "COLLIE", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "COMO", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BENTLEY", from: context)!, 
//            Suburb.fetch(withIdent: "MANNING", from: context)!, 
//            Suburb.fetch(withIdent: "SOUTH+PERTH", from: context)!, 
//            Suburb.fetch(withIdent: "KARAWARA", from: context)!])
//        Suburb.fetch(withIdent: "COOLGARDIE", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "COOLUP", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "COTTESLOE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "MOSMAN+PARK", from: context)!, 
//            Suburb.fetch(withIdent: "SWANBOURNE", from: context)!, 
//            Suburb.fetch(withIdent: "CLAREMONT", from: context)!])
//        Suburb.fetch(withIdent: "COWARAMUP", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "CUNDERDIN", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "CURRAMBINE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "JOONDALUP", from: context)!, 
//            Suburb.fetch(withIdent: "NEERABUP", from: context)!, 
//            Suburb.fetch(withIdent: "OCEAN+REEF", from: context)!])
//        Suburb.fetch(withIdent: "DALWALLINU", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "DAMPIER", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "DARDANUP", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "DENMARK", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "DERBY", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "DIANELLA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "MALAGA", from: context)!, 
//            Suburb.fetch(withIdent: "MIRRABOOKA", from: context)!, 
//            Suburb.fetch(withIdent: "WESTMINSTER", from: context)!, 
//            Suburb.fetch(withIdent: "MORLEY", from: context)!, 
//            Suburb.fetch(withIdent: "NORANDA", from: context)!, 
//            Suburb.fetch(withIdent: "NOLLAMARA", from: context)!, 
//            Suburb.fetch(withIdent: "YOKINE", from: context)!])
//        Suburb.fetch(withIdent: "DONGARA", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "DONNYBROOK", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "DOUBLEVIEW", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "SCARBOROUGH", from: context)!, 
//            Suburb.fetch(withIdent: "INNALOO", from: context)!, 
//            Suburb.fetch(withIdent: "KARRINYUP", from: context)!])
//        Suburb.fetch(withIdent: "DUNCRAIG", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "CARINE", from: context)!, 
//            Suburb.fetch(withIdent: "HILLARYS", from: context)!, 
//            Suburb.fetch(withIdent: "KINGSLEY", from: context)!, 
//            Suburb.fetch(withIdent: "GREENWOOD", from: context)!, 
//            Suburb.fetch(withIdent: "SORRENTO", from: context)!, 
//            Suburb.fetch(withIdent: "WARWICK", from: context)!, 
//            Suburb.fetch(withIdent: "PADBURY", from: context)!])
//        Suburb.fetch(withIdent: "DUNSBOROUGH", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "DWELLINGUP", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "EAST+FREMANTLE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "NORTH+FREMANTLE", from: context)!, 
//            Suburb.fetch(withIdent: "PALMYRA", from: context)!, 
//            Suburb.fetch(withIdent: "FREMANTLE", from: context)!, 
//            Suburb.fetch(withIdent: "BICTON", from: context)!])
//        Suburb.fetch(withIdent: "EAST+PERTH", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "NORTHBRIDGE", from: context)!, 
//            Suburb.fetch(withIdent: "MT+LAWLEY", from: context)!, 
//            Suburb.fetch(withIdent: "PERTH", from: context)!, 
//            Suburb.fetch(withIdent: "HIGHGATE", from: context)!])
//        Suburb.fetch(withIdent: "EAST+VICTORIA+PARK", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "VICTORIA+PARK", from: context)!, 
//            Suburb.fetch(withIdent: "BENTLEY", from: context)!, 
//            Suburb.fetch(withIdent: "CARLISLE", from: context)!])
//        Suburb.fetch(withIdent: "EATON", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "EDGEWATER", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "JOONDALUP", from: context)!, 
//            Suburb.fetch(withIdent: "BELDON", from: context)!, 
//            Suburb.fetch(withIdent: "WOODVALE", from: context)!])
//        Suburb.fetch(withIdent: "ELLENBROOK", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "HENLEY+BROOK", from: context)!])
//        Suburb.fetch(withIdent: "ERSKINE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "MANDURAH", from: context)!, 
//            Suburb.fetch(withIdent: "HALLS+HEAD", from: context)!, 
//            Suburb.fetch(withIdent: "FALCON", from: context)!])
//        Suburb.fetch(withIdent: "ESPERANCE", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "EXMOUTH", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "FALCON", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "ERSKINE", from: context)!, 
//            Suburb.fetch(withIdent: "HALLS+HEAD", from: context)!, 
//            Suburb.fetch(withIdent: "MANDURAH", from: context)!])
//        Suburb.fetch(withIdent: "FITZROY+CROSSING", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "FLOREAT", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "WEMBLEY", from: context)!, 
//            Suburb.fetch(withIdent: "JOLIMONT", from: context)!])
//        Suburb.fetch(withIdent: "FORRESTDALE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "ARMADALE", from: context)!, 
//            Suburb.fetch(withIdent: "CANNING+VALE", from: context)!, 
//            Suburb.fetch(withIdent: "SOUTHERN+RIVER", from: context)!, 
//            Suburb.fetch(withIdent: "SEVILLE+GROVE", from: context)!])
//        Suburb.fetch(withIdent: "FORRESTFIELD", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "KALAMUNDA", from: context)!, 
//            Suburb.fetch(withIdent: "HIGH+WYCOMBE", from: context)!, 
//            Suburb.fetch(withIdent: "LESMURDIE", from: context)!, 
//            Suburb.fetch(withIdent: "MAIDA+VALE", from: context)!])
//        Suburb.fetch(withIdent: "FREMANTLE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "O'CONNOR", from: context)!, 
//            Suburb.fetch(withIdent: "PALMYRA", from: context)!, 
//            Suburb.fetch(withIdent: "EAST+FREMANTLE", from: context)!, 
//            Suburb.fetch(withIdent: "SOUTH+FREMANTLE", from: context)!, 
//            Suburb.fetch(withIdent: "NORTH+FREMANTLE", from: context)!])
//        Suburb.fetch(withIdent: "GELORUP", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "GERALDTON", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "GIDGEGANNUP", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "CHIDLOW", from: context)!, 
//            Suburb.fetch(withIdent: "WOOROLOO", from: context)!, 
//            Suburb.fetch(withIdent: "BULLSBROOK", from: context)!])
//        Suburb.fetch(withIdent: "GIRRAWHEEN", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "WARWICK", from: context)!, 
//            Suburb.fetch(withIdent: "ALEXANDER+HEIGHTS", from: context)!, 
//            Suburb.fetch(withIdent: "GREENWOOD", from: context)!, 
//            Suburb.fetch(withIdent: "BALGA", from: context)!, 
//            Suburb.fetch(withIdent: "KOONDOOLA", from: context)!, 
//            Suburb.fetch(withIdent: "MIRRABOOKA", from: context)!])
//        Suburb.fetch(withIdent: "GLEN+FORREST", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "GLENDALOUGH", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "WEMBLEY", from: context)!, 
//            Suburb.fetch(withIdent: "OSBORNE+PARK", from: context)!])
//        Suburb.fetch(withIdent: "GLENFIELD", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "GREENOUGH", from: context)!])
//        Suburb.fetch(withIdent: "GNANGARA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "WANNEROO", from: context)!, 
//            Suburb.fetch(withIdent: "PEARSALL", from: context)!, 
//            Suburb.fetch(withIdent: "WANGARA", from: context)!, 
//            Suburb.fetch(withIdent: "LEXIA", from: context)!])
//        Suburb.fetch(withIdent: "GOLDEN+BAY", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "SINGLETON", from: context)!, 
//            Suburb.fetch(withIdent: "SECRET+HARBOUR", from: context)!])
//        Suburb.fetch(withIdent: "GOSNELLS", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "THORNLIE", from: context)!, 
//            Suburb.fetch(withIdent: "HUNTINGDALE", from: context)!, 
//            Suburb.fetch(withIdent: "KELMSCOTT", from: context)!, 
//            Suburb.fetch(withIdent: "SOUTHERN+RIVER", from: context)!, 
//            Suburb.fetch(withIdent: "MADDINGTON", from: context)!])
//        Suburb.fetch(withIdent: "GRACETOWN", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "GREENBUSHES", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "GREENOUGH", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "GLENFIELD", from: context)!])
//        Suburb.fetch(withIdent: "GREENWOOD", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "KINGSLEY", from: context)!, 
//            Suburb.fetch(withIdent: "GIRRAWHEEN", from: context)!, 
//            Suburb.fetch(withIdent: "MADELEY", from: context)!, 
//            Suburb.fetch(withIdent: "DUNCRAIG", from: context)!, 
//            Suburb.fetch(withIdent: "WARWICK", from: context)!])
//        Suburb.fetch(withIdent: "GUILDFORD", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BASSENDEAN", from: context)!, 
//            Suburb.fetch(withIdent: "CAVERSHAM", from: context)!])
//        Suburb.fetch(withIdent: "GWELUP", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "CARINE", from: context)!, 
//            Suburb.fetch(withIdent: "INNALOO", from: context)!, 
//            Suburb.fetch(withIdent: "BALCATTA", from: context)!, 
//            Suburb.fetch(withIdent: "KARRINYUP", from: context)!])
//        Suburb.fetch(withIdent: "HALLS+HEAD", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "ERSKINE", from: context)!, 
//            Suburb.fetch(withIdent: "MANDURAH", from: context)!, 
//            Suburb.fetch(withIdent: "FALCON", from: context)!])
//        Suburb.fetch(withIdent: "HAMILTON+HILL", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "SOUTH+FREMANTLE", from: context)!, 
//            Suburb.fetch(withIdent: "SPEARWOOD", from: context)!])
//        Suburb.fetch(withIdent: "HARVEY", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "HENLEY+BROOK", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "ELLENBROOK", from: context)!, 
//            Suburb.fetch(withIdent: "WEST+SWAN", from: context)!])
//        Suburb.fetch(withIdent: "HERNE+HILL", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "MIDDLE+SWAN", from: context)!, 
//            Suburb.fetch(withIdent: "BASKERVILLE", from: context)!])
//        Suburb.fetch(withIdent: "HIGH+WYCOMBE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "FORRESTFIELD", from: context)!, 
//            Suburb.fetch(withIdent: "MAIDA+VALE", from: context)!])
//        Suburb.fetch(withIdent: "HIGHGATE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "NORTHBRIDGE", from: context)!, 
//            Suburb.fetch(withIdent: "MT+LAWLEY", from: context)!, 
//            Suburb.fetch(withIdent: "NORTH+PERTH", from: context)!, 
//            Suburb.fetch(withIdent: "PERTH", from: context)!, 
//            Suburb.fetch(withIdent: "EAST+PERTH", from: context)!])
//        Suburb.fetch(withIdent: "HILLARYS", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "PADBURY", from: context)!, 
//            Suburb.fetch(withIdent: "DUNCRAIG", from: context)!, 
//            Suburb.fetch(withIdent: "SORRENTO", from: context)!])
//        Suburb.fetch(withIdent: "HUNTINGDALE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "GOSNELLS", from: context)!, 
//            Suburb.fetch(withIdent: "CANNING+VALE", from: context)!, 
//            Suburb.fetch(withIdent: "SOUTHERN+RIVER", from: context)!, 
//            Suburb.fetch(withIdent: "THORNLIE", from: context)!])
//        Suburb.fetch(withIdent: "INNALOO", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "OSBORNE+PARK", from: context)!, 
//            Suburb.fetch(withIdent: "GWELUP", from: context)!, 
//            Suburb.fetch(withIdent: "DOUBLEVIEW", from: context)!, 
//            Suburb.fetch(withIdent: "KARRINYUP", from: context)!])
//        Suburb.fetch(withIdent: "JANDAKOT", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "SOUTH+LAKE", from: context)!, 
//            Suburb.fetch(withIdent: "CANNING+VALE", from: context)!, 
//            Suburb.fetch(withIdent: "COCKBURN+CENTRAL", from: context)!, 
//            Suburb.fetch(withIdent: "LEEMING", from: context)!, 
//            Suburb.fetch(withIdent: "SUCCESS", from: context)!])
//        Suburb.fetch(withIdent: "JOLIMONT", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "FLOREAT", from: context)!, 
//            Suburb.fetch(withIdent: "WEMBLEY", from: context)!, 
//            Suburb.fetch(withIdent: "SUBIACO", from: context)!])
//        Suburb.fetch(withIdent: "JOONDALUP", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "CURRAMBINE", from: context)!, 
//            Suburb.fetch(withIdent: "NEERABUP", from: context)!, 
//            Suburb.fetch(withIdent: "EDGEWATER", from: context)!])
//        Suburb.fetch(withIdent: "JURIEN+BAY", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "KALAMUNDA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "LESMURDIE", from: context)!, 
//            Suburb.fetch(withIdent: "FORRESTFIELD", from: context)!, 
//            Suburb.fetch(withIdent: "MAIDA+VALE", from: context)!])
//        Suburb.fetch(withIdent: "KALGOORLIE", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "KAMBALDA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "KAMBALDA+WEST", from: context)!])
//        Suburb.fetch(withIdent: "KAMBALDA+WEST", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "KAMBALDA", from: context)!])
//        Suburb.fetch(withIdent: "KARAWARA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "COMO", from: context)!, 
//            Suburb.fetch(withIdent: "BENTLEY", from: context)!, 
//            Suburb.fetch(withIdent: "MANNING", from: context)!])
//        Suburb.fetch(withIdent: "KARDINYA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "O'CONNOR", from: context)!, 
//            Suburb.fetch(withIdent: "MURDOCH", from: context)!, 
//            Suburb.fetch(withIdent: "MYAREE", from: context)!])
//        Suburb.fetch(withIdent: "KARRAGULLEN", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "ROLEYSTONE", from: context)!])
//        Suburb.fetch(withIdent: "KARRATHA", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "KARRIDALE", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "KARRINYUP", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "CARINE", from: context)!, 
//            Suburb.fetch(withIdent: "SCARBOROUGH", from: context)!, 
//            Suburb.fetch(withIdent: "INNALOO", from: context)!, 
//            Suburb.fetch(withIdent: "DOUBLEVIEW", from: context)!, 
//            Suburb.fetch(withIdent: "GWELUP", from: context)!])
//        Suburb.fetch(withIdent: "KELLERBERRIN", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "KELMSCOTT", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "ARMADALE", from: context)!, 
//            Suburb.fetch(withIdent: "GOSNELLS", from: context)!, 
//            Suburb.fetch(withIdent: "BEDFORDALE", from: context)!, 
//            Suburb.fetch(withIdent: "SEVILLE+GROVE", from: context)!])
//        Suburb.fetch(withIdent: "KEWDALE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "WATTLE+GROVE", from: context)!, 
//            Suburb.fetch(withIdent: "CARLISLE", from: context)!, 
//            Suburb.fetch(withIdent: "WELSHPOOL", from: context)!, 
//            Suburb.fetch(withIdent: "CLOVERDALE", from: context)!, 
//            Suburb.fetch(withIdent: "RIVERVALE", from: context)!, 
//            Suburb.fetch(withIdent: "BELMONT", from: context)!])
//        Suburb.fetch(withIdent: "KIARA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BEECHBORO", from: context)!, 
//            Suburb.fetch(withIdent: "CAVERSHAM", from: context)!, 
//            Suburb.fetch(withIdent: "NORANDA", from: context)!, 
//            Suburb.fetch(withIdent: "MORLEY", from: context)!])
//        Suburb.fetch(withIdent: "KINGSLEY", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "PADBURY", from: context)!, 
//            Suburb.fetch(withIdent: "GREENWOOD", from: context)!, 
//            Suburb.fetch(withIdent: "WANGARA", from: context)!, 
//            Suburb.fetch(withIdent: "MADELEY", from: context)!, 
//            Suburb.fetch(withIdent: "DUNCRAIG", from: context)!, 
//            Suburb.fetch(withIdent: "WOODVALE", from: context)!])
//        Suburb.fetch(withIdent: "KIRUP", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "KOJONUP", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "KOONDOOLA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BALLAJURA", from: context)!, 
//            Suburb.fetch(withIdent: "ALEXANDER+HEIGHTS", from: context)!, 
//            Suburb.fetch(withIdent: "MALAGA", from: context)!, 
//            Suburb.fetch(withIdent: "BALGA", from: context)!, 
//            Suburb.fetch(withIdent: "GIRRAWHEEN", from: context)!, 
//            Suburb.fetch(withIdent: "MIRRABOOKA", from: context)!])
//        Suburb.fetch(withIdent: "KUNUNURRA", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "KWINANA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BALDIVIS", from: context)!, 
//            Suburb.fetch(withIdent: "BERTRAM", from: context)!, 
//            Suburb.fetch(withIdent: "PARMELIA", from: context)!, 
//            Suburb.fetch(withIdent: "NAVAL+BASE", from: context)!, 
//            Suburb.fetch(withIdent: "LEDA", from: context)!])
//        Suburb.fetch(withIdent: "LAKELANDS", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "MEADOW+SPRINGS", from: context)!, 
//            Suburb.fetch(withIdent: "MANDURAH", from: context)!])
//        Suburb.fetch(withIdent: "LANGFORD", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BECKENHAM", from: context)!, 
//            Suburb.fetch(withIdent: "THORNLIE", from: context)!, 
//            Suburb.fetch(withIdent: "LYNWOOD", from: context)!])
//        Suburb.fetch(withIdent: "LEDA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BALDIVIS", from: context)!, 
//            Suburb.fetch(withIdent: "KWINANA", from: context)!, 
//            Suburb.fetch(withIdent: "PARMELIA", from: context)!])
//        Suburb.fetch(withIdent: "LEEDERVILLE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "NORTH+PERTH", from: context)!, 
//            Suburb.fetch(withIdent: "WEST+PERTH", from: context)!])
//        Suburb.fetch(withIdent: "LEEMING", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "CANNING+VALE", from: context)!, 
//            Suburb.fetch(withIdent: "JANDAKOT", from: context)!, 
//            Suburb.fetch(withIdent: "BULL+CREEK", from: context)!, 
//            Suburb.fetch(withIdent: "MURDOCH", from: context)!, 
//            Suburb.fetch(withIdent: "BIBRA+LAKE", from: context)!, 
//            Suburb.fetch(withIdent: "WILLETTON", from: context)!])
//        Suburb.fetch(withIdent: "LESMURDIE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "FORRESTFIELD", from: context)!, 
//            Suburb.fetch(withIdent: "KALAMUNDA", from: context)!])
//        Suburb.fetch(withIdent: "LEXIA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "GNANGARA", from: context)!])
//        Suburb.fetch(withIdent: "LYNWOOD", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "THORNLIE", from: context)!, 
//            Suburb.fetch(withIdent: "LANGFORD", from: context)!])
//        Suburb.fetch(withIdent: "MADDINGTON", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "GOSNELLS", from: context)!])
//        Suburb.fetch(withIdent: "MADELEY", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "GREENWOOD", from: context)!, 
//            Suburb.fetch(withIdent: "WANGARA", from: context)!, 
//            Suburb.fetch(withIdent: "KINGSLEY", from: context)!])
//        Suburb.fetch(withIdent: "MAIDA+VALE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "KALAMUNDA", from: context)!, 
//            Suburb.fetch(withIdent: "FORRESTFIELD", from: context)!, 
//            Suburb.fetch(withIdent: "HIGH+WYCOMBE", from: context)!])
//        Suburb.fetch(withIdent: "MALAGA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BALLAJURA", from: context)!, 
//            Suburb.fetch(withIdent: "MIRRABOOKA", from: context)!, 
//            Suburb.fetch(withIdent: "NORANDA", from: context)!, 
//            Suburb.fetch(withIdent: "DIANELLA", from: context)!, 
//            Suburb.fetch(withIdent: "KOONDOOLA", from: context)!, 
//            Suburb.fetch(withIdent: "BEECHBORO", from: context)!])
//        Suburb.fetch(withIdent: "MANDURAH", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "FALCON", from: context)!, 
//            Suburb.fetch(withIdent: "ERSKINE", from: context)!, 
//            Suburb.fetch(withIdent: "LAKELANDS", from: context)!, 
//            Suburb.fetch(withIdent: "MEADOW+SPRINGS", from: context)!, 
//            Suburb.fetch(withIdent: "HALLS+HEAD", from: context)!])
//        Suburb.fetch(withIdent: "MANJIMUP", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "MANNING", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "COMO", from: context)!, 
//            Suburb.fetch(withIdent: "KARAWARA", from: context)!])
//        Suburb.fetch(withIdent: "MANYPEAKS", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "MARGARET+RIVER", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "MEADOW+SPRINGS", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "MANDURAH", from: context)!, 
//            Suburb.fetch(withIdent: "LAKELANDS", from: context)!])
//        Suburb.fetch(withIdent: "MEEKATHARRA", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "MERRIWA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "QUINNS+ROCKS", from: context)!, 
//            Suburb.fetch(withIdent: "CLARKSON", from: context)!, 
//            Suburb.fetch(withIdent: "MINDARIE", from: context)!, 
//            Suburb.fetch(withIdent: "BUTLER", from: context)!, 
//            Suburb.fetch(withIdent: "RIDGEWOOD", from: context)!])
//        Suburb.fetch(withIdent: "MIDDLE+SWAN", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "HERNE+HILL", from: context)!, 
//            Suburb.fetch(withIdent: "STRATTON", from: context)!])
//        Suburb.fetch(withIdent: "MIDVALE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BELLEVUE", from: context)!, 
//            Suburb.fetch(withIdent: "SWAN+VIEW", from: context)!, 
//            Suburb.fetch(withIdent: "STRATTON", from: context)!])
//        Suburb.fetch(withIdent: "MINDARIE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "CLARKSON", from: context)!, 
//            Suburb.fetch(withIdent: "MERRIWA", from: context)!])
//        Suburb.fetch(withIdent: "MIRRABOOKA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "MALAGA", from: context)!, 
//            Suburb.fetch(withIdent: "WESTMINSTER", from: context)!, 
//            Suburb.fetch(withIdent: "BALLAJURA", from: context)!, 
//            Suburb.fetch(withIdent: "KOONDOOLA", from: context)!, 
//            Suburb.fetch(withIdent: "BALGA", from: context)!, 
//            Suburb.fetch(withIdent: "DIANELLA", from: context)!, 
//            Suburb.fetch(withIdent: "GIRRAWHEEN", from: context)!, 
//            Suburb.fetch(withIdent: "NOLLAMARA", from: context)!])
//        Suburb.fetch(withIdent: "MOONYOONOOKA", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "MOORA", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "MORLEY", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "KIARA", from: context)!, 
//            Suburb.fetch(withIdent: "NORANDA", from: context)!, 
//            Suburb.fetch(withIdent: "BAYSWATER", from: context)!, 
//            Suburb.fetch(withIdent: "DIANELLA", from: context)!, 
//            Suburb.fetch(withIdent: "BEECHBORO", from: context)!])
//        Suburb.fetch(withIdent: "MOSMAN+PARK", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "COTTESLOE", from: context)!])
//        Suburb.fetch(withIdent: "MOUNT+BARKER", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "MT+LAWLEY", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "NORTHBRIDGE", from: context)!, 
//            Suburb.fetch(withIdent: "NORTH+PERTH", from: context)!, 
//            Suburb.fetch(withIdent: "HIGHGATE", from: context)!, 
//            Suburb.fetch(withIdent: "PERTH", from: context)!, 
//            Suburb.fetch(withIdent: "EAST+PERTH", from: context)!])
//        Suburb.fetch(withIdent: "MT+PLEASANT", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BRENTWOOD", from: context)!, 
//            Suburb.fetch(withIdent: "APPLECROSS", from: context)!])
//        Suburb.fetch(withIdent: "MULLALOO", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BELDON", from: context)!, 
//            Suburb.fetch(withIdent: "OCEAN+REEF", from: context)!])
//        Suburb.fetch(withIdent: "MULLALYUP", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "MUNDARING", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "SAWYERS+VALLEY", from: context)!])
//        Suburb.fetch(withIdent: "MUNDIJONG", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "MUNSTER", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BEELIAR", from: context)!, 
//            Suburb.fetch(withIdent: "SPEARWOOD", from: context)!])
//        Suburb.fetch(withIdent: "MURDOCH", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "LEEMING", from: context)!, 
//            Suburb.fetch(withIdent: "BULL+CREEK", from: context)!, 
//            Suburb.fetch(withIdent: "KARDINYA", from: context)!, 
//            Suburb.fetch(withIdent: "BIBRA+LAKE", from: context)!])
//        Suburb.fetch(withIdent: "MYALUP", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BINNINGUP", from: context)!])
//        Suburb.fetch(withIdent: "MYAREE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "ALFRED+COVE", from: context)!, 
//            Suburb.fetch(withIdent: "KARDINYA", from: context)!])
//        Suburb.fetch(withIdent: "NARROGIN", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "NAVAL+BASE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "KWINANA", from: context)!])
//        Suburb.fetch(withIdent: "NEDLANDS", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "SWANBOURNE", from: context)!, 
//            Suburb.fetch(withIdent: "CLAREMONT", from: context)!])
//        Suburb.fetch(withIdent: "NEERABUP", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "CURRAMBINE", from: context)!, 
//            Suburb.fetch(withIdent: "CLARKSON", from: context)!, 
//            Suburb.fetch(withIdent: "JOONDALUP", from: context)!, 
//            Suburb.fetch(withIdent: "NOWERGUP", from: context)!, 
//            Suburb.fetch(withIdent: "RIDGEWOOD", from: context)!])
//        Suburb.fetch(withIdent: "NEWMAN", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "NOLLAMARA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "TUART+HILL", from: context)!, 
//            Suburb.fetch(withIdent: "YOKINE", from: context)!, 
//            Suburb.fetch(withIdent: "WESTMINSTER", from: context)!, 
//            Suburb.fetch(withIdent: "BALCATTA", from: context)!, 
//            Suburb.fetch(withIdent: "DIANELLA", from: context)!, 
//            Suburb.fetch(withIdent: "MIRRABOOKA", from: context)!])
//        Suburb.fetch(withIdent: "NORANDA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BEECHBORO", from: context)!, 
//            Suburb.fetch(withIdent: "MORLEY", from: context)!, 
//            Suburb.fetch(withIdent: "DIANELLA", from: context)!, 
//            Suburb.fetch(withIdent: "KIARA", from: context)!, 
//            Suburb.fetch(withIdent: "MALAGA", from: context)!])
//        Suburb.fetch(withIdent: "NORSEMAN", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "NORTH+DANDALUP", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "NORTH+FREMANTLE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "FREMANTLE", from: context)!, 
//            Suburb.fetch(withIdent: "EAST+FREMANTLE", from: context)!])
//        Suburb.fetch(withIdent: "NORTH+PERTH", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "NORTHBRIDGE", from: context)!, 
//            Suburb.fetch(withIdent: "MT+LAWLEY", from: context)!, 
//            Suburb.fetch(withIdent: "LEEDERVILLE", from: context)!, 
//            Suburb.fetch(withIdent: "HIGHGATE", from: context)!, 
//            Suburb.fetch(withIdent: "PERTH", from: context)!, 
//            Suburb.fetch(withIdent: "WEST+PERTH", from: context)!])
//        Suburb.fetch(withIdent: "NORTH+YUNDERUP", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "PINJARRA", from: context)!, 
//            Suburb.fetch(withIdent: "SOUTH+YUNDERUP", from: context)!, 
//            Suburb.fetch(withIdent: "BARRAGUP", from: context)!])
//        Suburb.fetch(withIdent: "NORTHAM", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "NORTHBRIDGE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "WEST+PERTH", from: context)!, 
//            Suburb.fetch(withIdent: "NORTH+PERTH", from: context)!, 
//            Suburb.fetch(withIdent: "MT+LAWLEY", from: context)!, 
//            Suburb.fetch(withIdent: "HIGHGATE", from: context)!, 
//            Suburb.fetch(withIdent: "PERTH", from: context)!, 
//            Suburb.fetch(withIdent: "EAST+PERTH", from: context)!])
//        Suburb.fetch(withIdent: "NORTHCLIFFE", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "NOWERGUP", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "NEERABUP", from: context)!, 
//            Suburb.fetch(withIdent: "CLARKSON", from: context)!, 
//            Suburb.fetch(withIdent: "YANCHEP", from: context)!, 
//            Suburb.fetch(withIdent: "BUTLER", from: context)!, 
//            Suburb.fetch(withIdent: "RIDGEWOOD", from: context)!])
//        Suburb.fetch(withIdent: "O'CONNOR", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "FREMANTLE", from: context)!, 
//            Suburb.fetch(withIdent: "PALMYRA", from: context)!, 
//            Suburb.fetch(withIdent: "KARDINYA", from: context)!])
//        Suburb.fetch(withIdent: "OCEAN+REEF", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "CURRAMBINE", from: context)!, 
//            Suburb.fetch(withIdent: "BELDON", from: context)!, 
//            Suburb.fetch(withIdent: "MULLALOO", from: context)!])
//        Suburb.fetch(withIdent: "OSBORNE+PARK", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "GLENDALOUGH", from: context)!, 
//            Suburb.fetch(withIdent: "INNALOO", from: context)!, 
//            Suburb.fetch(withIdent: "TUART+HILL", from: context)!])
//        Suburb.fetch(withIdent: "PADBURY", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "KINGSLEY", from: context)!, 
//            Suburb.fetch(withIdent: "WOODVALE", from: context)!, 
//            Suburb.fetch(withIdent: "SORRENTO", from: context)!, 
//            Suburb.fetch(withIdent: "HILLARYS", from: context)!, 
//            Suburb.fetch(withIdent: "DUNCRAIG", from: context)!])
//        Suburb.fetch(withIdent: "PALMYRA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "O'CONNOR", from: context)!, 
//            Suburb.fetch(withIdent: "FREMANTLE", from: context)!, 
//            Suburb.fetch(withIdent: "EAST+FREMANTLE", from: context)!, 
//            Suburb.fetch(withIdent: "BICTON", from: context)!])
//        Suburb.fetch(withIdent: "PARMELIA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BERTRAM", from: context)!, 
//            Suburb.fetch(withIdent: "KWINANA", from: context)!, 
//            Suburb.fetch(withIdent: "LEDA", from: context)!])
//        Suburb.fetch(withIdent: "PEARSALL", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "GNANGARA", from: context)!, 
//            Suburb.fetch(withIdent: "WOODVALE", from: context)!])
//        Suburb.fetch(withIdent: "PEMBERTON", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "PERTH", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "NORTHBRIDGE", from: context)!, 
//            Suburb.fetch(withIdent: "NORTH+PERTH", from: context)!, 
//            Suburb.fetch(withIdent: "MT+LAWLEY", from: context)!, 
//            Suburb.fetch(withIdent: "HIGHGATE", from: context)!, 
//            Suburb.fetch(withIdent: "WEST+PERTH", from: context)!, 
//            Suburb.fetch(withIdent: "EAST+PERTH", from: context)!])
//        Suburb.fetch(withIdent: "PICTON", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BUNBURY", from: context)!])
//        Suburb.fetch(withIdent: "PINJARRA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "SOUTH+YUNDERUP", from: context)!, 
//            Suburb.fetch(withIdent: "NORTH+YUNDERUP", from: context)!])
//        Suburb.fetch(withIdent: "PORT+HEDLAND", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "PORT+KENNEDY", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BALDIVIS", from: context)!, 
//            Suburb.fetch(withIdent: "SECRET+HARBOUR", from: context)!, 
//            Suburb.fetch(withIdent: "WARNBRO", from: context)!])
//        Suburb.fetch(withIdent: "PRESTON+BEACH", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "QUINNS+ROCKS", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "MERRIWA", from: context)!])
//        Suburb.fetch(withIdent: "RAVENSTHORPE", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "REDCLIFFE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BELMONT", from: context)!, 
//            Suburb.fetch(withIdent: "CLOVERDALE", from: context)!, 
//            Suburb.fetch(withIdent: "ASCOT", from: context)!])
//        Suburb.fetch(withIdent: "REDMOND", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "RIDGEWOOD", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "NEERABUP", from: context)!, 
//            Suburb.fetch(withIdent: "MERRIWA", from: context)!, 
//            Suburb.fetch(withIdent: "CLARKSON", from: context)!, 
//            Suburb.fetch(withIdent: "NOWERGUP", from: context)!])
//        Suburb.fetch(withIdent: "RIVERTON", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "WILLETTON", from: context)!])
//        Suburb.fetch(withIdent: "RIVERVALE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BURSWOOD", from: context)!, 
//            Suburb.fetch(withIdent: "CARLISLE", from: context)!, 
//            Suburb.fetch(withIdent: "CLOVERDALE", from: context)!, 
//            Suburb.fetch(withIdent: "KEWDALE", from: context)!, 
//            Suburb.fetch(withIdent: "BELMONT", from: context)!])
//        Suburb.fetch(withIdent: "ROCKINGHAM", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "WAIKIKI", from: context)!, 
//            Suburb.fetch(withIdent: "WARNBRO", from: context)!])
//        Suburb.fetch(withIdent: "ROLEYSTONE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "KARRAGULLEN", from: context)!])
//        Suburb.fetch(withIdent: "ROSA+BROOK", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "ROTTNEST+ISLAND", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "SAWYERS+VALLEY", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "MUNDARING", from: context)!])
//        Suburb.fetch(withIdent: "SCARBOROUGH", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "KARRINYUP", from: context)!, 
//            Suburb.fetch(withIdent: "DOUBLEVIEW", from: context)!])
//        Suburb.fetch(withIdent: "SECRET+HARBOUR", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "GOLDEN+BAY", from: context)!, 
//            Suburb.fetch(withIdent: "PORT+KENNEDY", from: context)!])
//        Suburb.fetch(withIdent: "SERPENTINE", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "SEVILLE+GROVE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "KELMSCOTT", from: context)!, 
//            Suburb.fetch(withIdent: "ARMADALE", from: context)!, 
//            Suburb.fetch(withIdent: "FORRESTDALE", from: context)!])
//        Suburb.fetch(withIdent: "SINGLETON", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "GOLDEN+BAY", from: context)!])
//        Suburb.fetch(withIdent: "SORRENTO", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "HILLARYS", from: context)!, 
//            Suburb.fetch(withIdent: "DUNCRAIG", from: context)!, 
//            Suburb.fetch(withIdent: "PADBURY", from: context)!])
//        Suburb.fetch(withIdent: "SOUTH+FREMANTLE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "FREMANTLE", from: context)!, 
//            Suburb.fetch(withIdent: "HAMILTON+HILL", from: context)!])
//        Suburb.fetch(withIdent: "SOUTH+HEDLAND", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "SOUTH+LAKE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "COCKBURN+CENTRAL", from: context)!, 
//            Suburb.fetch(withIdent: "JANDAKOT", from: context)!, 
//            Suburb.fetch(withIdent: "BIBRA+LAKE", from: context)!])
//        Suburb.fetch(withIdent: "SOUTH+PERTH", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "COMO", from: context)!, 
//            Suburb.fetch(withIdent: "VICTORIA+PARK", from: context)!])
//        Suburb.fetch(withIdent: "SOUTH+YUNDERUP", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "NORTH+YUNDERUP", from: context)!, 
//            Suburb.fetch(withIdent: "PINJARRA", from: context)!, 
//            Suburb.fetch(withIdent: "BARRAGUP", from: context)!])
//        Suburb.fetch(withIdent: "SOUTHERN+RIVER", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "HUNTINGDALE", from: context)!, 
//            Suburb.fetch(withIdent: "CANNING+VALE", from: context)!, 
//            Suburb.fetch(withIdent: "GOSNELLS", from: context)!, 
//            Suburb.fetch(withIdent: "FORRESTDALE", from: context)!, 
//            Suburb.fetch(withIdent: "ARMADALE", from: context)!])
//        Suburb.fetch(withIdent: "SPEARWOOD", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BIBRA+LAKE", from: context)!, 
//            Suburb.fetch(withIdent: "HAMILTON+HILL", from: context)!, 
//            Suburb.fetch(withIdent: "MUNSTER", from: context)!])
//        Suburb.fetch(withIdent: "STRATHAM+DOWNS", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "STRATTON", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "MIDVALE", from: context)!, 
//            Suburb.fetch(withIdent: "SWAN+VIEW", from: context)!, 
//            Suburb.fetch(withIdent: "MIDDLE+SWAN", from: context)!])
//        Suburb.fetch(withIdent: "SUBIACO", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "WEMBLEY", from: context)!, 
//            Suburb.fetch(withIdent: "JOLIMONT", from: context)!, 
//            Suburb.fetch(withIdent: "WEST+PERTH", from: context)!])
//        Suburb.fetch(withIdent: "SUCCESS", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BEELIAR", from: context)!, 
//            Suburb.fetch(withIdent: "JANDAKOT", from: context)!, 
//            Suburb.fetch(withIdent: "COCKBURN+CENTRAL", from: context)!])
//        Suburb.fetch(withIdent: "SWAN+VIEW", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "MIDVALE", from: context)!, 
//            Suburb.fetch(withIdent: "STRATTON", from: context)!])
//        Suburb.fetch(withIdent: "SWANBOURNE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "COTTESLOE", from: context)!, 
//            Suburb.fetch(withIdent: "NEDLANDS", from: context)!, 
//            Suburb.fetch(withIdent: "CLAREMONT", from: context)!])
//        Suburb.fetch(withIdent: "TAMMIN", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "THE+LAKES", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "WOOROLOO", from: context)!])
//        Suburb.fetch(withIdent: "THORNLIE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "GOSNELLS", from: context)!, 
//            Suburb.fetch(withIdent: "CANNING+VALE", from: context)!, 
//            Suburb.fetch(withIdent: "HUNTINGDALE", from: context)!, 
//            Suburb.fetch(withIdent: "LYNWOOD", from: context)!, 
//            Suburb.fetch(withIdent: "LANGFORD", from: context)!])
//        Suburb.fetch(withIdent: "TUART+HILL", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "NOLLAMARA", from: context)!, 
//            Suburb.fetch(withIdent: "OSBORNE+PARK", from: context)!, 
//            Suburb.fetch(withIdent: "BALCATTA", from: context)!, 
//            Suburb.fetch(withIdent: "YOKINE", from: context)!])
//        Suburb.fetch(withIdent: "UPPER+SWAN", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BULLSBROOK", from: context)!, 
//            Suburb.fetch(withIdent: "BASKERVILLE", from: context)!])
//        Suburb.fetch(withIdent: "VASSE", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "VICTORIA+PARK", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "EAST+VICTORIA+PARK", from: context)!, 
//            Suburb.fetch(withIdent: "BURSWOOD", from: context)!, 
//            Suburb.fetch(withIdent: "CARLISLE", from: context)!, 
//            Suburb.fetch(withIdent: "SOUTH+PERTH", from: context)!])
//        Suburb.fetch(withIdent: "WAIKIKI", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BALDIVIS", from: context)!, 
//            Suburb.fetch(withIdent: "WARNBRO", from: context)!, 
//            Suburb.fetch(withIdent: "ROCKINGHAM", from: context)!])
//        Suburb.fetch(withIdent: "WALKAWAY", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "WALPOLE", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "WANGARA", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "WANNEROO", from: context)!, 
//            Suburb.fetch(withIdent: "KINGSLEY", from: context)!, 
//            Suburb.fetch(withIdent: "MADELEY", from: context)!, 
//            Suburb.fetch(withIdent: "GNANGARA", from: context)!, 
//            Suburb.fetch(withIdent: "WOODVALE", from: context)!])
//        Suburb.fetch(withIdent: "WANNEROO", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "WOODVALE", from: context)!, 
//            Suburb.fetch(withIdent: "GNANGARA", from: context)!, 
//            Suburb.fetch(withIdent: "WANGARA", from: context)!])
//        Suburb.fetch(withIdent: "WARNBRO", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "PORT+KENNEDY", from: context)!, 
//            Suburb.fetch(withIdent: "BALDIVIS", from: context)!, 
//            Suburb.fetch(withIdent: "ROCKINGHAM", from: context)!, 
//            Suburb.fetch(withIdent: "WAIKIKI", from: context)!])
//        Suburb.fetch(withIdent: "WAROONA", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "WARWICK", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "CARINE", from: context)!, 
//            Suburb.fetch(withIdent: "GREENWOOD", from: context)!, 
//            Suburb.fetch(withIdent: "BALGA", from: context)!, 
//            Suburb.fetch(withIdent: "GIRRAWHEEN", from: context)!, 
//            Suburb.fetch(withIdent: "DUNCRAIG", from: context)!])
//        Suburb.fetch(withIdent: "WATERLOO", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "WATTLE+GROVE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "WELSHPOOL", from: context)!, 
//            Suburb.fetch(withIdent: "KEWDALE", from: context)!])
//        Suburb.fetch(withIdent: "WEDGEFIELD", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "WELLSTEAD", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "WELSHPOOL", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "BENTLEY", from: context)!, 
//            Suburb.fetch(withIdent: "CARLISLE", from: context)!, 
//            Suburb.fetch(withIdent: "CANNINGTON", from: context)!, 
//            Suburb.fetch(withIdent: "KEWDALE", from: context)!, 
//            Suburb.fetch(withIdent: "WATTLE+GROVE", from: context)!])
//        Suburb.fetch(withIdent: "WEMBLEY", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "GLENDALOUGH", from: context)!, 
//            Suburb.fetch(withIdent: "FLOREAT", from: context)!, 
//            Suburb.fetch(withIdent: "JOLIMONT", from: context)!, 
//            Suburb.fetch(withIdent: "SUBIACO", from: context)!])
//        Suburb.fetch(withIdent: "WEST+PERTH", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "NORTHBRIDGE", from: context)!, 
//            Suburb.fetch(withIdent: "NORTH+PERTH", from: context)!, 
//            Suburb.fetch(withIdent: "LEEDERVILLE", from: context)!, 
//            Suburb.fetch(withIdent: "SUBIACO", from: context)!, 
//            Suburb.fetch(withIdent: "PERTH", from: context)!])
//        Suburb.fetch(withIdent: "WEST+SWAN", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "HENLEY+BROOK", from: context)!, 
//            Suburb.fetch(withIdent: "BEECHBORO", from: context)!, 
//            Suburb.fetch(withIdent: "CAVERSHAM", from: context)!])
//        Suburb.fetch(withIdent: "WESTMINSTER", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "NOLLAMARA", from: context)!, 
//            Suburb.fetch(withIdent: "BALGA", from: context)!, 
//            Suburb.fetch(withIdent: "BALCATTA", from: context)!, 
//            Suburb.fetch(withIdent: "DIANELLA", from: context)!, 
//            Suburb.fetch(withIdent: "MIRRABOOKA", from: context)!])
//        Suburb.fetch(withIdent: "WILLETTON", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "RIVERTON", from: context)!, 
//            Suburb.fetch(withIdent: "CANNING+VALE", from: context)!, 
//            Suburb.fetch(withIdent: "LEEMING", from: context)!, 
//            Suburb.fetch(withIdent: "BULL+CREEK", from: context)!])
//        Suburb.fetch(withIdent: "WILLIAMS", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "WITCHCLIFFE", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "WOKALUP", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "WOODVALE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "WANNEROO", from: context)!, 
//            Suburb.fetch(withIdent: "KINGSLEY", from: context)!, 
//            Suburb.fetch(withIdent: "WANGARA", from: context)!, 
//            Suburb.fetch(withIdent: "PEARSALL", from: context)!, 
//            Suburb.fetch(withIdent: "BELDON", from: context)!, 
//            Suburb.fetch(withIdent: "PADBURY", from: context)!, 
//            Suburb.fetch(withIdent: "EDGEWATER", from: context)!])
//        Suburb.fetch(withIdent: "WOOROLOO", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "CHIDLOW", from: context)!, 
//            Suburb.fetch(withIdent: "GIDGEGANNUP", from: context)!, 
//            Suburb.fetch(withIdent: "THE+LAKES", from: context)!])
//        Suburb.fetch(withIdent: "WUBIN", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "YANCHEP", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "NOWERGUP", from: context)!])
//        Suburb.fetch(withIdent: "YOKINE", from: context)!.update(surround: [
//            Suburb.fetch(withIdent: "NOLLAMARA", from: context)!, 
//            Suburb.fetch(withIdent: "TUART+HILL", from: context)!, 
//            Suburb.fetch(withIdent: "DIANELLA", from: context)!])
//        Suburb.fetch(withIdent: "YORK", from: context)!.update(surround: [])
//        Suburb.fetch(withIdent: "YOUNG+SIDING", from: context)!.update(surround: [])
//
//        Suburb.fetch(withIdent: "ALBANY", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -35.02804965, longitude: 117.8840047), radius: 1573.90610196176, identifier: "Albany")
//        Suburb.fetch(withIdent: "ALEXANDER+HEIGHTS", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.82836385, longitude: 115.8647703), radius: 1453.986923114114, identifier: "Alexander Heights")
//        Suburb.fetch(withIdent: "ALFRED+COVE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.03142725, longitude: 115.81642865), radius: 945.7355234791532, identifier: "Alfred Cove")
//        Suburb.fetch(withIdent: "APPLECROSS", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.00792455, longitude: 115.8240983), radius: 3765.379020694398, identifier: "Applecross")
//        Suburb.fetch(withIdent: "ARMADALE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.1543973, longitude: 116.00551), radius: 3278.557712934411, identifier: "Armadale")
//        Suburb.fetch(withIdent: "ASCOT", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.934657, longitude: 115.93215955), radius: 2750.566777674629, identifier: "Ascot")
//        Suburb.fetch(withIdent: "ASHBY", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.73416085, longitude: 115.79696825), radius: 1061.614061445934, identifier: "Ashby")
//        Suburb.fetch(withIdent: "ATTADALE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.02421385, longitude: 115.80423185), radius: 1558.284918913194, identifier: "Attadale")
//        Suburb.fetch(withIdent: "AUGUSTA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -34.31556385, longitude: 115.1425925), radius: 4358.633558526561, identifier: "Augusta")
//        Suburb.fetch(withIdent: "AUSTRALIND", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.2828382, longitude: 115.7214756), radius: 4480.857619306817, identifier: "Australind")
//        Suburb.fetch(withIdent: "BALCATTA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.87318535, longitude: 115.8191167), radius: 2589.223624235091, identifier: "Balcatta")
//        Suburb.fetch(withIdent: "BALDIVIS", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.3310702, longitude: 115.83307815), radius: 8425.901487923555, identifier: "Baldivis")
//        Suburb.fetch(withIdent: "BALGA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.8535415, longitude: 115.8392384), radius: 1983.417474144342, identifier: "Balga")
//        Suburb.fetch(withIdent: "BALINGUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.77659885, longitude: 115.9866435), radius: 2121.922035001093, identifier: "Balingup")
//        Suburb.fetch(withIdent: "BALLAJURA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.83819555, longitude: 115.8972627), radius: 2713.796567461632, identifier: "Ballajura")
//        Suburb.fetch(withIdent: "BARRAGUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.53960485, longitude: 115.7891354), radius: 4037.17347212729, identifier: "Barragup")
//        Suburb.fetch(withIdent: "BASKERVILLE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.79942905, longitude: 116.0468801), radius: 4076.262218393228, identifier: "Baskerville")
//        Suburb.fetch(withIdent: "BASSENDEAN", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.9087788, longitude: 115.94447015), radius: 2368.976210836644, identifier: "Bassendean")
//        Suburb.fetch(withIdent: "BAYSWATER", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.91450055, longitude: 115.9163708), radius: 3101.36037532973, identifier: "Bayswater")
//        Suburb.fetch(withIdent: "BECKENHAM", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.023609, longitude: 115.9592289), radius: 2786.460198795866, identifier: "Beckenham")
//        Suburb.fetch(withIdent: "BEDFORDALE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.1730575, longitude: 116.0758633), radius: 7011.865507206554, identifier: "Bedfordale")
//        Suburb.fetch(withIdent: "BEECHBORO", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.86823125, longitude: 115.9361617), radius: 2056.172700693673, identifier: "Beechboro")
//        Suburb.fetch(withIdent: "BEELIAR", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.14319215, longitude: 115.8151809), radius: 3249.465771421401, identifier: "Beeliar")
//        Suburb.fetch(withIdent: "BELDON", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.77516455, longitude: 115.7658154), radius: 1533.57264750247, identifier: "Beldon")
//        Suburb.fetch(withIdent: "BELLEVUE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.90132665, longitude: 116.02550185), radius: 1526.146795807182, identifier: "Bellevue")
//        Suburb.fetch(withIdent: "BELMONT", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.9500118, longitude: 115.93117325), radius: 2070.297721044154, identifier: "Belmont")
//        Suburb.fetch(withIdent: "BENTLEY", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.0024123, longitude: 115.9097543), radius: 2502.956674272358, identifier: "Bentley")
//        Suburb.fetch(withIdent: "BERTRAM", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.24327365, longitude: 115.84316415), radius: 1628.585616431188, identifier: "Bertram")
//        Suburb.fetch(withIdent: "BIBRA+LAKE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.10161585, longitude: 115.821947), radius: 3304.175128679147, identifier: "Bibra Lake")
//        Suburb.fetch(withIdent: "BICTON", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.0133799, longitude: 115.7825753), radius: 2972.466631030548, identifier: "Bicton")
//        Suburb.fetch(withIdent: "BINNINGUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.15094255, longitude: 115.6935604), radius: 1842.769624523408, identifier: "Binningup")
//        Suburb.fetch(withIdent: "BOULDER", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -30.7746791, longitude: 121.4812236), radius: 2202.719869843229, identifier: "Boulder")
//        Suburb.fetch(withIdent: "BRENTWOOD", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.04333914999999, longitude: 115.8528061), radius: 919.6725599688455, identifier: "Brentwood")
//        Suburb.fetch(withIdent: "BRIDGETOWN", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.95584965, longitude: 116.1455397), radius: 7306.298012979628, identifier: "Bridgetown")
//        Suburb.fetch(withIdent: "BROOME", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -17.95856535, longitude: 122.2309613), radius: 2286.9851712738, identifier: "Broome")
//        Suburb.fetch(withIdent: "BRUNSWICK+JUNCTION", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.257902, longitude: 115.83712365), radius: 1236.722160869128, identifier: "Brunswick Junction")
//        Suburb.fetch(withIdent: "BULL+CREEK", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.05565969999999, longitude: 115.8620353), radius: 1592.471766542029, identifier: "Bull Creek")
//        Suburb.fetch(withIdent: "BULLSBROOK", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.67273485, longitude: 116.01629445), radius: 15140.1686356458, identifier: "Bullsbrook")
//        Suburb.fetch(withIdent: "BUNBURY", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.3194271, longitude: 115.64236795), radius: 2545.824477146175, identifier: "Bunbury")
//        Suburb.fetch(withIdent: "BURSWOOD", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.9552131, longitude: 115.8926384), radius: 2149.445097381114, identifier: "Burswood")
//        Suburb.fetch(withIdent: "BUSSELTON", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.6563158, longitude: 115.3495351), radius: 1851.873225629796, identifier: "Busselton")
//        Suburb.fetch(withIdent: "BUTLER", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.6441517, longitude: 115.70381485), radius: 2088.066137903278, identifier: "Butler")
//        Suburb.fetch(withIdent: "BYFORD", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.22195895, longitude: 116.00334075), radius: 4361.395562609715, identifier: "Byford")
//        Suburb.fetch(withIdent: "CANNING+VALE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.08486234999999, longitude: 115.9179504), radius: 4638.365227190488, identifier: "Canning Vale")
//        Suburb.fetch(withIdent: "CANNINGTON", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.01604895, longitude: 115.9367778), radius: 2086.668994687916, identifier: "Cannington")
//        Suburb.fetch(withIdent: "CAPEL", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.5538974, longitude: 115.5611327), radius: 2880.389778705271, identifier: "Capel")
//        Suburb.fetch(withIdent: "CARBUNUP+RIVER", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.70014125, longitude: 115.1909627), radius: 525.5830502557535, identifier: "Carbunup River")
//        Suburb.fetch(withIdent: "CARINE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.8521693, longitude: 115.78186905), radius: 2009.886769138929, identifier: "Carine")
//        Suburb.fetch(withIdent: "CARLISLE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.97987545, longitude: 115.9184303), radius: 1650.904680822901, identifier: "Carlisle")
//        Suburb.fetch(withIdent: "CARNARVON", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -24.88167515, longitude: 113.668679), radius: 2248.975943830666, identifier: "Carnarvon")
//        Suburb.fetch(withIdent: "CATABY", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -30.73601645, longitude: 115.53959785), radius: 1025.066819807871, identifier: "Cataby")
//        Suburb.fetch(withIdent: "CAVERSHAM", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.8780702, longitude: 115.98107495), radius: 3315.973292742418, identifier: "Caversham")
//        Suburb.fetch(withIdent: "CHIDLOW", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.8526448, longitude: 116.27137995), radius: 5888.004327463679, identifier: "Chidlow")
//        Suburb.fetch(withIdent: "CLAREMONT", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.9811842, longitude: 115.7808532), radius: 1922.733792462317, identifier: "Claremont")
//        Suburb.fetch(withIdent: "CLARKSON", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.6863854, longitude: 115.72620125), radius: 2249.329206558022, identifier: "Clarkson")
//        Suburb.fetch(withIdent: "CLOVERDALE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.962739, longitude: 115.9423859), radius: 1923.794283925432, identifier: "Cloverdale")
//        Suburb.fetch(withIdent: "COCKBURN+CENTRAL", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.1195162, longitude: 115.8474354), radius: 1548.742440333908, identifier: "Cockburn Central")
//        Suburb.fetch(withIdent: "COLLIE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.35238625, longitude: 116.1543881), radius: 4913.917185087589, identifier: "Collie")
//        Suburb.fetch(withIdent: "COMO", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.00293265000001, longitude: 115.87036745), radius: 2301.520373497137, identifier: "Como")
//        Suburb.fetch(withIdent: "COOLGARDIE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -30.95393235, longitude: 121.1583986), radius: 2569.201108568631, identifier: "Coolgardie")
//        Suburb.fetch(withIdent: "COOLUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.7364206, longitude: 115.8745221), radius: 1222.757328535163, identifier: "Coolup")
//        Suburb.fetch(withIdent: "COTTESLOE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.99897425, longitude: 115.7595078), radius: 2107.360012129554, identifier: "Cottesloe")
//        Suburb.fetch(withIdent: "COWARAMUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.8505889, longitude: 115.09517115), radius: 1911.891077770078, identifier: "Cowaramup")
//        Suburb.fetch(withIdent: "CUNDERDIN", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.6582572, longitude: 117.240617), radius: 2459.065065754535, identifier: "Cunderdin")
//        Suburb.fetch(withIdent: "CURRAMBINE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.73288375, longitude: 115.74661205), radius: 1563.786457156715, identifier: "Currambine")
//        Suburb.fetch(withIdent: "DALWALLINU", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -30.2783647, longitude: 116.65943), radius: 1490.395400697207, identifier: "Dalwallinu")
//        Suburb.fetch(withIdent: "DAMPIER", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -20.66172715, longitude: 116.71079395), radius: 1317.336350761154, identifier: "Dampier")
//        Suburb.fetch(withIdent: "DARDANUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.4031935, longitude: 115.7782499), radius: 2732.035418241679, identifier: "Dardanup")
//        Suburb.fetch(withIdent: "DENMARK", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -34.96826425, longitude: 117.3487739), radius: 3409.577827679667, identifier: "Denmark")
//        Suburb.fetch(withIdent: "DERBY", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -17.3232974, longitude: 123.65814865), radius: 4567.848353694514, identifier: "Derby")
//        Suburb.fetch(withIdent: "DIANELLA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.8888767, longitude: 115.87147), radius: 3187.719977641058, identifier: "Dianella")
//        Suburb.fetch(withIdent: "DONGARA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -29.23846205, longitude: 114.9384836), radius: 2798.262707155463, identifier: "Dongara")
//        Suburb.fetch(withIdent: "DONNYBROOK", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.5509912, longitude: 115.81390195), radius: 4962.625224954904, identifier: "Donnybrook")
//        Suburb.fetch(withIdent: "DOUBLEVIEW", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.89676505, longitude: 115.782099), radius: 1416.082463205294, identifier: "Doubleview")
//        Suburb.fetch(withIdent: "DUNCRAIG", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.8311543, longitude: 115.77862775), radius: 2358.543289155594, identifier: "Duncraig")
//        Suburb.fetch(withIdent: "DUNSBOROUGH", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.61362985, longitude: 115.09506805), radius: 3863.723224757028, identifier: "Dunsborough")
//        Suburb.fetch(withIdent: "DWELLINGUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.71118435, longitude: 116.0738041), radius: 3100.793165873244, identifier: "Dwellingup")
//        Suburb.fetch(withIdent: "EAST+FREMANTLE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.0348444, longitude: 115.7657296), radius: 1707.362599129907, identifier: "East Fremantle")
//        Suburb.fetch(withIdent: "EAST+PERTH", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.9541012, longitude: 115.87733485), radius: 1942.50913659989, identifier: "East Perth")
//        Suburb.fetch(withIdent: "EAST+VICTORIA+PARK", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.9884372, longitude: 115.90360015), radius: 1945.832468446549, identifier: "East Victoria Park")
//        Suburb.fetch(withIdent: "EATON", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.308628, longitude: 115.7155589), radius: 2736.520317151853, identifier: "Eaton")
//        Suburb.fetch(withIdent: "EDGEWATER", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.76343145, longitude: 115.7849432), radius: 1997.175858605476, identifier: "Edgewater")
//        Suburb.fetch(withIdent: "ELLENBROOK", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.76861605, longitude: 115.98904425), radius: 4427.262036115584, identifier: "Ellenbrook")
//        Suburb.fetch(withIdent: "ERSKINE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.567959, longitude: 115.6994505), radius: 2768.494907784985, identifier: "Erskine")
//        Suburb.fetch(withIdent: "ESPERANCE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.86124105, longitude: 121.8914014), radius: 1320.401513564613, identifier: "Esperance")
//        Suburb.fetch(withIdent: "EXMOUTH", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -21.9391528, longitude: 114.12688045), radius: 2556.784773916319, identifier: "Exmouth")
//        Suburb.fetch(withIdent: "FALCON", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.5850175, longitude: 115.66885325), radius: 3456.925616963387, identifier: "Falcon")
//        Suburb.fetch(withIdent: "FITZROY+CROSSING", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -18.187136, longitude: 125.58458765), radius: 3970.805589233481, identifier: "Fitzroy Crossing")
//        Suburb.fetch(withIdent: "FLOREAT", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.93916045, longitude: 115.79032825), radius: 1854.260327056251, identifier: "Floreat")
//        Suburb.fetch(withIdent: "FORRESTDALE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.14882155, longitude: 115.93639515), radius: 5133.28858237263, identifier: "Forrestdale")
//        Suburb.fetch(withIdent: "FORRESTFIELD", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.98214785, longitude: 116.0103657), radius: 4016.561466243741, identifier: "Forrestfield")
//        Suburb.fetch(withIdent: "FREMANTLE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.05164455000001, longitude: 115.75602555), radius: 2633.876050529597, identifier: "Fremantle")
//        Suburb.fetch(withIdent: "GELORUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.4224896, longitude: 115.6376484), radius: 4648.888601330075, identifier: "Gelorup")
//        Suburb.fetch(withIdent: "GERALDTON", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -28.7763845, longitude: 114.61394495), radius: 1814.330154176945, identifier: "Geraldton")
//        Suburb.fetch(withIdent: "GIDGEGANNUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.7546097, longitude: 116.1934269), radius: 13606.12659043142, identifier: "Gidgegannup")
//        Suburb.fetch(withIdent: "GIRRAWHEEN", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.84116365, longitude: 115.8383115), radius: 1800.240665376419, identifier: "Girrawheen")
//        Suburb.fetch(withIdent: "GLEN+FORREST", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.92208435, longitude: 116.10665295), radius: 3121.939824486588, identifier: "Glen Forrest")
//        Suburb.fetch(withIdent: "GLENDALOUGH", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.91978535, longitude: 115.8199632), radius: 785.9113272968594, identifier: "Glendalough")
//        Suburb.fetch(withIdent: "GLENFIELD", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -28.68321575, longitude: 114.6133444), radius: 970.3580777442303, identifier: "Glenfield")
//        Suburb.fetch(withIdent: "GNANGARA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.7756694, longitude: 115.86225785), radius: 2951.810294674217, identifier: "Gnangara")
//        Suburb.fetch(withIdent: "GOLDEN+BAY", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.42543475, longitude: 115.7609059), radius: 1581.707967926475, identifier: "Golden Bay")
//        Suburb.fetch(withIdent: "GOSNELLS", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.0864183, longitude: 115.99513725), radius: 3669.816639614342, identifier: "Gosnells")
//        Suburb.fetch(withIdent: "GRACETOWN", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.8671167, longitude: 114.98770825), radius: 483.0378154380061, identifier: "Gracetown")
//        Suburb.fetch(withIdent: "GREENBUSHES", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.84112895, longitude: 116.0620158), radius: 1580.815390324022, identifier: "Greenbushes")
//        Suburb.fetch(withIdent: "GREENOUGH", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -28.94233915, longitude: 114.7448691), radius: 926.2009879765099, identifier: "Greenough")
//        Suburb.fetch(withIdent: "GREENWOOD", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.82775065, longitude: 115.80235375), radius: 2155.892556701776, identifier: "Greenwood")
//        Suburb.fetch(withIdent: "GUILDFORD", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.8970783, longitude: 115.9735031), radius: 1821.905631133466, identifier: "Guildford")
//        Suburb.fetch(withIdent: "GWELUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.87044875, longitude: 115.79438055), radius: 1493.940746037513, identifier: "Gwelup")
//        Suburb.fetch(withIdent: "HALLS+HEAD", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.54261169999999, longitude: 115.69324305), radius: 3472.151656775684, identifier: "Halls Head")
//        Suburb.fetch(withIdent: "HAMILTON+HILL", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.08561015, longitude: 115.7795906), radius: 2167.805103319805, identifier: "Hamilton Hill")
//        Suburb.fetch(withIdent: "HARVEY", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.0743829, longitude: 115.9165496), radius: 8144.524235022252, identifier: "Harvey")
//        Suburb.fetch(withIdent: "HENLEY+BROOK", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.8117675, longitude: 115.98712035), radius: 3268.531846646007, identifier: "Henley Brook")
//        Suburb.fetch(withIdent: "HERNE+HILL", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.83378605, longitude: 116.0294015), radius: 3523.006169178107, identifier: "Herne Hill")
//        Suburb.fetch(withIdent: "HIGH+WYCOMBE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.9450393, longitude: 115.99969905), radius: 3063.303246387347, identifier: "High Wycombe")
//        Suburb.fetch(withIdent: "HIGHGATE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.9402722, longitude: 115.8703894), radius: 664.0368167643921, identifier: "Highgate")
//        Suburb.fetch(withIdent: "HILLARYS", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.81116985, longitude: 115.7442987), radius: 2350.293034132062, identifier: "Hillarys")
//        Suburb.fetch(withIdent: "HUNTINGDALE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.0826607, longitude: 115.9652982), radius: 2245.620033708984, identifier: "Huntingdale")
//        Suburb.fetch(withIdent: "INNALOO", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.89334325, longitude: 115.79609515), radius: 1482.89666320318, identifier: "Innaloo")
//        Suburb.fetch(withIdent: "JANDAKOT", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.1049588, longitude: 115.8748934), radius: 3544.764854963421, identifier: "Jandakot")
//        Suburb.fetch(withIdent: "JOLIMONT", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.94611295, longitude: 115.81014205), radius: 729.448294699774, identifier: "Jolimont")
//        Suburb.fetch(withIdent: "JOONDALUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.7398789, longitude: 115.770999), radius: 3249.135206776392, identifier: "Joondalup")
//        Suburb.fetch(withIdent: "JURIEN+BAY", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -30.3055658, longitude: 115.04145045), radius: 3075.9887805396, identifier: "Jurien Bay")
//        Suburb.fetch(withIdent: "KALAMUNDA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.9742143, longitude: 116.0588722), radius: 3219.37486398133, identifier: "Kalamunda")
//        Suburb.fetch(withIdent: "KALGOORLIE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -30.7518356, longitude: 121.4686605), radius: 2184.859380044899, identifier: "Kalgoorlie")
//        Suburb.fetch(withIdent: "KAMBALDA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.90999005, longitude: 116.1682298), radius: 253.6176002373917, identifier: "Kambalda")
//        Suburb.fetch(withIdent: "KAMBALDA+WEST", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.21276485, longitude: 121.62292955), radius: 1680.655568515486, identifier: "Kambalda West")
//        Suburb.fetch(withIdent: "KARAWARA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.0080312, longitude: 115.88089535), radius: 867.3987193214481, identifier: "Karawara")
//        Suburb.fetch(withIdent: "KARDINYA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.06662475, longitude: 115.8162487), radius: 1681.253759464894, identifier: "Kardinya")
//        Suburb.fetch(withIdent: "KARRAGULLEN", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.103708, longitude: 116.13940475), radius: 6221.948496331085, identifier: "Karragullen")
//        Suburb.fetch(withIdent: "KARRATHA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -20.73473595, longitude: 116.84577935), radius: 635.1457051951705, identifier: "Karratha")
//        Suburb.fetch(withIdent: "KARRIDALE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -34.20032825, longitude: 115.09953585), radius: 548.552686508084, identifier: "Karridale")
//        Suburb.fetch(withIdent: "KARRINYUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.8713889, longitude: 115.7754013), radius: 2124.708942504975, identifier: "Karrinyup")
//        Suburb.fetch(withIdent: "KELLERBERRIN", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.6290236, longitude: 117.72325755), radius: 3028.134146225397, identifier: "Kellerberrin")
//        Suburb.fetch(withIdent: "KELMSCOTT", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.11502005, longitude: 116.0243659), radius: 3680.562936319275, identifier: "Kelmscott")
//        Suburb.fetch(withIdent: "KEWDALE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.9803684, longitude: 115.9527213), radius: 3658.012978823361, identifier: "Kewdale")
//        Suburb.fetch(withIdent: "KIARA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.8817923, longitude: 115.93907555), radius: 875.7568986571416, identifier: "Kiara")
//        Suburb.fetch(withIdent: "KINGSLEY", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.81002445, longitude: 115.8015035), radius: 2264.094165341375, identifier: "Kingsley")
//        Suburb.fetch(withIdent: "KIRUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.71125175, longitude: 115.890867), radius: 1444.053559567915, identifier: "Kirup")
//        Suburb.fetch(withIdent: "KOJONUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.83259905, longitude: 117.15076815), radius: 3632.255595657766, identifier: "Kojonup")
//        Suburb.fetch(withIdent: "KOONDOOLA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.84156405, longitude: 115.86639875), radius: 1520.924652242389, identifier: "Koondoola")
//        Suburb.fetch(withIdent: "KUNUNURRA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -15.77336425, longitude: 128.7304442), radius: 4908.996661379133, identifier: "Kununurra")
//        Suburb.fetch(withIdent: "KWINANA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.256473, longitude: 115.836206), radius: 5906.146155796293, identifier: "Kwinana")
//        Suburb.fetch(withIdent: "LAKELANDS", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.47165645, longitude: 115.77293275), radius: 2251.36473544093, identifier: "Lakelands")
//        Suburb.fetch(withIdent: "LANGFORD", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.04186555, longitude: 115.94167425), radius: 1856.55339001487, identifier: "Langford")
//        Suburb.fetch(withIdent: "LEDA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.2683227, longitude: 115.79886905), radius: 2504.506393435013, identifier: "Leda")
//        Suburb.fetch(withIdent: "LEEDERVILLE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.93330195, longitude: 115.8387725), radius: 1182.171588895963, identifier: "Leederville")
//        Suburb.fetch(withIdent: "LEEMING", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.07615775, longitude: 115.8721724), radius: 2541.947693388577, identifier: "Leeming")
//        Suburb.fetch(withIdent: "LESMURDIE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.0078675, longitude: 116.04513365), radius: 3493.133884103253, identifier: "Lesmurdie")
//        Suburb.fetch(withIdent: "LEXIA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.77881415, longitude: 115.92003895), radius: 3991.031385971921, identifier: "Lexia")
//        Suburb.fetch(withIdent: "LYNWOOD", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.040423, longitude: 115.9282721), radius: 1309.642022687803, identifier: "Lynwood")
//        Suburb.fetch(withIdent: "MADDINGTON", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.04410465, longitude: 115.9931352), radius: 3118.044039529208, identifier: "Maddington")
//        Suburb.fetch(withIdent: "MADELEY", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.81030785, longitude: 115.82699535), radius: 1512.508189367361, identifier: "Madeley")
//        Suburb.fetch(withIdent: "MAIDA+VALE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.95440625, longitude: 116.02154425), radius: 2879.321564707824, identifier: "Maida Vale")
//        Suburb.fetch(withIdent: "MALAGA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.8566907, longitude: 115.8975228), radius: 2284.79781779385, identifier: "Malaga")
//        Suburb.fetch(withIdent: "MANDURAH", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.5232397, longitude: 115.7305833), radius: 2936.386422971622, identifier: "Mandurah")
//        Suburb.fetch(withIdent: "MANJIMUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -34.24693355, longitude: 116.1449094), radius: 5960.287505032233, identifier: "Manjimup")
//        Suburb.fetch(withIdent: "MANNING", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.01286105, longitude: 115.8698812), radius: 1037.880204352374, identifier: "Manning")
//        Suburb.fetch(withIdent: "MANYPEAKS", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -34.83834775, longitude: 118.17283705), radius: 426.137066784295, identifier: "Manypeaks")
//        Suburb.fetch(withIdent: "MARGARET+RIVER", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.9665452, longitude: 115.05296965), radius: 7324.818657584762, identifier: "Margaret River")
//        Suburb.fetch(withIdent: "MEADOW+SPRINGS", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.4941297, longitude: 115.753596), radius: 2234.519933962438, identifier: "Meadow Springs")
//        Suburb.fetch(withIdent: "MEEKATHARRA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -26.5962488, longitude: 118.4982007), radius: 2183.334364274947, identifier: "Meekatharra")
//        Suburb.fetch(withIdent: "MERRIWA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.6653748, longitude: 115.7130079), radius: 1454.671060098581, identifier: "Merriwa")
//        Suburb.fetch(withIdent: "MIDDLE+SWAN", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.8615613, longitude: 116.0226628), radius: 3274.751605018252, identifier: "Middle Swan")
//        Suburb.fetch(withIdent: "MIDVALE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.8847495, longitude: 116.0286391), radius: 1628.721468299763, identifier: "Midvale")
//        Suburb.fetch(withIdent: "MINDARIE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.6887518, longitude: 115.70744545), radius: 2190.259864575325, identifier: "Mindarie")
//        Suburb.fetch(withIdent: "MIRRABOOKA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.86177395, longitude: 115.8671093), radius: 1871.946487194665, identifier: "Mirrabooka")
//        Suburb.fetch(withIdent: "MOONYOONOOKA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -28.78111495, longitude: 114.71301145), radius: 1669.924204768685, identifier: "Moonyoonooka")
//        Suburb.fetch(withIdent: "MOORA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -30.6494969, longitude: 116.0000132), radius: 3865.014434244244, identifier: "Moora")
//        Suburb.fetch(withIdent: "MORLEY", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.88993885, longitude: 115.9065775), radius: 3255.069826498753, identifier: "Morley")
//        Suburb.fetch(withIdent: "MOSMAN+PARK", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.0142228, longitude: 115.7663681), radius: 1870.522531482728, identifier: "Mosman Park")
//        Suburb.fetch(withIdent: "MOUNT+BARKER", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -34.63465625, longitude: 117.6621471), radius: 4426.562558539707, identifier: "Mount Barker")
//        Suburb.fetch(withIdent: "MT+LAWLEY", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.9310061, longitude: 115.8764102), radius: 2032.840686117208, identifier: "Mt Lawley")
//        Suburb.fetch(withIdent: "MT+PLEASANT", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.0261584, longitude: 115.85000005), radius: 1925.699495583253, identifier: "Mt Pleasant")
//        Suburb.fetch(withIdent: "MULLALOO", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.7794819, longitude: 115.743701), radius: 1484.925235889495, identifier: "Mullaloo")
//        Suburb.fetch(withIdent: "MULLALYUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.74518135, longitude: 115.9468446), radius: 553.5868794259939, identifier: "Mullalyup")
//        Suburb.fetch(withIdent: "MUNDARING", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.9202896, longitude: 116.16682735), radius: 5328.078386529472, identifier: "Mundaring")
//        Suburb.fetch(withIdent: "MUNDIJONG", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.2896832, longitude: 115.9823053), radius: 3679.217608465437, identifier: "Mundijong")
//        Suburb.fetch(withIdent: "MUNSTER", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.13777495, longitude: 115.7795515), radius: 4227.981025706879, identifier: "Munster")
//        Suburb.fetch(withIdent: "MURDOCH", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.06909705, longitude: 115.83731105), radius: 1732.205456938468, identifier: "Murdoch")
//        Suburb.fetch(withIdent: "MYALUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.10328725, longitude: 115.6943195), radius: 725.1215703427597, identifier: "Myalup")
//        Suburb.fetch(withIdent: "MYAREE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.0418263, longitude: 115.81549795), radius: 871.3453299106646, identifier: "Myaree")
//        Suburb.fetch(withIdent: "NARROGIN", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.93675265, longitude: 117.17281745), radius: 3479.681113541495, identifier: "Narrogin")
//        Suburb.fetch(withIdent: "NAVAL+BASE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.1954818, longitude: 115.7810715), radius: 2118.775698105462, identifier: "Naval Base")
//        Suburb.fetch(withIdent: "NEDLANDS", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.9789514, longitude: 115.80325775), radius: 2144.38390006284, identifier: "Nedlands")
//        Suburb.fetch(withIdent: "NEERABUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.69095965, longitude: 115.77549945), radius: 5435.961615091287, identifier: "Neerabup")
//        Suburb.fetch(withIdent: "NEWMAN", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -23.35158405, longitude: 119.7324723), radius: 3340.027071658668, identifier: "Newman")
//        Suburb.fetch(withIdent: "NOLLAMARA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.88011665, longitude: 115.84545925), radius: 1664.02219423309, identifier: "Nollamara")
//        Suburb.fetch(withIdent: "NORANDA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.87253805, longitude: 115.89811935), radius: 2088.057160376768, identifier: "Noranda")
//        Suburb.fetch(withIdent: "NORSEMAN", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.1982029, longitude: 121.77925615), radius: 2842.576781069468, identifier: "Norseman")
//        Suburb.fetch(withIdent: "NORTH+DANDALUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.51602135, longitude: 115.96382335), radius: 1286.590083280897, identifier: "North Dandalup")
//        Suburb.fetch(withIdent: "NORTH+FREMANTLE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.03761305, longitude: 115.7424194), radius: 2507.734358620461, identifier: "North Fremantle")
//        Suburb.fetch(withIdent: "NORTH+PERTH", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.92519135, longitude: 115.8541176), radius: 1566.201529964464, identifier: "North Perth")
//        Suburb.fetch(withIdent: "NORTH+YUNDERUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.57456550000001, longitude: 115.7902059), radius: 2435.517753896026, identifier: "North Yunderup")
//        Suburb.fetch(withIdent: "NORTHAM", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.64801785, longitude: 116.66137975), radius: 5052.873570607602, identifier: "Northam")
//        Suburb.fetch(withIdent: "NORTHBRIDGE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.94604805, longitude: 115.8558464), radius: 662.1071599894572, identifier: "Northbridge")
//        Suburb.fetch(withIdent: "NORTHCLIFFE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -34.63081765, longitude: 116.1211774), radius: 948.5483139770324, identifier: "Northcliffe")
//        Suburb.fetch(withIdent: "NOWERGUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.63544275, longitude: 115.7556387), radius: 5961.364121700378, identifier: "Nowergup")
//        Suburb.fetch(withIdent: "O'CONNOR", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.0603726, longitude: 115.79151315), radius: 1286.38514890737, identifier: "O'connor")
//        Suburb.fetch(withIdent: "OCEAN+REEF", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.75916435, longitude: 115.73746435), radius: 2266.555304937713, identifier: "Ocean Reef")
//        Suburb.fetch(withIdent: "OSBORNE+PARK", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.9034569, longitude: 115.8144778), radius: 2077.539609125864, identifier: "Osborne Park")
//        Suburb.fetch(withIdent: "PADBURY", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.80658585, longitude: 115.76857075), radius: 1993.053436103027, identifier: "Padbury")
//        Suburb.fetch(withIdent: "PALMYRA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.0445076, longitude: 115.7849535), radius: 1414.180223069004, identifier: "Palmyra")
//        Suburb.fetch(withIdent: "PARMELIA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.24598109999999, longitude: 115.8296421), radius: 2003.761113739106, identifier: "Parmelia")
//        Suburb.fetch(withIdent: "PEARSALL", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.78210285, longitude: 115.8189128), radius: 1116.142274499887, identifier: "Pearsall")
//        Suburb.fetch(withIdent: "PEMBERTON", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -34.43942715, longitude: 116.05179625), radius: 3351.530659217884, identifier: "Pemberton")
//        Suburb.fetch(withIdent: "PERTH", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.1376277, longitude: 115.95332235), radius: 65409.77382109817, identifier: "Perth")
//        Suburb.fetch(withIdent: "PICTON", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.34424319999999, longitude: 115.697647), radius: 2362.838701882918, identifier: "Picton")
//        Suburb.fetch(withIdent: "PINJARRA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.613647, longitude: 115.8787267), radius: 4598.889144134318, identifier: "Pinjarra")
//        Suburb.fetch(withIdent: "PORT+HEDLAND", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -20.3413556, longitude: 118.6296193), radius: 8338.199075855062, identifier: "Port Hedland")
//        Suburb.fetch(withIdent: "PORT+KENNEDY", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.37125924999999, longitude: 115.75057415), radius: 4334.288363615293, identifier: "Port Kennedy")
//        Suburb.fetch(withIdent: "PRESTON+BEACH", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.87865705, longitude: 115.6578731), radius: 992.0621474760089, identifier: "Preston Beach")
//        Suburb.fetch(withIdent: "QUINNS+ROCKS", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.66520975, longitude: 115.6981615), radius: 1855.482217929705, identifier: "Quinns Rocks")
//        Suburb.fetch(withIdent: "RAVENSTHORPE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.58197939999999, longitude: 120.05685335), radius: 2374.707216832294, identifier: "Ravensthorpe")
//        Suburb.fetch(withIdent: "REDCLIFFE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.9387127, longitude: 115.9457142), radius: 2165.897195789603, identifier: "Redcliffe")
//        Suburb.fetch(withIdent: "REDMOND", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -34.8867841, longitude: 117.69186905), radius: 471.0026213607811, identifier: "Redmond")
//        Suburb.fetch(withIdent: "RIDGEWOOD", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.66130275, longitude: 115.72242585), radius: 1394.650603403082, identifier: "Ridgewood")
//        Suburb.fetch(withIdent: "RIVERTON", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.0335219, longitude: 115.8978514), radius: 1965.665862491248, identifier: "Riverton")
//        Suburb.fetch(withIdent: "RIVERVALE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.96135545, longitude: 115.91413575), radius: 1963.770528906951, identifier: "Rivervale")
//        Suburb.fetch(withIdent: "ROCKINGHAM", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.2800622, longitude: 115.7437454), radius: 3759.700720956108, identifier: "Rockingham")
//        Suburb.fetch(withIdent: "ROLEYSTONE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.1178056, longitude: 116.08750625), radius: 6335.787828808805, identifier: "Roleystone")
//        Suburb.fetch(withIdent: "ROSA+BROOK", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.9447943, longitude: 115.18882275), radius: 373.830562857218, identifier: "Rosa Brook")
//        Suburb.fetch(withIdent: "ROTTNEST+ISLAND", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.967745, longitude: 115.57932015), radius: 21316.25097403215, identifier: "Rottnest Island")
//        Suburb.fetch(withIdent: "SAWYERS+VALLEY", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.96291745, longitude: 116.2452808), radius: 13461.38782116114, identifier: "Sawyers Valley")
//        Suburb.fetch(withIdent: "SCARBOROUGH", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.8958505, longitude: 115.7655447), radius: 1707.521534318754, identifier: "Scarborough")
//        Suburb.fetch(withIdent: "SECRET+HARBOUR", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.40621815, longitude: 115.75660685), radius: 2074.586258846753, identifier: "Secret Harbour")
//        Suburb.fetch(withIdent: "SERPENTINE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.38693385, longitude: 116.0096776), radius: 10704.38337830657, identifier: "Serpentine")
//        Suburb.fetch(withIdent: "SEVILLE+GROVE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.1343267, longitude: 115.9899172), radius: 2053.711070541225, identifier: "Seville Grove")
//        Suburb.fetch(withIdent: "SINGLETON", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.44497685, longitude: 115.7593735), radius: 1622.838622896792, identifier: "Singleton")
//        Suburb.fetch(withIdent: "SORRENTO", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.827495, longitude: 115.75319345), radius: 1587.266466537333, identifier: "Sorrento")
//        Suburb.fetch(withIdent: "SOUTH+FREMANTLE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.07215605, longitude: 115.751942), radius: 1415.346946242568, identifier: "South Fremantle")
//        Suburb.fetch(withIdent: "SOUTH+HEDLAND", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -20.40483265, longitude: 118.60021705), radius: 4090.664779510933, identifier: "South Hedland")
//        Suburb.fetch(withIdent: "SOUTH+LAKE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.10709495, longitude: 115.8386315), radius: 1836.486808829694, identifier: "South Lake")
//        Suburb.fetch(withIdent: "SOUTH+PERTH", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.9736517, longitude: 115.85222555), radius: 3375.846401096533, identifier: "South Perth")
//        Suburb.fetch(withIdent: "SOUTH+YUNDERUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.60954185, longitude: 115.73716835), radius: 8391.007762016492, identifier: "South Yunderup")
//        Suburb.fetch(withIdent: "SOUTHERN+RIVER", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.1069557, longitude: 115.9590999), radius: 3781.205280644967, identifier: "Southern River")
//        Suburb.fetch(withIdent: "SPEARWOOD", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.10692605, longitude: 115.781502), radius: 2200.164700540056, identifier: "Spearwood")
//        Suburb.fetch(withIdent: "STRATHAM+DOWNS", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.46963635, longitude: 115.5989831), radius: 5734.167216046876, identifier: "Stratham Downs")
//        Suburb.fetch(withIdent: "STRATTON", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.86859645, longitude: 116.03971265), radius: 1438.915570991721, identifier: "Stratton")
//        Suburb.fetch(withIdent: "SUBIACO", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.9488284, longitude: 115.8248711), radius: 1824.282671680173, identifier: "Subiaco")
//        Suburb.fetch(withIdent: "SUCCESS", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.14269575, longitude: 115.8482496), radius: 2251.046723175141, identifier: "Success")
//        Suburb.fetch(withIdent: "SWAN+VIEW", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.88213755, longitude: 116.05211195), radius: 2373.363233289355, identifier: "Swan View")
//        Suburb.fetch(withIdent: "SWANBOURNE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.9681448, longitude: 115.7652779), radius: 2156.45182828018, identifier: "Swanbourne")
//        Suburb.fetch(withIdent: "TAMMIN", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.63962915, longitude: 117.4976522), radius: 2295.713201912076, identifier: "Tammin")
//        Suburb.fetch(withIdent: "THE+LAKES", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.88516925, longitude: 116.361369), radius: 7283.648109394183, identifier: "The Lakes")
//        Suburb.fetch(withIdent: "THORNLIE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.06137905, longitude: 115.9533299), radius: 3338.956282561506, identifier: "Thornlie")
//        Suburb.fetch(withIdent: "TUART+HILL", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.8973754, longitude: 115.83628345), radius: 1201.81032806, identifier: "Tuart Hill")
//        Suburb.fetch(withIdent: "UPPER+SWAN", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.7676845, longitude: 116.0410153), radius: 3864.511723625275, identifier: "Upper Swan")
//        Suburb.fetch(withIdent: "VASSE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.7019668, longitude: 115.2752671), radius: 5741.80482489824, identifier: "Vasse")
//        Suburb.fetch(withIdent: "VICTORIA+PARK", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.97592725, longitude: 115.89156215), radius: 1802.300743664083, identifier: "Victoria Park")
//        Suburb.fetch(withIdent: "WAIKIKI", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.31486785, longitude: 115.7664812), radius: 3120.246274507713, identifier: "Waikiki")
//        Suburb.fetch(withIdent: "WALKAWAY", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -28.9391973, longitude: 114.80277585), radius: 1173.314291112846, identifier: "Walkaway")
//        Suburb.fetch(withIdent: "WALPOLE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -34.9702522, longitude: 116.74584085), radius: 5324.554810710946, identifier: "Walpole")
//        Suburb.fetch(withIdent: "WANGARA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.79294715, longitude: 115.8333234), radius: 2546.669735294605, identifier: "Wangara")
//        Suburb.fetch(withIdent: "WANNEROO", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.75294855, longitude: 115.8103056), radius: 5321.766557214352, identifier: "Wanneroo")
//        Suburb.fetch(withIdent: "WARNBRO", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.3382154, longitude: 115.76693225), radius: 2736.413518749354, identifier: "Warnbro")
//        Suburb.fetch(withIdent: "WAROONA", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.84062995, longitude: 115.9246073), radius: 2928.973954233834, identifier: "Waroona")
//        Suburb.fetch(withIdent: "WARWICK", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.83969685, longitude: 115.8083664), radius: 1539.246587361179, identifier: "Warwick")
//        Suburb.fetch(withIdent: "WATERLOO", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.32484165, longitude: 115.76165685), radius: 4393.275406506251, identifier: "Waterloo")
//        Suburb.fetch(withIdent: "WATTLE+GROVE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.00580645, longitude: 116.0027627), radius: 3108.448798590592, identifier: "Wattle Grove")
//        Suburb.fetch(withIdent: "WEDGEFIELD", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -20.36080445, longitude: 118.6018088), radius: 3904.6594056913, identifier: "Wedgefield")
//        Suburb.fetch(withIdent: "WELLSTEAD", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -34.49616045, longitude: 118.6087137), radius: 1032.847344005085, identifier: "Wellstead")
//        Suburb.fetch(withIdent: "WELSHPOOL", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.9929686, longitude: 115.9466941), radius: 3229.496692073706, identifier: "Welshpool")
//        Suburb.fetch(withIdent: "WEMBLEY", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.93242715, longitude: 115.81873335), radius: 1788.962004777531, identifier: "Wembley")
//        Suburb.fetch(withIdent: "WEST+PERTH", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.94677705, longitude: 115.845854), radius: 1645.894921042381, identifier: "West Perth")
//        Suburb.fetch(withIdent: "WEST+SWAN", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.8455963, longitude: 115.9943575), radius: 2463.982378407992, identifier: "West Swan")
//        Suburb.fetch(withIdent: "WESTMINSTER", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.8665269, longitude: 115.84065945), radius: 1583.425336608117, identifier: "Westminster")
//        Suburb.fetch(withIdent: "WILLETTON", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -32.05294425, longitude: 115.8879202), radius: 2278.845295442901, identifier: "Willetton")
//        Suburb.fetch(withIdent: "WILLIAMS", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.0229192, longitude: 116.89589845), radius: 2801.917772716558, identifier: "Williams")
//        Suburb.fetch(withIdent: "WITCHCLIFFE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -34.0251622, longitude: 115.09568925), radius: 708.8021417547834, identifier: "Witchcliffe")
//        Suburb.fetch(withIdent: "WOKALUP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -33.1111066, longitude: 115.87795115), radius: 976.6620235617644, identifier: "Wokalup")
//        Suburb.fetch(withIdent: "WOODVALE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.78865755, longitude: 115.7982928), radius: 2369.965671959204, identifier: "Woodvale")
//        Suburb.fetch(withIdent: "WOOROLOO", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.8086247, longitude: 116.32629825), radius: 6107.340207158284, identifier: "Wooroloo")
//        Suburb.fetch(withIdent: "WUBIN", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -30.1065302, longitude: 116.6299665), radius: 1118.556148978515, identifier: "Wubin")
//        Suburb.fetch(withIdent: "YANCHEP", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.53603775, longitude: 115.72935055), radius: 14943.24460231528, identifier: "Yanchep")
//        Suburb.fetch(withIdent: "YOKINE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.90069, longitude: 115.8549084), radius: 2084.006973032192, identifier: "Yokine")
//        Suburb.fetch(withIdent: "YORK", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.87461655, longitude: 116.77644955), radius: 4383.679302379159, identifier: "York")
//        Suburb.fetch(withIdent: "YOUNG+SIDING", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -35.01272585, longitude: 117.5217347), radius: 375.1964817343134, identifier: "Young Siding")
//        Suburb.fetch(withIdent: "BANKSIA+GROVE", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: -31.7005632, longitude: 115.80649235), radius: 2025.216364708562, identifier: "Banksia Grove")
//}
//
//    fileprivate var buildFormatter: String {
////        let regions: [Region] = region.allObjects as! [Region]
//        let regionStr = region?.reduce(""){ (string: String, region: Region) -> String in
//            return (string.isEmpty ? string : string + ", ") + "Region.fetch(withIdent: \(region.ident), from: context)!"
//        } ?? ""
//        return "Suburb.update(from: [SIElement(ident: \"\(ident)\", value: \"\(name)\")], withRegions: [\(regionStr)], to: context)"
//    }
//
//    fileprivate var surroundFormatter: String {
////        let surround: [Suburb] = self.surround.allObjects as! [Suburb]
//        let surroundStr = surround?.reduce(""){ (string: String, suburb: Suburb) -> String in
//            return (string.isEmpty ? string : string + ", ") + suburb.fetchFormatter + "!"
//        } ?? ""
//        return "\(fetchFormatter)!.update(surround: [\(surroundStr)])"
//    }
//
//    fileprivate var fetchFormatter: String {
//        return "Suburb.fetch(withIdent: \"\(ident)\", from: context)"
//    }
//
//    fileprivate func update(surround surroundList: [Suburb]) {
//        objc_sync_enter(Static.lock)
//        for s in surroundList {
//            if s != self && !(surround?.contains(s) ?? false) {
//                mutableSetValue(forKey: "surround").add(s)
//            }
//        }
//        do {
//            try self.managedObjectContext!.save()
//        } catch {
//            print("Error during update of Suburb: \(error)")
//        }
//        objc_sync_exit(Static.lock)
//    }
//
//    var updateLocationString: String {
//        guard latitude != nil && longitude != nil else {
//            return ""
//        }
//        guard radius != nil else {
//            return "Suburb.fetch(withIdent: \"\(ident)\", from: context)?.location = CLLocation(latitude: \(String(describing: latitude)), longitude: \(String(describing: longitude)))"
//        }
//        return "Suburb.fetch(withIdent: \"\(ident)\", from: context)?.geographicRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: \(String(describing: latitude)), longitude: \(String(describing: longitude))), radius: \(String(describing: radius)), identifier: \"\(name)\")"
//    }
//
//    class func consolidate(_ context: NSManagedObjectContext) -> Bool {
//        objc_sync_enter(Static.lock)
//        var consolidated = false;
//        var previous: Suburb?
//        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Suburb")
//        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
//        for suburb: Suburb in try! context.fetch(request) as! [Suburb] {
//            if previous != nil && (previous!.name == suburb.name) {
//                print("Conflict detected, \(suburb.description)")
//                if (previous?.region?.count ?? 0) == 0 || previous!.region == suburb.region {
//                    let previousStation = previous!.mutableSetValue(forKey: "station")
//                    let currentStation = suburb.mutableSetValue(forKey: "station")
//                    let station = Array<Station>(previous!.station ?? [])
//                    currentStation.addObjects(from: station)
//                    previousStation.removeAllObjects()
//                    context.delete(previous!)
//                    consolidated = true
//                }
//            }
//            previous = suburb
//        }
//        do {
//            try context.save()
//        } catch {
//            print("Error during update of Suburb: \(error)")
//        }
//        objc_sync_exit(Static.lock)
//        return consolidated
//    }
//
//    /// Determine the location for a suburb in a sequence of suburbs.
//    ///
//    /// This algorithm is a little hard to follow. Fundamentally to geocode an
//    /// address, a request is put through to apple, but these requests cannot
//    /// be made too frequently, so 30 seconds is left between each, but the geocoding
//    /// is only performed if the suburb has an indeterminate location, i.e. nil.
//    ///
//    /// - Parameter iter: The iterator of suburbs
//    func determineLocation(iterator: AnyIterator<Suburb>?, completion: @escaping (Error?)->Void) {
//        guard location == nil else {
//            if let suburb = iterator?.next() {
//                suburb.determineLocation(iterator: iterator, completion: completion)
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
//        Static.geocoder.geocodeAddressDictionary(address) { (placeMarks, error) -> Void in
//            defer {
//                if let suburb = iterator?.next() {
//                    suburb.determineLocation(iterator: iterator, completion: completion)
//                } else {
//                    completion(nil)
//                }
//            }
//
//            guard error == nil else {
//                os_log("Error during geocoding for locations: %@", log: self.logger, type: .error, (error?.localizedDescription)!)
//                return
//            }
//
//            if let placemark = placeMarks?.first {
//                if let r = placemark.region as? CLCircularRegion {
//                    self.geographicRegion = r
//                    do {
//                        try self.managedObjectContext!.save()
//                    } catch {
//                        os_log("Error during determination of suburb locations: %@", log: self.logger, type: .error, error.localizedDescription)
//                    }
////                    println("locatity is \(placemark.locality), \(placemark.region)")
////                    println(self.updateLocationString)
//                }
//            }
//        }
//    }
//
//    class func determineAllLocations(completion: @escaping (Error?)->Void) {
//        let iterator = AnySequence<Suburb>(Suburb.fetchAll(from: PersistentStore.instance.context)).makeIterator()
//        iterator.next()?.determineLocation(iterator: iterator, completion: completion)
//    }
//
//    class func findClosestSuburb(to location: CLLocationCoordinate2D?, suburbs: [Suburb], closure: (_ actual: String?, _ suburb: Suburb?) -> Void) {
//        if location != nil {
////            println("Location is \(location)")
//            var intercepts = suburbs.filter{$0.geographicRegion?.contains(location!) ?? false}
//            if intercepts.isEmpty {
//                intercepts += suburbs.filter{$0.geographicRegion != nil}
//            }
//            let loc = CLLocation(latitude: location!.latitude, longitude: location!.longitude)
//            intercepts = intercepts.sorted{$0.location!.distance(from: loc) < $1.location!.distance(from: loc)}
//            let suburb = intercepts.first!
//            closure(suburb.name, suburb)
//        } else {
//            closure(nil, nil)
//        }
////            Static.geocoder.reverseGeocodeLocation(location) { (placeMarks: [AnyObject]!, error: NSError!) -> Void in
////                if error != nil {
////                    println("Error during geocoding: \(error.localizedDescription), \(error.localizedFailureReason)")
////                }
////                if let placemark = (placeMarks as [CLPlacemark]?)?.first {
////                    println("locatity is \(placemark.locality)")
////                    if placemark.locality != nil {
////                        let locality = Suburb.identify(placemark.locality!)
////                        let name = placemark.locality!.capitalizedString
////
////                        let index = suburbs.firstUntil{$0.ident == locality}.count
////                        if index < suburbs.count {
////                            closure(actual: name, suburb: suburbs[index])
////                        } else {
////                            if let location = placemark.location {
////                                var closestDistance: CLLocationDistance?
////                                var closestSuburb: String?
////                                for (suburb, suburbLocation) in FuelWatchParameters.sharedInstance.suburbLocations {
////                                    let distance = location.distanceFromLocation(suburbLocation)
////                                    if closestDistance == nil || closestDistance! > distance {
////                                        closestSuburb = suburb
////                                        closestDistance = distance
////                                    }
////                                }
////                                if closestSuburb != nil && closestDistance! < 100000 {
////                                    closestSuburb = Suburb.identify(closestSuburb!)
////                                    let index = suburbs.firstUntil{$0.ident == closestSuburb!}.count
////                                    if index < suburbs.count {
////                                        closure(actual: name, suburb: suburbs[index])
////                                    } else {
////                                        closure(actual: name, suburb: nil)
////                                    }
////                                } else {
////                                    closure(actual: name, suburb: nil)
////                                }
////                            } else {
////                                closure(actual: name, suburb: nil)
////                            }
////                        }
////                    } else {
////                        closure(actual: nil, suburb: nil)
////                    }
////                } else {
////                    closure(actual: nil, suburb: nil)
////                }
////            }
////        }
//    }

}
