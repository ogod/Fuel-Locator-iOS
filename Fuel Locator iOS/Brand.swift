//
//  Brand.swift
//  FuelLocator
//
//  Created by Owen Godfrey on 9/10/2014.
//  Copyright (c) 2014 Owen Godfrey. All rights reserved.
//

import UIKit
import CloudKit
import os.log

let FWBrandUpdateNotificationKey = "FuelWatchBrandUpdateNotification"

class Brand: FLODataEntity, Hashable {
    var hashValue: Int { return Int(ident) }

    static func == (lhs: Brand, rhs: Brand) -> Bool {
        return lhs.ident == rhs.ident
    }

    enum Known: Int16 {
        case bp = 5
        case caltex = 6
        case colesExpress = 20
        case pumaEnergy = 26
        case caltexWoolworths = 19
        case sevenEleven = 29
        case united = 23
        case shell = 14
        case vibe = 27
        case gull = 7
        case betterChoice = 3
        case liberty = 10
        case mobil = 11
        case eagle = 24
        case kleenheat = 8
        case peak = 13
        case boc = 4
        case fastfuel24_7 = 25
        case kwikfuel = 9
        case wesco = 16
        case ampol = 2
        case fuelsWest = 22
        case blackWhite = 21
        case independent = 15

        var name: String! {
            switch self {
            case .ampol:
                return "ampol"
            case .betterChoice:
                return "betterChoice"
            case .boc:
                return "boc"
            case .bp:
                return "bp"
            case .caltex:
                return "caltex"
            case .gull:
                return "gull"
            case .kleenheat:
                return "kleenheat"
            case .kwikfuel:
                return "kwikfuel"
            case .liberty:
                return "liberty"
            case .mobil:
                return "mobil"
            case .peak:
                return "peak"
            case .shell:
                return "shell"
            case .independent:
                return "independent"
            case .wesco:
                return "wesco"
            case .caltexWoolworths:
                return "caltexWoolworths"
            case .colesExpress:
                return "colesExpress"
            case .blackWhite:
                return "blackWhite"
            case .fuelsWest:
                return "fuelsWest"
            case .united:
                return "united"
            case .eagle:
                return "eagle"
            case .fastfuel24_7:
                return "fastfuel24_7"
            case .pumaEnergy:
                return "pumaEnergy"
            case .vibe:
                return "vibe"
            case .sevenEleven:
                return "sevenEleven"
            }
        }
        var key: String {
            guard name != nil else {
                return ""
            }
            return "Brand.\(name!).useDiscount"
        }
        var discountKey: String {
            guard name != nil else {
                return ""
            }
            return "Brand.\(name!).amountDiscount"
        }
    }

