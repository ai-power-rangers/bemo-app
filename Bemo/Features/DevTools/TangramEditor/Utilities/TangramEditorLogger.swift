//
//  TangramEditorLogger.swift
//  Bemo
//
//  Logging utilities for Tangram Editor
//

import Foundation
import OSLog

extension Logger {
    /// Logger for Tangram Editor subsystem
    static let tangramEditor = Logger(subsystem: "com.bemo.devtools", category: "TangramEditor")
    
    /// Logger for editor state changes
    static let tangramEditorState = Logger(subsystem: "com.bemo.devtools", category: "TangramEditor.State")
    
    /// Logger for editor persistence operations
    static let tangramEditorPersistence = Logger(subsystem: "com.bemo.devtools", category: "TangramEditor.Persistence")
    
    /// Logger for editor validation
    static let tangramEditorValidation = Logger(subsystem: "com.bemo.devtools", category: "TangramEditor.Validation")
}