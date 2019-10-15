//
//  Statistics.swift
//  FuelLocator
//
//  Created by Owen Godfrey on 15/10/2014.
//  Copyright (c) 2014 Owen Godfrey. All rights reserved.
//

import Foundation
import CloudKit
import os.log

class Statistics: FLODataEntity, Hashable {
    static func == (lhs: Statistics, rhs: Statistics) -> Bool {
        return calendar.isDate(lhs.date, inSameDayAs: rhs.date) && lhs.product == rhs.product && lhs.region == rhs.region
    }

//    var hashValue: Int { return date.hashValue ^ (product.hashValue << 8) ^ ((region?.hashValue ?? 0) << 16)}
    func hash(into hasher: inout Hasher) {
        hasher.combine(date)
        hasher.combine(product)
        hasher.combine(region)
    }


    init(date: Date, product: Product, region: Region) {
        self.date = date
        self.product = product
        self.region = region
    }
    
    init(record: CKRecord) {
        date = record["date"] as! Date
        product = Product.all[Product.ident(from: (record["product"] as! CKRecord.Reference).recordID)]!
        if let rID = (record["region"] as? CKRecord.Reference)?.recordID {
            region = Region.all[Region.ident(from: rID)]
        }
        mean = record["mean"] as? NSNumber
        median = record["median"] as? NSNumber
        mode = record["mode"] as? NSNumber
        if let arr = record["percentiles"] as? NSArray {
            minimum = arr[0] as? NSNumber
            per10 = arr[1] as? NSNumber
            per20 = arr[2] as? NSNumber
            per30 = arr[3] as? NSNumber
            per40 = arr[4] as? NSNumber
            per50 = arr[5] as? NSNumber
            per60 = arr[6] as? NSNumber
            per70 = arr[7] as? NSNumber
            per80 = arr[8] as? NSNumber
            per90 = arr[9] as? NSNumber
            maximum = arr[10] as? NSNumber
        }
        systemFields = Brand.archiveSystemFields(from: record)
    }

    public var date: Date
    public var mean: NSNumber?
    public var median: NSNumber?
    public var mode: NSNumber?
    public var product: Product
    public var region: Region?
    public var minimum: NSNumber?
    public var per10: NSNumber?
    public var per20: NSNumber?
    public var per30: NSNumber?
    public var per40: NSNumber?
    public var per50: NSNumber?
    public var per60: NSNumber?
    public var per70: NSNumber?
    public var per80: NSNumber?
    public var per90: NSNumber?
    public var maximum: NSNumber?
    public var systemFields: Data?

