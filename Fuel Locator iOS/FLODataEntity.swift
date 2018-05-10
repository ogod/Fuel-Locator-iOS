//
//  FLODataEntity.swift
//  Fuel Locator OSX
//
//  Created by Owen Godfrey on 12/8/17.
//  Copyright © 2017 Owen Godfrey. All rights reserved.
//

import CloudKit
import os.log

protocol FLODataEntity {

    var record: CKRecord { get set }

    var systemFields: Data? { get set }

    var recordID: CKRecordID { get }

    func hasChanged(from record: CKRecord) -> Bool

}

extension FLODataEntity {
    /// Creates an archive of system fields from a record
    ///
    /// - Parameter record: The record whose system fields are to be archived
    /// - Returns: The archived system fields
    static func archiveSystemFields(from record: CKRecord) -> Data? {
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
                                var s = (self as FLODataEntity)
                                s.record = record
                                completion?(nil, true)
                            } else {
                                completion?(nil, false)
                            }
                        }

                    case .networkFailure, .networkUnavailable, .internalError, .serviceUnavailable:
                        // An error that is returned when the network is available but cannot be accessed.
                        // An error that is returned when the network is not available.
                        let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "FLODataEntity.upload.networkFailure")
                        os_log("Error on cloud read: %@", log: logger, type: .error, error.localizedDescription)
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + (retryAfter ?? pow(2.0, Double(attempt)))) {
                            os_log("Mark 0 : Enter", log: logger, type: .debug)
                            try! self.upload(toDatabase: database, attempt: attempt+1, completion: completion)
                            os_log("Mark 0 : Exit", log: logger, type: .debug)
                        }

                    case .unknownItem:
                        // The recordedsystem fields point to a record that doesn't exist, perhaps because it has been deleted
                        DispatchQueue.main.async {
                            guard self.systemFields != nil else {
                                completion?(err, false)
                                return
                            }
                            var s = (self as FLODataEntity)
                            s.systemFields = nil
                            let logger = OSLog(subsystem: "com.nomdejoye.Fuel-Locator-OSX", category: "FLODataEntity.upload.unknownItem")
                            os_log("Error on cloud read: %@", log: logger, type: .error, error.localizedDescription)
                            try! self.upload(toDatabase: database, attempt: attempt+1, completion: completion)
                        }

                    case .serverRejectedRequest:
                        print("Record name: \(self.record.recordID.recordName)")
                        DispatchQueue.main.async {
                            completion?(error, false)
                        }

                    default:
                        print("Default error return: \(String(reflecting: error)), \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            completion?(error, false)
                        }
                    }

                default:
                    print("Default error return: \(err?.localizedDescription ?? "")")
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
                var s = (self as FLODataEntity)
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
                                var s = (self as FLODataEntity)
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
                            var s = (self as FLODataEntity)
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
                var s = (self as FLODataEntity)
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
                         withRecordID recordID: CKRecordID,
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
                         withCursor cursor0: CKQueryCursor? = nil,
                         attempt: Int = 0,
                         accumulator: [CKRecord] = [CKRecord](),
                         completion: ((_ error: Error?, _ records: [CKRecord]?) -> Void)? = nil) {
        var results = Array<CKRecord>(accumulator)
        let operation = query != nil ? CKQueryOperation(query: query!) : CKQueryOperation(cursor: cursor0!)
        operation.recordFetchedBlock = { (record) in
            results.append(record)
            print("result found \(record.recordID)")
        }
        operation.queryCompletionBlock = { (cursor, err) in
            guard err == nil else {
                print(err!)
                switch err {
                case let error as CKError:
                    print("\(error.localizedDescription)")
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
                    print("next cursor")
                    Self.download(fromDatabase: database, withCursor: cursor, accumulator: results, completion: completion)
                }
            } else {
                DispatchQueue.main.async {
                    print("completed")
                    completion?(nil, results.count > 0 ? results : nil)
                }
            }
        }
        database.add(operation)
    }
}
