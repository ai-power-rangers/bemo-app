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
    
    /// Logger for piece placement operations
    static let tangramPlacement = Logger(subsystem: "com.bemo.devtools", category: "TangramEditor.Placement")
    
    /// Logger for connection operations
    static let tangramConnections = Logger(subsystem: "com.bemo.devtools", category: "TangramEditor.Connections")
}

// MARK: - Debug Logging Configuration

struct TangramEditorDebug {
    /// Enable verbose debug logging (set to false for production)
    static let verboseLogging = true
    
    /// Enable connection point logging
    static let logConnections = true
    
    /// Enable placement calculation logging
    static let logPlacement = true
    
    /// Enable validation logging
    static let logValidation = true
}

// MARK: - Logging Helpers

extension Logger {
    
    /// Log connection point selection with details
    func logConnectionSelection(
        type: String,
        pieceType: PieceType? = nil,
        connectionType: String,
        index: Int,
        position: CGPoint
    ) {
        guard TangramEditorDebug.logConnections else { return }
        
        if let pieceType = pieceType {
            self.info("[\(type)] Selected \(connectionType) connection: piece=\(pieceType.rawValue) index=\(index) pos=(\(String(format: "%.1f", position.x)), \(String(format: "%.1f", position.y)))")
        } else {
            self.info("[\(type)] Selected \(connectionType) connection: index=\(index) pos=(\(String(format: "%.1f", position.x)), \(String(format: "%.1f", position.y)))")
        }
    }
    
    /// Log placement calculation details
    func logPlacementCalculation(
        pieceType: PieceType,
        rotation: Double,
        isFlipped: Bool,
        connectionCount: Int,
        success: Bool,
        reason: String? = nil
    ) {
        guard TangramEditorDebug.logPlacement else { return }
        
        let rotationDeg = rotation * 180.0 / .pi
        if success {
            self.info("[Placement] SUCCESS: piece=\(pieceType.rawValue) rotation=\(String(format: "%.0f", rotationDeg))° flipped=\(isFlipped) connections=\(connectionCount)")
        } else {
            self.error("[Placement] FAILED: piece=\(pieceType.rawValue) rotation=\(String(format: "%.0f", rotationDeg))° flipped=\(isFlipped) connections=\(connectionCount) reason=\(reason ?? "unknown")")
        }
    }
    
    /// Log validation results
    func logValidation(
        type: String,
        passed: Bool,
        details: String
    ) {
        guard TangramEditorDebug.logValidation else { return }
        
        if passed {
            self.debug("[Validation] ✅ \(type): \(details)")
        } else {
            self.warning("[Validation] ❌ \(type): \(details)")
        }
    }
}