    static let lock = NSObject()
    static let calendar = Calendar.current
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yy"
        return f
    }()

    class func fetch(withIdent ident: Int16, _ completionBlock: @escaping (Statistics?, Error?) -> Void) {
        let sd = PriceOnDay.calendar.date(bySettingHour: 0, minute: 0, second: 0, of: MapViewController.instance!.globalDate!)!
        let ed = PriceOnDay.calendar.date(byAdding: .day, value: 1, to: sd)!
        let pRef = CKRecord.Reference(recordID: MapViewController.instance!.globalProduct.recordID, action: .none)
        let sRef = CKRecord.Reference(recordID: Region.all[ident]!.recordID, action: .none)
        let pred = NSPredicate(format: "date >= %@ && date < %@ && product == %@ && region == %@", sd as NSDate, ed as NSDate, pRef, sRef)
        let query = CKQuery(recordType: "FWStatistics", predicate: pred)

        do {
            Statistics.download(fromDatabase: try FLOCloud.shared.publicDatabase(), withQuery: query) { (error, records) in
                let stats: Statistics? = (records == nil || records!.isEmpty ? nil : Statistics(record: records!.first!))
                completionBlock(stats, error)
            }
        } catch {
            print("Error while submitting Statistics fetch (with block): \(error)")
        }
    }

    class func fetchAll(_ completionBlock: @escaping (Set<Statistics>, Error?) -> Void) {
        let sd = PriceOnDay.calendar.date(bySettingHour: 0, minute: 0, second: 0, of: MapViewController.instance!.globalDate!)!
        let ed = PriceOnDay.calendar.date(byAdding: .day, value: 1, to: sd)!
        let pRef = CKRecord.Reference(recordID: MapViewController.instance!.globalProduct.recordID, action: .none)
        let predicate = NSPredicate(format: "date >= %@ && date < %@ && product == %@", sd as NSDate, ed as NSDate, pRef)
        let query = CKQuery(recordType: "FWStatistics", predicate: predicate)

        do {
            Statistics.download(fromDatabase: try FLOCloud.shared.publicDatabase(), withQuery: query) { (error, records) in
                let stats = Set<Statistics>(records?.map({ Statistics(record: $0) }) ?? [])
                completionBlock(stats, error)
            }
        } catch {
            print("Error while submitting Statistics fetch: \(error)")
        }
    }

    static func fetchAll(with stations: [Station], _ completionBlock: @escaping (Set<Statistics>, Error?) -> Void) {}

    class func fetchHistoric(_ product: Product, _ region: Region, _ dateRange: PartialRangeFrom<Date>? = nil, _ completionBlock: @escaping (Set<Statistics>, Error?) -> Void) {
        let pRef = CKRecord.Reference(recordID: product.recordID, action: .none)
        let rRef = CKRecord.Reference(recordID: region.recordID, action: .none)
        let predicate: NSPredicate
        if dateRange != nil {
            predicate = NSPredicate(format: "product == %@ AND region == %@ AND date >= %@",
                                    pRef, rRef, dateRange!.lowerBound as NSDate)
        } else {
            predicate = NSPredicate(format: "product == %@ AND region == %@", pRef, rRef)
        }
        let query = CKQuery(recordType: "FWStatistics", predicate: predicate)

        do {
            Statistics.download(fromDatabase: try FLOCloud.shared.publicDatabase(), withQuery: query) { (error, records) in
                let stats = Set<Statistics>(records?.map({ Statistics(record: $0) }) ?? [])
                completionBlock(stats, error)
            }
        } catch {
            print("Error while submitting Statistics fetch historic values: \(error)")
        }
    }

    static var all = FLODataEntityAll<Int16, Statistics>()

    var key: Int16 {
        get {
            return region?.ident ?? -1
        }
    }

    class func ident(from recordID: CKRecord.ID) -> (date: Date, product: Product, region: Region) {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
//        let part = String(recordID.recordName.substring(from: recordID.recordName.index(after: recordID.recordName.index(of: ":")!))).split(separator: "|")
        let str = recordID.recordName
        let index = str.index(after: str.firstIndex(of: ":")!)
        let part = String(str[index...]).split(separator: "|")
        let date = f.date(from: String(part[0]))!
//        let product = Product.fetch(withIdent: Int16(String(part[1]))!)!
//        let region = Region.fetch(withIdent: Int16(String(part[2]))!)!
        let product: Product! = nil
        let region: Region! = nil
        return (date: date, product: product, region: region)
    }
    
    class func recordID(date: Date, product: Product, region: Region?) -> CKRecord.ID {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return CKRecord.ID(recordName: "Statistics:\(f.string(from: date))|\(product.ident)|\(region?.ident ?? -1)")
    }

    var recordID: CKRecord.ID {
        return Statistics.recordID(date: date, product: product, region: region)
    }

    func hasChanged(from record: CKRecord) -> Bool {
        if let a = record["percentiles"] as? Array<NSNumber> {
            let b = NSNumber(value: -100)
            if a != [minimum ?? b, per10 ?? b, per20 ?? b, per30 ?? b, per30 ?? b, per40 ?? b, per50 ?? b, per60 ?? b, per70 ?? b, per80 ?? b, per90 ?? b, maximum ?? b] {
                if minimum != a[0] ||
                    per10 != a[1] ||
                    per20 != a[2] ||
                    per30 != a[3] ||
                    per40 != a[4] ||
                    per50 != a[5] ||
                    per60 != a[6] ||
                    per70 != a[7] ||
                    per80 != a[8] ||
                    per90 != a[9] ||
                    maximum != a[10]
                {
                    return true
                }
            }
            var v = record["mean"] as! NSNumber
            if mean != v {
                return true
            }
            v = record["mode"] as! NSNumber
            if mode != v {
                return true
            }
            v = record["median"] as! NSNumber
            if median != v {
                return true
            }
        }
        if ((record["date"] as? Date) ?? Date.distantFuture) != date {
            return true
        }
        if (record["region"] as? CKRecord.Reference) != CKRecord.Reference(recordID: Region.recordId(from: region!.ident), action: .deleteSelf) {
            return true
        }
        if (record["product"] as? CKRecord.Reference) != CKRecord.Reference(recordID: Product.recordId(from: product.ident), action: .deleteSelf) {
            return true
        }
        return false
    }

    var record: CKRecord {
        get {
            let r: CKRecord
            if systemFields == nil {
                r = CKRecord(recordType: "FWStatistics", recordID: recordID)
            } else {
                let unarchiver = NSKeyedUnarchiver(forReadingWith: systemFields!)
                unarchiver.requiresSecureCoding = true
                r = CKRecord(coder: unarchiver)!
            }
            if minimum != nil {
                let p10 = (per10 ?? minimum)!
                let p20 = (per20 ?? minimum)!
                let p30 = (per30 ?? minimum)!
                let p40 = (per40 ?? minimum)!
                let p50 = (per50 ?? minimum)!
                let p60 = (per60 ?? maximum)!
                let p70 = (per60 ?? maximum)!
                let p80 = (per80 ?? maximum)!
                let p90 = (per90 ?? maximum)!
                r["percentiles"] = [minimum!, p10, p20, p30, p40, p50, p60, p70, p80, p90, maximum!] as NSArray
            }
            r["mean"] = mean ?? minimum
            r["median"] = median ?? minimum
            r["mode"] = mode ?? minimum
            r["date"] = date as NSDate
            r["region"] = CKRecord.Reference.init(recordID: Region.recordId(from: region!.ident), action: .deleteSelf)
            r["product"] = CKRecord.Reference.init(recordID: Product.recordId(from: product.ident), action: .deleteSelf)
            return r
        }
        set {
            systemFields = Statistics.archiveSystemFields(from: newValue)
            if let a = newValue["percentiles"] as? Array<NSNumber> {
                let b = NSNumber(value: -100)
                if a != [minimum ?? b, per10 ?? b, per20 ?? b, per30 ?? b, per30 ?? b, per40 ?? b, per50 ?? b, per60 ?? b, per70 ?? b, per80 ?? b, per90 ?? b, maximum ?? b] {
                    minimum = a[0]
                    per10 = a[1]
                    per20 = a[2]
                    per30 = a[3]
                    per40 = a[4]
                    per50 = a[5]
                    per60 = a[6]
                    per70 = a[7]
                    per80 = a[8]
                    per90 = a[9]
                    maximum = a[10]
                }
                var v = newValue["mean"] as! NSNumber
                if mean != v {
                    mean = v
                }
                v = newValue["mode"] as! NSNumber
                if mode != v {
                    mode = v
                }
                v = newValue["median"] as! NSNumber
                if median != v {
                    median = v
                }
            }
            if ((record["date"] as? Date) ?? Date.distantFuture) != date {
                date = (record["date"] as! Date)
            }
            if (record["region"] as? CKRecord.Reference) != CKRecord.Reference(recordID: Region.recordId(from: region!.ident), action: .deleteSelf) {
//                region = Region.fetch(withIdent: Region.ident(from: (record["region"] as! CKReference).recordID))
            }
            if (record["product"] as? CKRecord.Reference) != CKRecord.Reference(recordID: Product.recordId(from: product.ident), action: .deleteSelf) {
//                product = Product.fetch(withIdent: Product.ident(from: (record["product"] as! CKReference).recordID))!
            }
//            do {
//                try managedObjectContext!.save()
//            } catch {
//                os_log("Error on managed object save: %@", type: .error, error.localizedDescription)
//            }
        }
    }

    static let defaults: Dictionary<Int16, Statistics> = [:]

    static let retrievalNotificationName = Notification.Name(rawValue: "Statistics.RetrievalNotification")
}

