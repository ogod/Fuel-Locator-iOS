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

    convenience init(ident: Int16, name: String, latitude: Double, longitude: Double, radius: Double) {
        self.init(ident: ident, name: name)
        self.latitude = latitude as NSNumber
        self.longitude = longitude as NSNumber
        self.radius = radius as NSNumber
    }

    enum Known: Int16 {
        case metropolitanArea = -1
        case northOfRiver = 25
        case southOfRiver = 26
        case eastHills = 27
        case albany = 15
        case augustaMargaretRiver = 28
        case bridgetownGreenbushes = 30
        case boulder = 1
        case broome = 2
        case bunbury = 16
        case busseltonTownsite = 3
        case busseltonShire = 29
        case capel = 19
        case carnarvon = 4
        case cataby = 33
        case collie = 5
        case coolgardie = 34
        case cunderdin = 35
        case donnybrookBalingup = 31
        case dalwallinu = 36
        case dampier = 6
        case dardanup = 20
        case denmark = 37
        case derby = 38
        case dongara = 39
        case esperance = 7
        case exmouth = 40
        case fitzroyCrossing = 41
        case geraldton = 17
        case greenough = 21
        case harvey = 22
        case jurien = 42
        case kalgoorlie = 8
        case kambalda = 43
        case karratha = 9
        case kellerberrin = 44
        case kojonup = 45
        case kununurra = 10
        case mandurah = 18
        case manjimup = 32
        case meckering = 58
        case meekatharra = 46
        case moora = 47
        case mtBarker = 48
        case murray = 23
        case narrogin = 11
        case newman = 49
        case norseman = 50
        case northam = 12
        case portHedland = 13
        case ravensthorpe = 51
        case regansFord = 57
        case southHedland = 14
        case tammin = 53
        case waroona = 24
        case williams = 54
        case wubin = 55
        case wundowie = 59
        case york = 56

        var identifier: String {
            switch self {
            case .metropolitanArea:
                return "metropolitanArea"
            case .northOfRiver:
                return "northOfRiver"
            case .southOfRiver:
                return "southOfRiver"
            case .eastHills:
                return "eastHills"
            case .albany:
                return "albany"
            case .augustaMargaretRiver:
                return "augustaMargaretRiver"
            case .bridgetownGreenbushes:
                return "bridgetownGreenbushes"
            case .boulder:
                return "boulder"
            case .broome:
                return "broome"
            case .bunbury:
                return "bunbury"
            case .busseltonTownsite:
                return "busseltonTownsite"
            case .busseltonShire:
                return "busseltonShire"
            case .capel:
                return "capel"
            case .carnarvon:
                return "carnarvon"
            case .cataby:
                return "cataby"
            case .collie:
                return "collie"
            case .coolgardie:
                return "coolgardie"
            case .cunderdin:
                return "cunderdin"
            case .donnybrookBalingup:
                return "donnybrookBalingup"
            case .dalwallinu:
                return "dalwallinu"
            case .dampier:
                return "dampier"
            case .dardanup:
                return "dardanup"
            case .denmark:
                return "denmark"
            case .derby:
                return "derby"
            case .dongara:
                return "dongara"
            case .esperance:
                return "esperance"
            case .exmouth:
                return "exmouth"
            case .fitzroyCrossing:
                return "fitzroyCrossing"
            case .geraldton:
                return "geraldton"
            case .greenough:
                return "greenough"
            case .harvey:
                return "harvey"
            case .jurien:
                return "jurien"
            case .kalgoorlie:
                return "kalgoorlie"
            case .kambalda:
                return "kambalda"
            case .karratha:
                return "karratha"
            case .kellerberrin:
                return "kellerberrin"
            case .kojonup:
                return "kojonup"
            case .kununurra:
                return "kununurra"
            case .mandurah:
                return "mandurah"
            case .manjimup:
                return "manjimup"
            case .meckering:
                return "meckering"
            case .meekatharra:
                return "meekatharra"
            case .moora:
                return "moora"
            case .mtBarker:
                return "mtBarker"
            case .murray:
                return "murray"
            case .narrogin:
                return "narrogin"
            case .newman:
                return "newman"
            case .norseman:
                return "norseman"
            case .northam:
                return "northam"
            case .portHedland:
                return "portHedland"
            case .ravensthorpe:
                return "ravensthorpe"
            case .regansFord:
                return "regansFord"
            case .southHedland:
                return "southHedland"
            case .tammin:
                return "tammin"
            case .waroona:
                return "waroona"
            case .williams:
                return "williams"
            case .wubin:
                return "wubin"
            case .wundowie:
                return "wundowie"
            case .york:
                return "york"
            }
        }
        var name: String {
            switch self {
            case .metropolitanArea:
                return "Metropolitan Area"
            case .northOfRiver:
                return "Metro : North of River"
            case .southOfRiver:
                return "Metro : South of River"
            case .eastHills:
                return "Metro : East/Hills"
            case .albany:
                return "Albany"
            case .augustaMargaretRiver:
                return "Augusta / Margaret River"
            case .bridgetownGreenbushes:
                return "Bridgetown / Greenbushes"
            case .boulder:
                return "Boulder"
            case .broome:
                return "Broome"
            case .bunbury:
                return "Bunbury"
            case .busseltonTownsite:
                return "Busselton (Townsite)"
            case .busseltonShire:
                return "Busselton (Shire)"
            case .capel:
                return "Capel"
            case .carnarvon:
                return "Carnarvon"
            case .cataby:
                return "Cataby"
            case .collie:
                return "Collie"
            case .coolgardie:
                return "Coolgardie"
            case .cunderdin:
                return "Cunderdin"
            case .donnybrookBalingup:
                return "Donnybrook / Balingup"
            case .dalwallinu:
                return "Dalwallinu"
            case .dampier:
                return "Dampier"
            case .dardanup:
                return "Dardanup"
            case .denmark:
                return "Denmark"
            case .derby:
                return "Derby"
            case .dongara:
                return "Dongara"
            case .esperance:
                return "Esperance"
            case .exmouth:
                return "Exmouth"
            case .fitzroyCrossing:
                return "Fitzroy Crossing"
            case .geraldton:
                return "Geraldton"
            case .greenough:
                return "Greenough"
            case .harvey:
                return "Harvey"
            case .jurien:
                return "Jurien"
            case .kalgoorlie:
                return "Kalgoorlie"
            case .kambalda:
                return "Kambalda"
            case .karratha:
                return "Karratha"
            case .kellerberrin:
                return "Kellerberrin"
            case .kojonup:
                return "Kojonup"
            case .kununurra:
                return "Kununurra"
            case .mandurah:
                return "Mandurah"
            case .manjimup:
                return "Manjimup"
            case .meckering:
                return "Meckering"
            case .meekatharra:
                return "Meekatharra"
            case .moora:
                return "Moora"
            case .mtBarker:
                return "Mt Barker"
            case .murray:
                return "Murray"
            case .narrogin:
                return "Narrogin"
            case .newman:
                return "Newman"
            case .norseman:
                return "Norseman"
            case .northam:
                return "Northam"
            case .portHedland:
                return "Port Hedland"
            case .ravensthorpe:
                return "Ravensthorpe"
            case .regansFord:
                return "Regans Ford"
            case .southHedland:
                return "South Hedland"
            case .tammin:
                return "Tammin"
            case .waroona:
                return "Waroona"
            case .williams:
                return "Williams"
            case .wubin:
                return "Wubin"
            case .wundowie:
                return "Wundowie"
            case .york:
                return "York"
            }
        }
        var recordId: CKRecord.ID {
            return Region.recordId(from: rawValue)
        }
    }

    init(record: CKRecord) {
        ident = Region.ident(from: record.recordID)
        name = record["name"] as! String
        location = record["location"] as? CLLocation
        radius = record["radius"] as? NSNumber
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
                CLLocation(latitude: latitude!.doubleValue, longitude: longitude!.doubleValue) :
                nil
        }
        set (newLocation) {
            latitude = newLocation?.coordinate.latitude as NSNumber?
            longitude = newLocation?.coordinate.longitude as NSNumber?
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
            print("Error while submitting Region fetch (with block): \(error)")
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
            print("Error while submitting Region fetch: \(error)")
        }
    }

    var key: Int16 {
        return ident
    }

    class func ident(from recordID: CKRecord.ID) -> Int16 {
        let str = recordID.recordName
        let index = str.index(after: str.index(of: ":")!)
        return Int16(String(str[index...]))!
    }

    class func recordId(from ident: Int16) -> CKRecord.ID {
        return CKRecord.ID(recordName: "Region:" + String(ident))
    }

    class func recordId(from ident: Known) -> CKRecord.ID {
        return recordId(from: ident.rawValue)
    }

    var recordID: CKRecord.ID {
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

    var initialiser: String {
        get {
            if latitude == nil || longitude == nil || radius == nil {
                return "\(ident): Region(ident: \(ident), name: \"\(name)\")"
            } else {
                return "\(ident): Region(ident: \(ident), name: \"\(name)\", latitude: \(latitude!.doubleValue), longitude: \(longitude!.doubleValue), radius: \(radius!.doubleValue))"
            }
        }
    }

    static let defaults: Dictionary<Int16, Region> = [
        54: Region(ident: 54, name: "Williams", latitude: -33.028103, longitude: 116.879206, radius: 5000.0),
        35: Region(ident: 35, name: "Cunderdin", latitude: -31.652038, longitude: 117.232004, radius: 5000.0),
        21: Region(ident: 21, name: "Greenough", latitude: -28.844604000000004, longitude: 114.7300835, radius: 26903.150177619147),
        29: Region(ident: 29, name: "Busselton (Shire)", latitude: -33.661596625, longitude: 115.191095625, radius: 14484.803084711277),
        49: Region(ident: 49, name: "Newman", latitude: -23.375385333333334, longitude: 119.74471283333335, radius: 5000.0),
        20: Region(ident: 20, name: "Dardanup", latitude: -33.347548333333336, longitude: 115.74232799999999, radius: 10872.367711197236),
        2: Region(ident: 2, name: "Broome", latitude: -17.956006571428574, longitude: 122.23100557142857, radius: 5000.0),
        26: Region(ident: 26, name: "Metro : South of River", latitude: -32.10457923516925, longitude: 115.85931749588352, radius: 44047.4559739961),
        32: Region(ident: 32, name: "Manjimup", latitude: -34.57573445357143, longitude: 116.25810914285714, radius: 68275.8190351985),
        38: Region(ident: 38, name: "Derby", latitude: -17.313909666666667, longitude: 123.64283333333333, radius: 5000.0),
        16: Region(ident: 16, name: "Bunbury", latitude: -33.34074265079364, longitude: 115.67755204761906, radius: 7718.230096382874),
        12: Region(ident: 12, name: "Northam", latitude: -31.654200333333335, longitude: 116.672584, radius: 5000.0),
        45: Region(ident: 45, name: "Kojonup", latitude: -33.835258, longitude: 117.16021, radius: 5000.0),
        51: Region(ident: 51, name: "Ravensthorpe", latitude: -33.581312, longitude: 120.048818, radius: 5000.0),
        37: Region(ident: 37, name: "Denmark", latitude: -34.96104233333333, longitude: 117.35291799999999, radius: 5000.0),
        31: Region(ident: 31, name: "Donnybrook / Balingup", latitude: -33.702832666666666, longitude: 115.91241591666667, radius: 21889.296835021294),
        1: Region(ident: 1, name: "Boulder", latitude: -30.7831158, longitude: 121.4657708, radius: 5000.0),
        23: Region(ident: 23, name: "Murray", latitude: -32.621161055555554, longitude: 115.86413522222223, radius: 26269.392012856963),
        7: Region(ident: 7, name: "Esperance", latitude: -33.846405299999994, longitude: 121.88752085714285, radius: 5000.0),
        25: Region(ident: 25, name: "Metro : North of River", latitude: -31.83978581904762, longitude: 115.81779462777779, radius: 40871.898948146096),
        43: Region(ident: 43, name: "Kambalda", latitude: -31.208105500000002, longitude: 121.651743, radius: 6070.776871419579),
        58: Region(ident: 58, name: "Meckering", latitude: -31.63242, longitude: 117.006301, radius: 5000.0),
        42: Region(ident: 42, name: "Jurien", latitude: -30.3057475, longitude: 115.0387335, radius: 5000.0),
        50: Region(ident: 50, name: "Norseman", latitude: -32.188634, longitude: 121.778694, radius: 5000.0),
        3: Region(ident: 3, name: "Busselton (Townsite)", latitude: -33.65781645833333, longitude: 115.32080358333334, radius: 7951.710597460472),
        30: Region(ident: 30, name: "Bridgetown / Greenbushes", latitude: -33.90375, longitude: 116.09793316666666, radius: 12111.48801588454),
        24: Region(ident: 24, name: "Waroona", latitude: -32.86102233333334, longitude: 115.790268, radius: 17378.511313405492),
        22: Region(ident: 22, name: "Harvey", latitude: -33.150884833333336, longitude: 115.79647541666667, radius: 20552.430544648894),
        28: Region(ident: 28, name: "Augusta / Margaret River", latitude: -34.02248409523809, longitude: 115.10296885714286, radius: 37755.648686868546),
        44: Region(ident: 44, name: "Kellerberrin", latitude: -31.633149, longitude: 117.7267344, radius: 5000.0),
        41: Region(ident: 41, name: "Fitzroy Crossing", latitude: -18.20106725, longitude: 125.57107024999999, radius: 5000.0),
        47: Region(ident: 47, name: "Moora", latitude: -30.639021333333332, longitude: 116.00819966666666, radius: 5000.0),
        48: Region(ident: 48, name: "Mt Barker", latitude: -34.628447333333334, longitude: 117.66393766666667, radius: 5000.0),
        56: Region(ident: 56, name: "York", latitude: -31.8921365, longitude: 116.768338, radius: 5000.0),
        11: Region(ident: 11, name: "Narrogin", latitude: -32.9337085, longitude: 117.1779625, radius: 5000.0),
        33: Region(ident: 33, name: "Cataby", latitude: -30.744478, longitude: 115.5492495, radius: 5000.0),
        8: Region(ident: 8, name: "Kalgoorlie", latitude: -30.750553888888895, longitude: 121.47048344444445, radius: 5000.0),
        59: Region(ident: 59, name: "Wundowie", latitude: -31.806159, longitude: 116.3372595, radius: 6831.38450991653),
        15: Region(ident: 15, name: "Albany", latitude: -34.85097420434783, longitude: 117.99824197391305, radius: 74800.3390515784),
        40: Region(ident: 40, name: "Exmouth", latitude: -21.934815, longitude: 114.126983, radius: 5000.0),
        17: Region(ident: 17, name: "Geraldton", latitude: -28.6553725, longitude: 115.06672206538461, radius: 50451.42072334734),
        53: Region(ident: 53, name: "Tammin", latitude: -31.640374, longitude: 117.491034, radius: 5000.0),
        57: Region(ident: 57, name: "Regans Ford", latitude: -30.983045, longitude: 115.702039, radius: 5000.0),
        46: Region(ident: 46, name: "Meekatharra", latitude: -26.595215800000002, longitude: 118.495069775, radius: 5000.0),
        14: Region(ident: 14, name: "South Hedland", latitude: -20.4052775, longitude: 118.598494, radius: 2538.72633591527),
        6: Region(ident: 6, name: "Dampier", latitude: -20.665198, longitude: 116.706964, radius: 5000.0),
        39: Region(ident: 39, name: "Dongara", latitude: -29.251995666666666, longitude: 114.94400999999999, radius: 5000.0),
        34: Region(ident: 34, name: "Coolgardie", latitude: -30.9546275, longitude: 121.16575499999999, radius: 5000.0),
        13: Region(ident: 13, name: "Port Hedland", latitude: -20.372652016666667, longitude: 118.60100801666664, radius: 9093.141677563071),
        18: Region(ident: 18, name: "Mandurah", latitude: -32.5404824875, longitude: 115.71233025625001, radius: 17520.21756978068),
        5: Region(ident: 5, name: "Collie", latitude: -33.358850333333336, longitude: 116.15167233333332, radius: 5000.0),
        9: Region(ident: 9, name: "Karratha", latitude: -20.752608416666664, longitude: 116.81469583333333, radius: 5000.0),
        27: Region(ident: 27, name: "Metro : East/Hills", latitude: -31.911701517857143, longitude: 116.07443905654762, radius: 35885.9627658278),
        55: Region(ident: 55, name: "Wubin", latitude: -30.10664, longitude: 116.631805, radius: 5000.0),
        10: Region(ident: 10, name: "Kununurra", latitude: -15.785064285714284, longitude: 128.74442557142856, radius: 5000.0),
        36: Region(ident: 36, name: "Dalwallinu", latitude: -30.274373, longitude: 116.663595, radius: 5000.0),
        -1: Region(ident: -1, name: "Metropolitan Area", latitude: -31.963147972731843, longitude: 115.87512869723679, radius: 60162.468620822096),
        19: Region(ident: 19, name: "Capel", latitude: -33.46549516666666, longitude: 115.60012216666667, radius: 15611.907892551319),
        4: Region(ident: 4, name: "Carnarvon", latitude: -24.869948399999995, longitude: 113.6944805, radius: 5000.0),
        ]

    static let retrievalNotificationName = Notification.Name(rawValue: "Region.RetrievalNotification")
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
