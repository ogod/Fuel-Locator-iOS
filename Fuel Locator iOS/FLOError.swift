//
//  FLOError.swift
//  Fuel Locator OSX
//
//  Created by Owen Godfrey on 14/6/17.
//  Copyright © 2017 Owen Godfrey. All rights reserved.
//

import Foundation

enum FLOError: Error {
    case stationUpdateBlankName
    case stationNotEnoughDataToCreate(String?, String?, String?)
    case stationUpdateSaveError(Error)
    case cloudDatabaseNotAvailable
}

extension FLOError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .stationUpdateBlankName:
            return "Station update with a blank name"
        case .stationNotEnoughDataToCreate:
            return "Not enough details to create station"
        case .stationUpdateSaveError:
            return "Error during station update save"
        case .cloudDatabaseNotAvailable:
            return "The cloud database is not available"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .stationUpdateBlankName:
            return "Attempting to update a station with a blank name is illegal"
        case .stationNotEnoughDataToCreate(let tradingName, let brandName, let suburbName):
            return "Station doesn't have enough details, trading name '\(tradingName ?? "<nil>")', brand '\(brandName ?? "<nil>"), suburb '\(suburbName ?? "<nil>")'"
        case .stationUpdateSaveError(let error):
            return "There was an error during the station update save: \(error.localizedDescription)"
        case .cloudDatabaseNotAvailable:
            return "The user has not signed in with their iCloud credentials, or iCloud Drive has not been selected"
        }
    }

    var helpAnchor: String? {
        switch self {
        default:
            return nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .cloudDatabaseNotAvailable:
            return "Open system preferences, select iCloud and sign it. Ensure that iCloud Drive is selected."
        default:
            return nil
        }
    }

}
