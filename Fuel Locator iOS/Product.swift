//
//  Product.swift
//  FuelLocator
//
//  Created by Owen Godfrey on 9/10/2014.
//  Copyright (c) 2014 Owen Godfrey. All rights reserved.
//

import Foundation
import CloudKit
import os.log

class Product: FLODataEntity, Hashable {
    static func == (lhs: Product, rhs: Product) -> Bool {
        return lhs.ident == rhs.ident
    }

    var hashValue: Int { return Int(ident) }

    init(ident: Int16, name: String) {
        self.ident = ident
        self.name = name
    }

    init(record: CKRecord) {
        ident = Brand.ident(from: record.recordID)
        name = record["name"] as! String
        systemFields = Brand.archiveSystemFields(from: record)
    }

    enum Known: Int16 {
        case unknown = 0
        case ulp = 1
        case premiumUnleaded = 2
        case diesel = 4
        case lpg = 5
        case ron98  = 6
        case b20Diesel = 7
        case e10 = 8
        case p100 = 9
        case e85 = 10
        case brandDiesel = 11

        var name: String! {
            switch self {
            case .unknown:
                return nil
            case .ulp:
                return "ulp"
            case .premiumUnleaded:
                return "pulp"
            case .diesel:
                return "diesel"
            case .lpg:
                return "lpg"
            case .ron98:
                return "98ron"
            case .b20Diesel:
                return "b20diesel"
            case .e10:
                return "e10"
            case .p100:
                return "p100"
            case .e85:
                return "e85"
            case .brandDiesel:
                return "brandDiesel"
            }
        }
        var fullName: String! {
            switch self {
            case .unknown:
                return nil
            case .ulp:
                return "Unleaded (91)"
            case .premiumUnleaded:
                return "Premium Unleaded (95)"
            case .diesel:
                return "Diesel"
            case .lpg:
                return "LPG"
            case .ron98:
                return "Ultra-premium Unleaded (98)"
            case .b20Diesel:
                return "20% Biodiesel"
            case .e10:
                return "10% Ethenol Petrol"
            case .p100:
                return "10% Ethenol + Ultra-premium"
            case .e85:
                return "85% Ethenol Petrol"
            case .brandDiesel:
                return "Brand Diesel"
            }
        }
    }

    public var ident: Int16
    public var name: String
    public var priceOnDay: Set<PriceOnDay>?
    public var station: Set<Station>?
    public var statistics: Set<Statistics>?
    public var systemFields: Data?

    var knownType: Known {
        get {
            return Known(rawValue: ident) ?? .unknown
        }
        set {
            ident = newValue.rawValue
        }
    }

    static let lock = NSObject()

    public var description: String {
        return "Product \(name)"
    }

    public var debugDescription: String {
        return "Product (\(ident), \(name))"
    }

    class func fetch(withIdent ident: Int16, _ completionBlock: @escaping (Product?, Error?) -> Void) {
        let pred = NSPredicate(format: "ident == %@", ident)
        let query = CKQuery(recordType: "FWProduct", predicate: pred)

        do {
            Product.download(fromDatabase: try FLOCloud.shared.publicDatabase(), withQuery: query) { (error, records) in
                let product: Product? = (records == nil || records!.isEmpty ? nil : Product(record: records!.first!))
                completionBlock(product, error)
            }
        } catch {
            print(error)
        }
    }

    class func fetchAll(_ completionBlock: @escaping (Set<Product>, Error?) -> Void) {
        let pred = NSPredicate(value: true)
        let query = CKQuery(recordType: "FWProduct", predicate: pred)

        do {
            Product.download(fromDatabase: try FLOCloud.shared.publicDatabase(), withQuery: query) { (error, records) in
                let products = Set<Product>(records?.map({ Product(record: $0) }) ?? [])
                completionBlock(products, error)
            }
        } catch {
            print(error)
        }
    }

    static var all = FLODataEntityAll<Int16, Product>()

    var key: Int16 {
        return ident
    }

    class func ident(from recordID: CKRecordID) -> Int16 {
        let str = recordID.recordName
        let index = str.index(after: str.index(of: ":")!)
        return Int16(String(str[index...]))!
    }

    class func recordId(from ident: Int16) -> CKRecordID {
        return CKRecordID(recordName: "Product:" + String(ident))
    }

    var recordID: CKRecordID {
        return Product.recordId(from: ident)
    }

    func hasChanged(from record: CKRecord) -> Bool {
        if let name = record["name"] as? String {
            if name != self.name {
                return true
            }
        }
        return false
    }

    var record: CKRecord {
        get {
            let r: CKRecord
            if systemFields == nil {
                r = CKRecord(recordType: "FWProduct", recordID: Product.recordId(from: ident))
            } else {
                let unarchiver = NSKeyedUnarchiver(forReadingWith: systemFields!)
                unarchiver.requiresSecureCoding = true
                r = CKRecord(coder: unarchiver)!
            }
            r["name"] = name as NSString
            return r
        }
        set {
            systemFields = Product.archiveSystemFields(from: newValue)
            ident = Product.ident(from: newValue.recordID)
            if let n = newValue["name"] as? String {
                if n != name {
                    name = n
                }
            }
        }
    }
}

extension Product {
//    class func updateStatic(context: NSManagedObjectContext) {
//        Product.update(from: [IIElement(ident: 1, value: "ULP")], to: context)
//        Product.update(from: [IIElement(ident: 2, value: "Premium Unleaded")], to: context)
//        Product.update(from: [IIElement(ident: 4, value: "Diesel")], to: context)
//        Product.update(from: [IIElement(ident: 5, value: "LPG")], to: context)
//        Product.update(from: [IIElement(ident: 6, value: "98 RON ")], to: context)
//        Product.update(from: [IIElement(ident: 7, value: "B20 diesel")], to: context)
//        Product.update(from: [IIElement(ident: 8, value: "E10")], to: context)
//        Product.update(from: [IIElement(ident: 9, value: "P100")], to: context)
//        Product.update(from: [IIElement(ident: 10, value: "E85 ")], to: context)
//    }
//
//    var lpk: Double {
//        get {
//            let base = 0.085
//            switch ident {
//            case 1:
//                return base
//
//            case 2:
//                return base / 1.04
//
//            case 4:
//                return base / 1.28
//
//            case 5:
//                return base * 1.25
//
//            case 6:
//                return base / 1.0712
//
//            case 7:
//                return base
//
//            case 8:
//                return base * 1.035
//
//            case 9:
//                return base / 1.07
//
//            case 10:
//                return base * 1.475
//
//            default:
//                return 0
//            }
//        }
//    }
//
//    class func update(from sourceItems: [IIElement]?, to context: NSManagedObjectContext) {
//        objc_sync_enter(Static.lock)
//        if sourceItems != nil {
//            for item in sourceItems! {
//                var product = fetch(withIdent: Int16(item.ident), from: context) ?? fetch(withName: item.value, from: context)
//                if product != nil {
//                    if product!.name != item.value {
//                        product!.name = item.value
//                    }
//                    if product!.ident != Int16(item.ident) {
//                        product!.ident = Int16(item.ident)
//                    }
//                } else {
//                    product = create(in: context)
//                    product!.name = item.value
//                    product!.ident = Int16(item.ident)
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
