//
//  ValidationState.swift
//  Bemo
//
//  Validation state model for tangram puzzle assemblies
//

import Foundation

enum ValidationState: Equatable {
    case unknown
    case valid
    case invalid(reason: String)
    case warning(message: String)
    
    var isValid: Bool {
        switch self {
        case .valid:
            return true
        case .unknown, .invalid, .warning:
            return false
        }
    }
}