//
//  PriceOnDay.swift
//  FuelLocator
//
//  Created by Owen Godfrey on 9/10/2014.
//  Copyright (c) 2014 Owen Godfrey. All rights reserved.
//

import Foundation
import CloudKit
import os

class PriceOnDay: Hashable {
    var hashValue: Int { return date.hashValue ^ (product.hashValue << 8) ^ (station.hashValue << 16)}

    static func == (lhs: PriceOnDay, rhs: PriceOnDay) -> Bool {
        return true
    }

    public var date: Date
    public var price: Int16
    public var product: Product
    public var station: Station
    public var systemFields: Data?

    init(date: Date, price: Int16, product: Product, station: Station) {
        self.date = date
        self.price = price
        self.product = product
        self.station = station
    }

    init(record: CKRecord) {
        let ident = PriceOnDay.ident(from: record.recordID)
        date = ident.date
        product = ident.product
        station = ident.station
        price = record["price"] as! Int16
        systemFields = Brand.archiveSystemFields(from: record)
    }

    var adjustedPrice: Int16 {
        return price // - (station.brand?.discount * 10 ?? 0)
    }
    
    private static var _allPrices: [String: PriceOnDay]? = nil

    static var all: [String: PriceOnDay] {
        get {
            defer { objc_sync_exit(lock) }
            objc_sync_enter(lock)
            if _allPrices == nil {
                let group = DispatchGroup()
                group.enter()
                PriceOnDay.fetchAll({ (prs, err) in
                    DispatchQueue.global().async {
                        defer {
                            group.leave()
                        }
                        guard err == nil else {
                            print(err!)
                            return
                        }
                        self._allPrices = [:]
                        for price in prs {
                            self._allPrices![price.station.tradingName] = price
                        }
                    }
                })
                if group.wait(timeout: .now() + 5.0) == .timedOut {
                    print("Prices Timed out")
                }
            }
            return _allPrices ?? [:]
        }
    }

    static func reset() {
        defer { objc_sync_exit(lock) }
        objc_sync_enter(lock)
        _allPrices = nil
    }

    static let lock = NSObject()
    static let calendar = Calendar.current
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yy"
        return f
    }()

    let keyRegx = try! NSRegularExpression(pattern: "^(\\d{4}-\\d+-\\d+)|(\\d+)|(.*)$")

    class func fetch(withStation station: Station, _ completionBlock: ((PriceOnDay?, Error?) -> Void)?) {
        let st = PriceOnDay.calendar.date(bySettingHour: 0, minute: 0, second: 0, of: MapViewController.instance!.globalDate)!
        let en = PriceOnDay.calendar.date(byAdding: .day, value: 1, to: st)!
        let prodRef = CKReference(recordID: MapViewController.instance!.globalProduct.recordID, action: .none)
        let stRef = CKReference(recordID: station.recordID, action: .none)
        let pred = NSPredicate(format: "date >= %@ && date < %@ && product == %@ && station == %@",
                               st as NSDate, en as NSDate, prodRef, stRef)
        let query = CKQuery(recordType: "FWPrice", predicate: pred)

        do {
            PriceOnDay.download(fromDatabase: try FLOCloud.shared.publicDatabase(), withQuery: query) { (error, records) in
                let price: PriceOnDay? = (records == nil || records!.isEmpty ? nil : PriceOnDay(record: records!.first!))
                completionBlock?(price, error)
            }
        } catch {
            print(error)
        }
    }

    class func fetchAll(_ completionBlock: ((Set<PriceOnDay>, Error?) -> Void)?) {
        let st = PriceOnDay.calendar.date(bySettingHour: 0, minute: 0, second: 0, of: MapViewController.instance!.globalDate)!
        let en = PriceOnDay.calendar.date(byAdding: .day, value: 1, to: st)!
        let prodRef = CKReference(recordID: MapViewController.instance!.globalProduct.recordID, action: .none)
        let predicate = NSPredicate(format: "date >= %@ && date < %@ && product == %@",
                                    st as NSDate, en as NSDate, prodRef)
        let query = CKQuery(recordType: "FWPrice", predicate: predicate)

        do {
            PriceOnDay.download(fromDatabase: try FLOCloud.shared.publicDatabase(), withQuery: query) { (error, records) in
                print("Completing prices")
                let prices = Set<PriceOnDay>(records?.map({ PriceOnDay(record: $0) }) ?? [])
                completionBlock?(prices, error)
            }
        } catch {
            print(error)
        }
    }
}

