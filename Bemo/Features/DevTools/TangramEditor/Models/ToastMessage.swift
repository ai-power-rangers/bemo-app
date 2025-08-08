//
//  ToastMessage.swift
//  Bemo
//
//  Model for toast notification messages
//

// WHAT: Data model for toast notifications displayed to users
// ARCHITECTURE: Model in MVVM-S pattern, used by ToastService and ToastView
// USAGE: Created by services/ViewModels when user feedback is needed

import Foundation

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let severity: Severity
    let duration: TimeInterval
    
    enum Severity {
        case error
        case warning
        case info
        case success
        
        var iconName: String {
            switch self {
            case .error:
                return "xmark.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            case .info:
                return "info.circle.fill"
            case .success:
                return "checkmark.circle.fill"
            }
        }
        
        var color: String {
            switch self {
            case .error:
                return "red"
            case .warning:
                return "orange"
            case .info:
                return "blue"
            case .success:
                return "green"
            }
        }
    }
    
    static func error(_ message: String) -> ToastMessage {
        ToastMessage(text: message, severity: .error, duration: 3.0)
    }
    
    static func warning(_ message: String) -> ToastMessage {
        ToastMessage(text: message, severity: .warning, duration: 2.5)
    }
    
    static func info(_ message: String) -> ToastMessage {
        ToastMessage(text: message, severity: .info, duration: 2.0)
    }
    
    static func success(_ message: String) -> ToastMessage {
        ToastMessage(text: message, severity: .success, duration: 2.0)
    }
}