    private let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "Brand")

    init(ident: Int16, name: String, discount: Int16) {
        self.ident = ident
        self.name = name
        self.discount = discount
    }

    init(record: CKRecord) {
        ident = Brand.ident(from: record.recordID)
        name = record["name"] as! String
        discount = record["discount"] as? Int16 ?? 0
        systemFields = Brand.archiveSystemFields(from: record)
    }

    public var discount: Int16
    public var ident: Int16
    public var name: String
    public var station: Set<Station>?
    public var systemFields: Data?
    public lazy var image: UIImage = Brand.image(named: name.replacingOccurrences(of: "/", with: "-"))
    public lazy var glyph: UIImage = Brand.glyph(named: name.replacingOccurrences(of: "/", with: "-"))

    public var useDiscount: Bool {
        get {
            if let b = brandIdent {
                return UserDefaults.standard.bool(forKey: b.key)
            } else {
                return false
            }
        }
        set {
            if let b = brandIdent {
                UserDefaults.standard.set(newValue, forKey: b.key)
            }
        }
    }
    public var personalDiscount: Int16? {
        get {
            if let b = brandIdent {
                if UserDefaults.standard.object(forKey: b.discountKey) != nil {
                    let d = Int16(UserDefaults.standard.integer(forKey: b.discountKey))
                    return d == 0 ? nil : d
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
        set {
            if let b = brandIdent {
                if newValue != nil {
                    UserDefaults.standard.set(newValue, forKey: b.discountKey)
                } else {
                    UserDefaults.standard.removeObject(forKey: b.discountKey)
                }
            }
        }
    }

    var adjustment: Int16 {
        return useDiscount ? (personalDiscount ?? discount) * 10 : 0
    }
    
    var brandIdent: Known? {
        get {
            return Known(rawValue: ident)
        }
        set {
            if newValue != nil {
                ident = newValue!.rawValue
            }
        }
    }

//        get {
//            defer { objc_sync_exit(lock) }
//            objc_sync_enter(lock)
//            if _allBrands == nil {
//                let group = DispatchGroup()
//                group.enter()
//                Brand.fetchAll({ (brs, err) in
//                    DispatchQueue.global().async {
//                        defer {
//                            group.leave()
//                        }
//                        guard err == nil else {
//                            print(err!)
//                            return
//                        }
//                        self._allBrands = [:]
//                        for brand in brs {
//                            self._allBrands![brand.ident] = brand
//                        }
//                    }
//                })
//                while group.wait(timeout: .now() + 5.0) == .timedOut {
//                    print("Brand Timed out")
//                }
//            }
//            return _allBrands ?? [:]
//        }
//    }

    static var brandImageCache: [String: UIImage] = {
        var dict = [String: UIImage]()
        return dict
    }()
    static var brandGlyphCache: [String: UIImage] = {
        var dict = [String: UIImage]()
        return dict
    }()
    static let lock = NSObject()
    static let defaultImage = UIImage(named: "question_mark")!

    public var description: String {
        return "Brand \(name)"
    }

    public var debugDescription: String {
        return "Brand (\(ident), \(name))"
    }

    class func image(named name: String) -> UIImage {
        var i = Brand.brandImageCache[name]
        if i == nil {
            i = UIImage(named: "Brand Image - \(name)") ?? defaultImage
            Brand.brandImageCache[name] = i
        }
        return i!
    }

    class func glyph(named name: String) -> UIImage {
        var i = Brand.brandGlyphCache[name]
        if i == nil {
            i = UIImage(named: "Brand Glyph - \(name)") ?? defaultImage
            Brand.brandGlyphCache[name] = i
        }
        return i!
    }

    func write<Target : OutputStream>(to target: inout Target) {
        target.write(self.description, maxLength: 512)
    }

    class func fetch(withIdent ident: Int16, _ completionBlock: @escaping (Brand?, Error?) -> Void) {
        let pred = NSPredicate(format: "ident == %@", ident)
        let query = CKQuery(recordType: "FWBrand", predicate: pred)

        do {
            Brand.download(fromDatabase: try FLOCloud.shared.publicDatabase(), withQuery: query) { (error, records) in
                let brand: Brand? = (records == nil || records!.isEmpty ? nil : Brand(record: records!.first!))
                completionBlock(brand, error)
            }
        } catch {
            let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "Brand.fetch")
            os_log("Fetch error: %@", log: logger, type: .error, error.localizedDescription)
        }
    }

    class func fetchAll(_ completionBlock: @escaping (Set<Brand>, Error?) -> Void) {
        let pred = NSPredicate(value: true)
        let query = CKQuery(recordType: "FWBrand", predicate: pred)

        do {
            Brand.download(fromDatabase: try FLOCloud.shared.publicDatabase(), withQuery: query) { (error, records) in
                let brands = Set<Brand>(records?.map({ Brand(record: $0) }) ?? [])
                completionBlock(brands, error)
            }
        } catch FLOError.cloudDatabaseNotAvailable {
            if MapViewController.instance != nil {
                let alert = UIAlertController(title: "Cloud Database", message: "The iCloud Database is not accessible. Please try again later.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                MapViewController.instance?.present(alert, animated: true, completion: {
                    abort()
                })
            } else {
                let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "Brand.fetchAll")
                os_log("FetchAll error: %@", log: logger, type: .error, FLOError.cloudDatabaseNotAvailable.localizedDescription)
                abort()
            }
        } catch {
            let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "Brand.fetchAll")
            os_log("FetchAll error: %@", log: logger, type: .error, error.localizedDescription)
            abort()
        }
    }

    static var all: FLODataEntityAll<Int16, Brand> = FLODataEntityAll<Int16, Brand>() 

    var key: Int16 {
        return ident
    }

    class func ident(from recordID: CKRecord.ID) -> Int16 {
        let str = recordID.recordName
        let index = str.index(after: str.index(of: ":")!)
        return Int16(String(str[index...]))!
    }

    class func recordID(from ident: Int16) -> CKRecord.ID {
        return CKRecord.ID(recordName: "Brand:" + String(ident))
    }

    var recordID: CKRecord.ID {
        return Brand.recordID(from: ident)
    }

    func hasChanged(from record:CKRecord) -> Bool {
        let na = record["name"] as? String
        if na != name {
            return true
        }
        let d = record["discount"] as? Int16 ?? 0
        if d != discount {
            return true
        }
        return false
    }

    var record: CKRecord {
        get {
            let r: CKRecord
            if systemFields == nil {
                r = CKRecord(recordType: "FWBrand", recordID: recordID)
            } else {
                let unarchiver = NSKeyedUnarchiver(forReadingWith: systemFields!)
                unarchiver.requiresSecureCoding = true
                r = CKRecord(coder: unarchiver)!
            }
            r["name"] = name as NSString
            r["discount"] = discount as CKRecordValue
            return r
        }
        set {
            systemFields = Brand.archiveSystemFields(from: newValue)
            ident = Brand.ident(from: newValue.recordID)
            let na = newValue["name"] as? String
            if na != name {
                name = na!
            }
            let d = newValue["discount"] as? Int16 ?? 0
            if d != discount {
                discount = d
            }
        }
    }

    var initialiser: String {
        get {
            return "\(ident): Brand(ident: \(ident), name: \"\(name)\", discount: \(discount))"
        }
    }

    static let defaults: Dictionary<Int16, Brand> = [
        19: Brand(ident: 19, name: "Caltex Woolworths", discount: 4),
        23: Brand(ident: 23, name: "United", discount: 4),
        10: Brand(ident: 10, name: "Liberty", discount: 4),
        14: Brand(ident: 14, name: "Shell", discount: 4),
        4:  Brand(ident: 4,  name: "BOC", discount: 4),
        13: Brand(ident: 13, name: "Peak", discount: 4),
        27: Brand(ident: 27, name: "Vibe", discount: 4),
        20: Brand(ident: 20, name: "Coles Express", discount: 4),
        29: Brand(ident: 29, name: "7-Eleven", discount: 4),
        25: Brand(ident: 25, name: "FastFuel 24/7", discount: 4),
        3:  Brand(ident: 3,  name: "Better Choice", discount: 4),
        16: Brand(ident: 16, name: "Wesco", discount: 4),
        8:  Brand(ident: 8,  name: "Kleenheat", discount: 4),
        21: Brand(ident: 21, name: "Black & White", discount: 4),
        6:  Brand(ident: 6,  name: "Caltex", discount: 4),
        24: Brand(ident: 24, name: "Eagle", discount: 4),
        26: Brand(ident: 26, name: "Puma", discount: 4),
        22: Brand(ident: 22, name: "Fuels West", discount: 4),
        9:  Brand(ident: 9,  name: "Kwikfuel", discount: 4),
        7:  Brand(ident: 7,  name: "Gull", discount: 4),
        15: Brand(ident: 15, name: "Independent", discount: 4),
        11: Brand(ident: 11, name: "Mobil", discount: 4),
        2:  Brand(ident: 2,  name: "Ampol", discount: 4),
        5:  Brand(ident: 5,  name: "BP", discount: 4)
        ]

    static let retrievalNotificationName = Notification.Name(rawValue: "Brand.RetrievalNotification")
}