extension PriceOnDay: FLODataEntity {
    class func ident(from recordID: CKRecordID) -> (date: Date, product: Product, station: Station) {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let str = recordID.recordName
        let index = str.index(after: str.index(of: ":")!)
        let part = String(str[index...]).split(separator: "|")
        let date = f.date(from: String(part[0]))!
        let product: Product = Product.all[Int16(String(part[1]))!]!
        let station: Station = Station.all[String(part[2])]!
        return (date: date, product: product, station: station)
    }

    class func recordID(date: Date, product: Product, station: Station) -> CKRecordID {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return CKRecordID(recordName: "Price:\(f.string(from: date))|\(product.ident)|\(station.tradingName)")
    }

    var recordID: CKRecordID {
        return PriceOnDay.recordID(date: date, product: product, station: station)
    }

    func hasChanged(from record: CKRecord) -> Bool {
        if let dt = record["date"] as? Date {
            if dt != date {
                return true
            }
        }
        if let pri = record["price"] as? Int16 {
            if pri != price {
                return true
            }
        }
        if let pr = record["product"] as? CKReference {
            let id = Product.ident(from: pr.recordID)
            if product.ident != id {
                return true
            }
        }
        if let st = record["station"] as? CKReference {
            let tr = Station.tradingName(from: st.recordID)
            if station.tradingName != tr {
                return true
            }
        }
        return false
    }

    var record: CKRecord {
        get {
            let r: CKRecord
            if systemFields == nil {
                r = CKRecord(recordType: "FWPrice", recordID: recordID)
            } else {
                let unarchiver = NSKeyedUnarchiver(forReadingWith: systemFields!)
                unarchiver.requiresSecureCoding = true
                r = CKRecord(coder: unarchiver)!
            }
            r["date"] = date as NSDate
            r["price"] = price as NSNumber
            r["product"] = CKReference(record: product.record, action: .deleteSelf)
            r["station"] = CKReference(record: station.record, action: .deleteSelf)
            return r
        }
        set {
            systemFields = PriceOnDay.archiveSystemFields(from: newValue)
            if let dt = newValue["date"] as? Date {
                if dt != date {
                    date = dt
                }
            }
            if let pri = newValue["price"] as? Int16 {
                if pri != price {
                    price = pri
                }
            }
            if let pr = newValue["product"] as? CKReference {
                let id = Product.ident(from: pr.recordID)
                if product.ident != id {
//                    product = Product.fetch(withIdent: id)!
                }
            }
            if let st = newValue["station"] as? CKReference {
                let tr = Station.tradingName(from: st.recordID)
                if station.tradingName != tr {
//                    station = Station.fetch(withTradingName: tr)!
                }
            }
            // The problem with doing a save here is that another
            // record may be in the process of being created elsewhere
            // The answer is to allowthe save operation to fail and log
            // the failure, and hope that a later save works.
//            do {
//                try managedObjectContext!.save()
//            } catch {
//                let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "PriceOnDay.record.set")
//                os_log("Error on cloud read: %@", log: logger, type: .error, error.localizedDescription)
//            }
            // try! managedObjectContext!.save()
        }
    }
}

extension PriceOnDay {
//    class func update(price: Int16, day: Date, product: Product, station: Station, to context: NSManagedObjectContext) {
//        objc_sync_enter(Static.lock)
//        let priceOnDay = fetch(day: day as Date?, product: product, station: station, from: context)
//        if priceOnDay.count > 1 {
//            print("Duplicate PriceOnDay detected, \(day), \(product.name), \(station.tradingName)")
//            for p in priceOnDay.after(1) {
//                context.delete(p)
//            }
//        }
//        if let p = priceOnDay.first {
//            if p.price != price {
//                // Actually an error condition. Should never happen
//                DispatchQueue.main.async {
//                    print("Update price for \(station.tradingName) from \(p.price) to \(price)")
//                }
//                p.price = price
//            }
//        } else {
//            let p = create(in: context)
//            p.price = price
//            p.date = day
//            p.product = product
//            p.station = station
//        }
////        println("Update Begin")
//        // The problem with doing a save here is that another
//        // record may be in the process of being created elsewhere
//        // The answer is to allowthe save operation to fail and log
//        // the failure, and hope that a later save works.
//        do {
//            try context.save()
//        } catch {
//            let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "PriceOnDay.update")
//            os_log("Error on cloud read: %@", log: logger, type: .error, error.localizedDescription)
//        }
////        println("Update End")
//        objc_sync_exit(Static.lock)
//    }

}
