//
//  FLODataEntity.swift
//  Fuel Locator OSX
//
//  Created by Owen Godfrey on 12/8/17.
//  Copyright © 2017 Owen Godfrey. All rights reserved.
//

import CloudKit
import os.log

protocol FLODataEntity: Hashable {
    associatedtype Key: Hashable
    associatedtype Value: FLODataEntity

    var record: CKRecord { get set }

    var systemFields: Data? { get set }

    var recordID: CKRecord.ID { get }

    func hasChanged(from record: CKRecord) -> Bool

    static func fetch(withIdent ident: Key, _ completionBlock: @escaping (Value?, Error?) -> Void)

    static func fetchAll(_ completionBlock: @escaping (Set<Value>, Error?) -> Void)

    static var all: FLODataEntityAll<Key, Value> { get }

    static var defaults: Dictionary<Key, Value> { get }

    static var retrievalNotificationName: Notification.Name { get }

    var initialiser: String { get }

    var key: Key { get }
}

class FLODataEntityAll<K: Hashable, V: FLODataEntity>: NSObject {
    private var _all: [K: V] = [:]
    private(set) var hasData = false
    var queue = FLOCloud.shared.queue
    var lock: pthread_rwlock_t

    override init() {
        lock = pthread_rwlock_t()
        let status = pthread_rwlock_init(&lock, nil)
        super.init()
        assert(status == 0)
    }

    deinit {
        let status = pthread_rwlock_destroy(&lock)
        assert(status == 0)
    }

    subscript(_ ident: K) -> V? {
        guard pthread_rwlock_tryrdlock(&lock) == 0  else {
            return V.defaults[ident as! V.Key] as? V
        }
        defer { pthread_rwlock_unlock(&lock) }
        guard _all.keys.contains(ident)  else {
            return V.defaults[ident as! V.Key] as? V
        }
        return _all[ident]
    }

    var values: Dictionary<K, V>.Values! {
        guard pthread_rwlock_tryrdlock(&lock) == 0  else {
            return V.defaults.values as? Dictionary<K, V>.Values
        }
        defer { pthread_rwlock_unlock(&lock) }
        return _all.values
    }

    var keys: Dictionary<K, V>.Keys! {
        guard pthread_rwlock_tryrdlock(&lock) == 0  else {
            return V.defaults.keys as? Dictionary<K, V>.Keys
        }
        defer { pthread_rwlock_unlock(&lock) }
        return _all.keys
    }

    func retrieve(_ block: ((Bool, Error?)->Void)? = nil) {
        FLOCloud.shared.queue.async {
            pthread_rwlock_wrlock(&self.lock)
            self.hasData = false
            V.fetchAll({ (sts, err) in
                FLOCloud.shared.queue.async {
                    guard err == nil else {
                        let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "FLODataEntity.retrieve")
                        os_log("Error on retrieval: %@", log: logger, type: .error, err!.localizedDescription)
                        print(err!)
                        DispatchQueue.main.async {
                            pthread_rwlock_unlock(&self.lock)
                            block?(false, err)
                        }
                        return
                    }
                    self._all = sts.reduce(into: [K: V](), { (dict, element) -> Void in
                        dict[element.key as! K] = (element as! V)
                    })
                    self.hasData = true

//                    print("Retrieved \(String(describing: V.self).split(separator: ".")[0])")

//                    if V.self == Brand.self || V.self == Product.self || V.self == Suburb.self || V.self == Region.self || V.self == Station.self {
//                        print("    static let defaults: Dictionary<\(K.self), \(V.self)> = [")
//                        for (_, v) in self._all {
//                            print("        \(v.initialiser),")
//                        }
//                        print("    ]")
//                    }

                    DispatchQueue.main.async {
                        pthread_rwlock_unlock(&self.lock)
                        V.notify()
                        block?(true, nil)
                    }
                }
            })
        }
    }
}

extension FLODataEntity {

    /// Creates an archive of system fields from a record
    ///
    /// - Parameter record: The record whose system fields are to be archived
    /// - Returns: The archived system fields
    static func archiveSystemFields(from record: CKRecord) -> Data {
        let data = NSMutableData()
        let archiver = NSKeyedArchiver(forWritingWith: data)
        archiver.requiresSecureCoding = true
        record.encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return data as Data
    }