extension Brand {

//    class func updateStatic(to context: NSManagedObjectContext) {
//        Brand.update(from: [IIElement(ident: 2, value: "Ampol")], to: context)
//        Brand.update(from: [IIElement(ident: 3, value: "Better Choice")], to: context)
//        Brand.update(from: [IIElement(ident: 4, value: "BOC")], to: context)
//        Brand.update(from: [IIElement(ident: 5, value: "BP")], to: context)
//        Brand.update(from: [IIElement(ident: 6, value: "Caltex")], to: context)
//        Brand.update(from: [IIElement(ident: 7, value: "Gull")], to: context)
//        Brand.update(from: [IIElement(ident: 8, value: "Kleenheat")], to: context)
//        Brand.update(from: [IIElement(ident: 9, value: "Kwikfuel")], to: context)
//        Brand.update(from: [IIElement(ident: 10, value: "Liberty")], to: context)
//        Brand.update(from: [IIElement(ident: 13, value: "Peak")], to: context)
//        Brand.update(from: [IIElement(ident: 14, value: "Shell")], to: context)
//        Brand.update(from: [IIElement(ident: 15, value: "Independent")], to: context)
//        Brand.update(from: [IIElement(ident: 16, value: "Wesco")], to: context)
//        Brand.update(from: [IIElement(ident: 19, value: "Caltex Woolworths")], to: context)
//        Brand.update(from: [IIElement(ident: 20, value: "Coles Express")], to: context)
//        Brand.update(from: [IIElement(ident: 21, value: "Black & White")], to: context)
//        Brand.update(from: [IIElement(ident: 22, value: "Fuels West")], to: context)
//        Brand.update(from: [IIElement(ident: 23, value: "United")], to: context)
//        Brand.update(from: [IIElement(ident: 24, value: "Eagle")], to: context)
//        Brand.update(from: [IIElement(ident: 25, value: "Fastfuel 24/7")], to: context)
//        Brand.update(from: [IIElement(ident: 26, value: "Puma Energy")], to: context)
//        Brand.update(from: [IIElement(ident: 27, value: "Vibe")], to: context)
//    }
//
//    class func update(from sourceItems: [IIElement]?, to context: NSManagedObjectContext) {
//        objc_sync_enter(Brand.lock)
//        if sourceItems != nil {
//            for item in sourceItems! {
//                var brand = fetch(withIdent: Int16(item.ident), from: context) ?? fetch(withName: item.value, from: context)
//                if brand == nil {
//                    brand = create(in: context)
//                    brand!.name = item.value
//                    brand!.ident = item.ident
//                }
//                if brand!.name != item.value {
//                    brand!.name = item.value
//                }
//                if brand!.ident != item.ident {
//                    brand!.ident = item.ident
//                }
//                if brand?.hasChanges ?? false {
//                    let userInfo: [AnyHashable: Any] = ["ident" : brand!.ident,
//                        "name" : brand!.name,
//                        "discount" : brand!.discount]
//                    NotificationCenter.default.post(name: Notification.Name(rawValue: FWBrandUpdateNotificationKey), object: nil, userInfo: userInfo)
//                }
//            }
//        }
//        do {
//            try context.save()
//        } catch {
//            os_log("Error on managed object save: %@", type: .error, error.localizedDescription)
//        }
//        objc_sync_exit(Static.lock)
//    }
}