extension Statistics {
//    func update() -> Bool {
//        var altered = false
//        synchronized(Statistics.lock) {
//            //let metro = "Metro"
//            let daysPrices = PriceOnDay.fetch(day: date, product: product, region: region, from: context)
//
//            if !Static.calendar.isDateInTomorrow(date) || daysPrices.count > 0 {
//                let sortedPrices: [Int16] = daysPrices.map{$0.adjustedPrice}.sorted() as [Int16]
////                let today = Static.calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date())
////                let dateIndex = Static.calendar.dateComponents(Set<Calendar.Component>(arrayLiteral: Calendar.Component.day), from: today!, to: date).day! + 7
//                let sortedCounts = sortedPrices.runs(==)
//                let num = daysPrices.count
//                var minimum: Int16? = self.minimum as! Int16?
//                var maximum: Int16? = self.maximum as! Int16?
//                var per10: Int16? = self.per10 as! Int16?
//                var per20: Int16? = self.per20 as! Int16?
//                var per30: Int16? = self.per30 as! Int16?
//                var per40: Int16? = self.per40 as! Int16?
//                var per50: Int16? = self.per50 as! Int16?
//                var per60: Int16? = self.per60 as! Int16?
//                var per70: Int16? = self.per70 as! Int16?
//                var per80: Int16? = self.per80 as! Int16?
//                var per90: Int16? = self.per90 as! Int16?
//                var mean: Float? = self.mean as! Float?
//                var median: Float? = self.median as! Float?
//                var mode: Float? = self.mode as! Float?
//                if num > 0 {
//                    let tenthPercentile = Int(floor(Float(num-1) * 0.1))
//                    let twentithPercentile = Int(floor(Float(num-1) * 0.2))
//                    let thirtiethPercentile = Int(floor(Float(num-1) * 0.3))
//                    let fortiethPercentile = Int(floor(Float(num-1) * 0.4))
//                    let fiftiethPercentile = Int(floor(Float(num-1) * 0.5))
//                    let sixtiethPercentile = Int(floor(Float(num-1) * 0.6))
//                    let seventiethPercentile = Int(floor(Float(num-1) * 0.7))
//                    let eightiethPercentile = Int(floor(Float(num-1) * 0.8))
//                    let ninetiethPercentile = Int(ceil(Float(num-1) * 0.9))
//                    minimum = sortedPrices.first!
//                    maximum = sortedPrices.last!
//                    print(num)
//                    mean = sortedPrices.map({Float($0)}).reduce(0, +) / Float(num)
//                    median = (num % 2 == 1) ?
//                        Float(sortedPrices[num/2]) :
//                        Float(sortedPrices[num/2-1] + sortedPrices[num/2]) / 2.0
//                    per10 = sortedPrices[tenthPercentile]
//                    per20 = sortedPrices[twentithPercentile]
//                    per30 = sortedPrices[thirtiethPercentile]
//                    per40 = sortedPrices[fortiethPercentile]
//                    per50 = sortedPrices[fiftiethPercentile]
//                    per60 = sortedPrices[sixtiethPercentile]
//                    per70 = sortedPrices[seventiethPercentile]
//                    per80 = sortedPrices[eightiethPercentile]
//                    per90 = sortedPrices[ninetiethPercentile]
//                    let reverseFreqSortedCounts = sortedCounts.sorted{$0.count>$1.count}
//                    let modalNum = reverseFreqSortedCounts.first?.count
//                    let modeCount = reverseFreqSortedCounts.filter{$0.count == modalNum}.map{$0.value}
//                    let modeNum = Float(modeCount.count)
//                    mode = Float(modeCount.reduce(0) { $0 + $1 } ) / modeNum
//                }
//                if self.minimum as! Int16? != minimum {
//                    altered = true
//                    self.minimum = minimum as NSNumber?
//                }
//                if self.maximum as! Int16? != maximum {
//                    altered = true
//                    self.maximum = maximum as NSNumber?
//                }
//                if self.per10 as! Int16? != per10 {
//                    altered = true
//                    self.per10 = per10 as NSNumber?
//                }
//                if self.per20 as! Int16? != per20 {
//                    altered = true
//                    self.per20 = per20 as NSNumber?
//                }
//                if self.per30 as! Int16? != per30 {
//                    altered = true
//                    self.per30 = per30 as NSNumber?
//                }
//                if self.per40 as! Int16? != per40 {
//                    altered = true
//                    self.per40 = per40 as NSNumber?
//                }
//                if self.per50 as! Int16? != per50 {
//                    altered = true
//                    self.per50 = per50 as NSNumber?
//                }
//                if self.per60 as! Int16? != per60 {
//                    altered = true
//                    self.per60 = per60 as NSNumber?
//                }
//                if self.per70 as! Int16? != per70 {
//                    altered = true
//                    self.per70 = per70 as NSNumber?
//                }
//                if self.per80 as! Int16? != per80 {
//                    altered = true
//                    self.per80 = per80 as NSNumber?
//                }
//                if self.per90 as! Int16? != per90 {
//                    altered = true
//                    self.per90 = per90 as NSNumber?
//                }
//                if self.mean as! Float? != mean {
//                    altered = true
//                    self.mean = mean as NSNumber?
//                }
//                if self.median as! Float? != median {
//                    altered = true
//                    self.median = median as NSNumber?
//                }
//                if self.mode as! Float? != mode {
//                    altered = true
//                    self.mode = mode as NSNumber?
//                }
//                do {
//                    try context.save()
//                } catch {
//                    os_log("Error on managed object save: %@", type: .error, error.localizedDescription)
//                }
//            }
//        }
//        return altered
//    }
//
//    class func updateAll() {
//        print("*** *** Updating all statistics *** ***")
//        class Something {
//            let date: Date
//            let product: Product
//            let region: Region?
//            init (date: Date, product: Product, region: Region?) {
//                self.date = date
//                self.product = product
//                self.region = region
//            }
//        }
//        let set = NSMutableSet()
//        for price in PriceOnDay.fetchAll(from: context) {
//            for region in price.station.suburb?.region ?? [] {
//                set.add(Something(date: price.date, product: price.product, region: region))
//            }
//        }
//        for item in set {
//            let something = item as! Something
//            _ = update(date: something.date as Date, product: something.product, region:something.region)
//        }
//        print("*** *** Updating all statistics Complete *** ***")
//    }
//
//    class func update(date: Date, product: Product, region: Region?) -> Bool {
//        var altered = false
////        let metro = "Metro"
////        println("Updating statistics for date \(Static.formatter.stringFromDate(date)), product \(product.name), region \(region?.name ?? metro)")
//        var statistics: Statistics! = self.fetch(withDate: date, product: product, region: region, from: context)
//        let daysPrices = PriceOnDay.fetch(day: date as Date, product: product, region: region, from: context)
//
//        if statistics != nil || !Static.calendar.isDateInTomorrow(date as Date) || daysPrices.count > 0 {
//            if statistics == nil {
//                statistics = Statistics.create(in: context)
//                statistics.date = date as Date
//                statistics.product = product
//                statistics.region = region
//                statistics.minimum = nil
//                statistics.maximum = nil
//                statistics.per10 = nil
//                statistics.per20 = nil
//                statistics.per30 = nil
//                statistics.per40 = nil
//                statistics.per50 = nil
//                statistics.per60 = nil
//                statistics.per70 = nil
//                statistics.per80 = nil
//                statistics.per90 = nil
//                statistics.mean = nil
//                statistics.median = nil
//                statistics.mode = nil
//                altered = true
//                do {
//                    try context.save()
//                } catch {
//                    os_log("Error on managed object save: %@", type: .error, error.localizedDescription)
//                }
//            }
//        } else if statistics == nil && !Static.calendar.isDateInTomorrow(date as Date) && daysPrices.count == 0 {
//            statistics = Statistics.create(in: context)
//            statistics.date = date as Date
//            statistics.product = product
//            statistics.region = region
//            statistics.minimum = nil
//            statistics.maximum = nil
//            statistics.per10 = nil
//            statistics.per20 = nil
//            statistics.per30 = nil
//            statistics.per40 = nil
//            statistics.per50 = nil
//            statistics.per60 = nil
//            statistics.per70 = nil
//            statistics.per80 = nil
//            statistics.per90 = nil
//            statistics.mean = nil
//            statistics.median = nil
//            statistics.mode = nil
//            do {
//                try context.save()
//            } catch {
//                os_log("Error on managed object save: %@", type: .error, error.localizedDescription)
//            }
//        }
//        if statistics?.update(to: context) ?? false {
//            altered = true
//        }
//        return altered
//    }
}