    /// Uploads the entity to the cloud asynchronously
    ///
    /// - Parameters:
    ///   - database: The cloud kit database to upload to
    ///   - attempt: The number of prior attempts
    ///   - completion: A completion block to be called when then state is ultimately known
    func upload(toDatabase database: CKDatabase = try! FLOCloud.shared.publicDatabase(),
                attempt: Int = 0,
                completion: ((_ error: Error?, _ success: Bool)->Void)? = nil) throws {
        database.save(record) { (rec, err) in
            guard err == nil else {
                guard attempt < 10 else {
                    DispatchQueue.main.async {
                        completion?(err, false)
                    }
                    return
                }
                switch err {
                case let error as CKError:
                    let retryAfter = error.userInfo[CKErrorRetryAfterKey] as? Double
                    switch error.code {
                    case .serverRecordChanged:
                        // An error indicating that the record was rejected because the version on the server is different.
                        try! self.download(fromDatabase: database, attempt: attempt, completion: { (error, success) in
                            guard error == nil else {
                                completion?(error, false)
                                return
                            }
                            guard success else {
                                completion?(nil, false)
                                return
                            }
                            try! self.upload(toDatabase: database, attempt: attempt+1, completion: completion)
                        })

                    case .requestRateLimited:
                        // Transfers to and from the server are being rate limited for the client at this time.
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + (retryAfter ?? pow(2.0, Double(attempt)))) {
                            try! self.upload(toDatabase: database, attempt: attempt+1, completion: completion)
                        }

                    case .partialFailure:
                        // An error indicating that some items failed, but the operation succeeded overall.
                        let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "FLODataEntity.upload.partialFailure")
                        os_log("Error on cloud read: %@", log: logger, type: .error, error.localizedDescription)
                        DispatchQueue.main.async {
                            if let record = rec {
                                var s = self
                                s.record = record
                                completion?(nil, true)
                            } else {
                                completion?(nil, false)
                            }
                        }

                    case .networkFailure, .networkUnavailable, .internalError, .serviceUnavailable:
                        // An error that is returned when the network is available but cannot be accessed.
                        // An error that is returned when the network is not available.
//                        let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "FLODataEntity.upload.networkFailure")
//                        os_log("Error on cloud read: %@", log: logger, type: .error, error.localizedDescription)
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + (retryAfter ?? pow(2.0, Double(attempt)))) {
                            try! self.upload(toDatabase: database, attempt: attempt+1, completion: completion)
                        }

                    case .unknownItem:
                        // The recorded system fields point to a record that doesn't exist, perhaps because it has been deleted
                        DispatchQueue.main.async {
                            guard self.systemFields != nil else {
                                completion?(err, false)
                                return
                            }
                            var s = self
                            s.systemFields = nil
                            let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "FLODataEntity.upload.unknownItem")
                            os_log("Error on cloud read: %@", log: logger, type: .error, error.localizedDescription)
                            try! self.upload(toDatabase: database, attempt: attempt+1, completion: completion)
                        }

                    case .serverRejectedRequest:
                        let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "FLODataEntity.upload.serverRejected")
                        os_log("Derver rejected upload: %@", log: logger, type: .error, err!.localizedDescription)
                        DispatchQueue.main.async {
                            completion?(error, false)
                        }

