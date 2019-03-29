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

class PriceOnDay: FLODataEntity, Hashable {
    var hashValue: Int { return date.hashValue ^ (product.hashValue << 8) ^ (station.hashValue << 16)}

    static func == (lhs: PriceOnDay, rhs: PriceOnDay) -> Bool {
        return PriceOnDay.calendar.isDate(lhs.date, inSameDayAs: rhs.date) && lhs.product == rhs.product && lhs.station == rhs.station
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

    init(record: CKRecord) throws {
        let ident = try PriceOnDay.ident(from: record.recordID)
        date = ident.date
        product = ident.product
        station = ident.station
        price = record["price"] as! Int16
        systemFields = Brand.archiveSystemFields(from: record)
    }

    var adjustedPrice: Int16 {
        return price - (station.brand?.adjustment ?? 0)
    }
    
    static let lock = NSObject()
    static let calendar = Calendar.current
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yy"
        return f
    }()

    let keyRegx = try! NSRegularExpression(pattern: "^(\\d{4}-\\d+-\\d+)|(\\d+)|(.*)$")

    class func fetch(withIdent tradingName: String, _ completionBlock: @escaping (PriceOnDay?, Error?) -> Void) {
        let st = PriceOnDay.calendar.date(bySettingHour: 0, minute: 0, second: 0, of: MapViewController.instance!.globalDate)!
        let en = PriceOnDay.calendar.date(byAdding: .day, value: 1, to: st)!
        let prodRef = CKRecord.Reference(recordID: MapViewController.instance!.globalProduct.recordID, action: .none)
        let stRef = CKRecord.Reference(recordID: Station.recordId(from: tradingName), action: .none)
        let pred = NSPredicate(format: "date >= %@ && date < %@ && product == %@ && station == %@",
                               st as NSDate, en as NSDate, prodRef, stRef)
        let query = CKQuery(recordType: "FWPrice", predicate: pred)

        do {
            PriceOnDay.download(fromDatabase: try FLOCloud.shared.publicDatabase(), withQuery: query) { (error, records) in
                let price: PriceOnDay? = (records == nil || records!.isEmpty ? nil : try? PriceOnDay(record: records!.first!))
                completionBlock(price, error)
            }
        } catch {
            print("Error while submitting Price fetch (with block): \(error)")
        }
    }

    class func fetchAll(_ completionBlock: @escaping (Set<PriceOnDay>, Error?) -> Void) {
        let st = PriceOnDay.calendar.date(bySettingHour: 0, minute: 0, second: 0, of: MapViewController.instance!.globalDate)!
        let en = PriceOnDay.calendar.date(byAdding: .day, value: 1, to: st)!
        let prodRef = CKRecord.Reference(recordID: MapViewController.instance!.globalProduct.recordID, action: .none)
        let predicate = NSPredicate(format: "date >= %@ && date < %@ && product == %@",
                                    st as NSDate, en as NSDate, prodRef)
        let query = CKQuery(recordType: "FWPrice", predicate: predicate)

        do {
            PriceOnDay.download(fromDatabase: try FLOCloud.shared.publicDatabase(), withQuery: query) { (error, records) in
                let prices = Set<PriceOnDay>(records?.map({ try? PriceOnDay(record: $0) }).filter({$0 != nil}).map({$0!}) ?? [])
                completionBlock(prices, error)
            }
        } catch {
            print("Error while submitting Price fetch: \(error)")
        }
    }

    static func fetchAll(with stations: [Station], _ completionBlock: @escaping (Set<PriceOnDay>, Error?) -> Void) {
        let st = PriceOnDay.calendar.date(bySettingHour: 0, minute: 0, second: 0, of: MapViewController.instance!.globalDate)!
        let en = PriceOnDay.calendar.date(byAdding: .day, value: 1, to: st)!
        let prodRef = CKRecord.Reference(recordID: MapViewController.instance!.globalProduct.recordID, action: .none)
        let recs = stations.map({ station in CKRecord.Reference(recordID: PriceOnDay.recordID(date: MapViewController.instance!.globalDate,
                                                                                              product: MapViewController.instance!.globalProduct,
                                                                                              station: station),
                                                                action: .none)})
        let predicate: NSPredicate
        if stations.count > 0 {
            predicate = NSPredicate(format: "date >= %@ && date < %@ && product == %@ && station IN %@",
                                    st as NSDate, en as NSDate, prodRef, recs)
        } else {
            predicate = NSPredicate(format: "date >= %@ && date < %@ && product == %@",
                                    st as NSDate, en as NSDate, prodRef)
        }
        let query = CKQuery(recordType: "FWPrice", predicate: predicate)
        do {
            PriceOnDay.download(fromDatabase: try FLOCloud.shared.publicDatabase(), withQuery: query) { (error, records) in
                let prices = Set<PriceOnDay>(records?.map({ try? PriceOnDay(record: $0) }).filter({$0 != nil}).map({$0!}) ?? [])
                completionBlock(prices, error)
            }
        } catch {
            print("Error while submitting Price fetch: \(error)")
        }
    }

    static var all = FLODataEntityAll<String, PriceOnDay>()

    var key: String {
        get {
            return station.tradingName
        }
    }

    class func ident(from recordID: CKRecord.ID) throws -> (date: Date, product: Product, station: Station) {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let str = recordID.recordName
        let index = str.index(after: str.index(of: ":")!)
        let part = String(str[index...]).split(separator: "|")
        let date = f.date(from: String(part[0]))!
        let product: Product = Product.all[Int16(String(part[1]))!]!
        if let station: Station = Station.all[String(part[2])] {
            return (date: date, product: product, station: station)
        } else {
            throw NSError(domain: "Something", code: 1, userInfo: nil)
        }
    }

    class func recordID(date: Date, product: Product, station: Station) -> CKRecord.ID {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return CKRecord.ID(recordName: "Price:\(f.string(from: date))|\(product.ident)|\(station.tradingName)")
    }

    var recordID: CKRecord.ID {
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
        if let pr = record["product"] as? CKRecord.Reference {
            let id = Product.ident(from: pr.recordID)
            if product.ident != id {
                return true
            }
        }
        if let st = record["station"] as? CKRecord.Reference {
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
            r["product"] = CKRecord.Reference(record: product.record, action: .deleteSelf)
            r["station"] = CKRecord.Reference(record: station.record, action: .deleteSelf)
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
            if let pr = newValue["product"] as? CKRecord.Reference {
                let id = Product.ident(from: pr.recordID)
                if product.ident != id {
//                    product = Product.fetch(withIdent: id)!
                }
            }
            if let st = newValue["station"] as? CKRecord.Reference {
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

    static let defaults: Dictionary<String, PriceOnDay> = [:]

    static let retrievalNotificationName = Notification.Name(rawValue: "Price.RetrievalNotification")
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
