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

class Product: Hashable {
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

    public var ident: Int16
    public var name: String
    public var priceOnDay: Set<PriceOnDay>?
    public var station: Set<Station>?
    public var statistics: Set<Statistics>?
    public var systemFields: Data?

    private static var _allProducts: [Int16: Product]? = nil

    static var all: [Int16: Product] {
        get {
            defer { objc_sync_exit(lock) }
            objc_sync_enter(lock)
            if _allProducts == nil {
                let group = DispatchGroup()
                group.enter()
                Product.fetchAll({ (prs, err) in
                    DispatchQueue.global().async {
                        defer {
                            group.leave()
                        }
                        guard err == nil else {
                            print(err!)
                            return
                        }
                        self._allProducts = [:]
                        for product in prs {
                            self._allProducts![product.ident] = product
                        }
                    }
                })
                while group.wait(timeout: .now() + 5.0) == .timedOut {
                    print("Product Timed out")
                }
            }
            return _allProducts ?? [:]
        }
    }

    static let lock = NSObject()

    public var description: String {
        return "Product \(name)"
    }

    public var debugDescription: String {
        return "Product (\(ident), \(name))"
    }

    class func fetch(withIdent ident: Int16, _ completionBlock: ((Product?, Error?) -> Void)?) {
        let pred = NSPredicate(format: "ident == %@", ident)
        let query = CKQuery(recordType: "FWProduct", predicate: pred)

        do {
            Product.download(fromDatabase: try FLOCloud.shared.publicDatabase(), withQuery: query) { (error, records) in
                let product: Product? = (records == nil || records!.isEmpty ? nil : Product(record: records!.first!))
                completionBlock?(product, error)
            }
        } catch {
            print(error)
        }
    }

    class func fetchAll(_ completionBlock: ((Set<Product>, Error?) -> Void)?) {
        let pred = NSPredicate(value: true)
        let query = CKQuery(recordType: "FWProduct", predicate: pred)

        do {
            Product.download(fromDatabase: try FLOCloud.shared.publicDatabase(), withQuery: query) { (error, records) in
                let products = Set<Product>(records?.map({ Product(record: $0) }) ?? [])
                completionBlock?(products, error)
            }
        } catch {
            print(error)
        }
    }
}

extension Product: FLODataEntity {
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