                    default:
                        let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "FLODataEntity.upload.default")
                        os_log("Error: %@", log: logger, type: .error, err!.localizedDescription)
                        DispatchQueue.main.async {
                            completion?(error, false)
                        }
                    }

                default:
                    let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "FLODataEntity.upload.default")
                    os_log("Error: %@", log: logger, type: .error, err!.localizedDescription)
                    DispatchQueue.main.async {
                        completion?(err, false)
                    }
                }
                return
            }
            guard let record = rec else {
                DispatchQueue.main.async {
                    completion?(nil, false)
                }
                return
            }
            DispatchQueue.main.async {
                var s = self
                s.record = record
                completion?(nil, true)
            }
        }
    }

    /// Downloads the entity from the cloud kit database asynchronously
    ///
    /// - Parameters:
    ///   - database: The database to download from
    ///   - attempt: The number of prior atempts
    ///   - completion: A completion block to be called once the state is finally determined.
    func download(fromDatabase database: CKDatabase = try! FLOCloud.shared.publicDatabase(),
                  attempt: Int = 0,
                  completion: ((_ error: Error?, _ success: Bool)->Void)? = nil) throws {
        database.fetch(withRecordID: recordID) { (rec, err) in
            guard err == nil else {
                switch err {
                case let error as CKError:
                    let retryAfter = error.userInfo[CKErrorRetryAfterKey] as? Double
                    switch error.code {
                    case .requestRateLimited:
                        // Transfers to and from the server are being rate limited for the client at this time.
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + (retryAfter ?? pow(2.0, Double(attempt)))) {
                            try! self.download(fromDatabase: database, attempt: attempt+1, completion: completion)
                        }

                    case .partialFailure:
                        // An error indicating that some items failed, but the operation succeeded overall.
                        os_log("Error on cloud read: %@", type: .error, error.localizedDescription)
                        DispatchQueue.main.async {
                            if let record = rec {
                                var s = self
                                s.record = record
                                completion?(nil, true)
                            } else {
                                completion?(nil, false)
                            }
                        }

                    case .networkFailure, .networkUnavailable, .internalError, .serverRejectedRequest:
                        // An error that is returned when the network is available but cannot be accessed.
                        // An error that is returned when the network is not available.
                        os_log("Error on cloud read: %@", type: .error, error.localizedDescription)
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + (retryAfter ?? pow(2.0, Double(attempt)))) {
                            try! self.download(fromDatabase: database, attempt: attempt+1, completion: completion)
                        }

                    case .unknownItem:
                        DispatchQueue.main.async {
                            var s = self
                            s.systemFields = nil
                            completion?(nil, true)
                        }

                    default:
                        DispatchQueue.main.async {
                            completion?(error, false)
                        }
                    }

                default:
                    DispatchQueue.main.async {
                        completion?(err, false)
                    }
                }
                return
            }

            guard let record = rec else {
                DispatchQueue.main.async {
                    completion?(nil, false)
                }
                return
            }
            
            DispatchQueue.main.async {
                var s = self
                s.record = record
                completion?(nil, true)
            }
        }
    }

    /// Downloads the entity from the cloud kit database asynchronously
    ///
    /// - Parameters:
    ///   - database: The database to download from
    ///   - attempt: The number of prior atempts
    ///   - completion: A completion block to be called once the state is finally determined.
    static func download(fromDatabase database: CKDatabase = try! FLOCloud.shared.publicDatabase(),
                         withRecordID recordID: CKRecord.ID,
                         attempt: Int = 0,
                         completion: ((_ error: Error?, _ record: CKRecord?)->Void)? = nil) throws {
        database.fetch(withRecordID: recordID) { (rec, err) in
            guard err == nil else {
                switch err {
                case let error as CKError:
                    let retryAfter = error.userInfo[CKErrorRetryAfterKey] as? Double
                    switch error.code {
                    case .requestRateLimited:
                        // Transfers to and from the server are being rate limited for the client at this time.
                        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + (retryAfter ?? pow(2.0, Double(attempt)))) {
                            try! Self.download(fromDatabase: database, withRecordID: recordID, attempt: attempt+1, completion: completion)
                        }

                    case .partialFailure:
                        // An error indicating that some items failed, but the operation succeeded overall.
                        os_log("Error on cloud read: %@", type: .error, error.localizedDescription)
                        DispatchQueue.main.async {
                            if let record = rec {
                                completion?(nil, record)
                            } else {
                                completion?(nil, nil)
                            }
                        }

                    case .networkFailure, .networkUnavailable, .internalError, .serverRejectedRequest:
                        // An error that is returned when the network is available but cannot be accessed.
                        // An error that is returned when the network is not available.
                        os_log("Error on cloud read: %@", type: .error, error.localizedDescription)
                        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + (retryAfter ?? pow(2.0, Double(attempt)))) {
                            try! self.download(fromDatabase: database, withRecordID: recordID, attempt: attempt+1, completion: completion)
                        }

                    case .unknownItem:
                        DispatchQueue.main.async {
                            completion?(nil, nil)
                        }

                    default:
                        DispatchQueue.main.async {
                            completion?(error, nil)
                        }
                    }

                default:
                    DispatchQueue.main.async {
                        completion?(err, nil)
                    }
                }
                return
            }

            guard let record = rec else {
                DispatchQueue.main.async {
                    completion?(nil, nil)
                }
                return
            }

            DispatchQueue.main.async {
                completion?(nil, record)
            }
        }
    }

    /// Downloads the entity from the cloud kit database asynchronously
    ///
    /// - Parameters:
    ///   - database: The database to download from
    ///   - attempt: The number of prior atempts
    ///   - completion: A completion block to be called once the state is finally determined.
    static func download(fromDatabase database: CKDatabase,
                         withQuery query: CKQuery? = nil,
                         withCursor cursor0: CKQueryOperation.Cursor? = nil,
                         attempt: Int = 0,
                         accumulator: [CKRecord] = [CKRecord](),
                         completion: ((_ error: Error?, _ records: [CKRecord]?) -> Void)? = nil) {
        var results = Array<CKRecord>(accumulator)
        let operation = query != nil ? CKQueryOperation(query: query!) : CKQueryOperation(cursor: cursor0!)
        operation.recordFetchedBlock = { (record) in
            results.append(record)
        }
        operation.queryCompletionBlock = { (cursor, err) in
            guard err == nil else {
                switch err {
                case let error as CKError:
                    let retryAfter = error.userInfo[CKErrorRetryAfterKey] as? Double
                    switch error.code {
                    case .requestRateLimited:
                        // Transfers to and from the server are being rate limited for the client at this time.
                        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + (retryAfter ?? pow(2.0, Double(attempt)))) {
                            if cursor != nil {
                                Self.download(fromDatabase: database, withCursor: cursor, attempt: attempt+1, accumulator: results, completion: completion)
                            } else {
                                Self.download(fromDatabase: database, withQuery: query, attempt: attempt+1, accumulator: results, completion: completion)
                            }
                        }

                    case .partialFailure:
                        // An error indicating that some items failed, but the operation succeeded overall.
                        os_log("Error on cloud read: %@", type: .error, error.localizedDescription)
                        DispatchQueue.main.async {
                            if results.count > 0 {
                                completion?(nil, results)
                            } else {
                                completion?(nil, nil)
                            }
                        }

                    case .networkFailure, .networkUnavailable, .internalError, .serverRejectedRequest:
                        // An error that is returned when the network is available but cannot be accessed.
                        // An error that is returned when the network is not available.
                        os_log("Error on cloud read: %@", type: .error, error.localizedDescription)
                        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + (retryAfter ?? pow(2.0, Double(attempt)))) {
                            if cursor != nil {
                                Self.download(fromDatabase: database, withCursor: cursor, attempt: attempt+1, accumulator: results, completion: completion)
                            } else {
                                Self.download(fromDatabase: database, withQuery: query, attempt: attempt+1, accumulator: results, completion: completion)
                            }
                        }

                    case .unknownItem:
                        DispatchQueue.main.async {
                            completion?(nil, nil)
                        }

                    default:
                        DispatchQueue.main.async {
                            completion?(error, nil)
                        }
                    }

                default:
                    DispatchQueue.main.async {
                        completion?(err, nil)
                    }
                }
                return
            }

            if cursor != nil {
                DispatchQueue.global().async {
                    Self.download(fromDatabase: database, withCursor: cursor, accumulator: results, completion: completion)
                }
            } else {
                DispatchQueue.main.async {
                    completion?(nil, results.count > 0 ? results : nil)
                }
            }
        }
        database.add(operation)
    }

    var initialiser: String {
        get {
            return ""
        }
    }

    static func notify() {
        NotificationCenter.default.post(Notification(name: retrievalNotificationName))
    }
}
