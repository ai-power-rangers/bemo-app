//
//  CVEventBus.swift
//  Bemo
//
//  Event bus for CV event distribution
//

// WHAT: Central event bus for distributing CV events between scene sections
// ARCHITECTURE: Publisher-subscriber pattern for decoupled communication
// USAGE: Physical world emits events, digital displays subscribe

import Foundation
import Combine

class CVEventBus: ObservableObject {
    static let shared = CVEventBus()
    
    // Published for SwiftUI observation
    @Published private(set) var lastEvent: TangramCVEvent?
    @Published private(set) var lastFrame: CVFrameEvent?
    @Published private(set) var eventCount: Int = 0
    
    private var subscribers: [UUID: (TangramCVEvent) -> Void] = [:]
    private var frameSubscribers: [UUID: (CVFrameEvent) -> Void] = [:]
    
    // Change detection to prevent duplicate events
    private var lastPieceStates: [String: (position: CGPoint, rotation: CGFloat)] = [:]
    private var frameTimer: Timer?
    private var currentPieces: [String: CVPieceEvent] = [:]
    
    private init() {
        startFrameTimer()
    }
    
    /// Start emitting frame events at ~30fps like real CV hardware
    private func startFrameTimer() {
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.emitFrame()
        }
    }
    
    /// Emit a frame event with all current piece states (private, timer-based)
    private func emitFrame() {
        guard !currentPieces.isEmpty else { return }
        
        let frame = CVFrameEvent(objects: Array(currentPieces.values))
        lastFrame = frame
        
        frameSubscribers.values.forEach { handler in
            handler(frame)
        }
    }
    
    /// Public method to emit a custom frame event
    func emitFrame(_ frame: CVFrameEvent) {
        lastFrame = frame
        
        // Update current pieces from frame
        currentPieces.removeAll()
        for object in frame.objects {
            let id = pieceIdFromCVName(object.name)
            currentPieces[id] = object
        }
        
        // Notify subscribers
        frameSubscribers.values.forEach { handler in
            handler(frame)
        }
    }
    
    /// Helper to convert CV name back to piece ID
    private func pieceIdFromCVName(_ cvName: String) -> String {
        switch cvName {
        case "tangram_triangle_sml": return "piece_smallTriangle1"
        case "tangram_triangle_sml2": return "piece_smallTriangle2"
        case "tangram_triangle_med": return "piece_mediumTriangle"
        case "tangram_triangle_lrg": return "piece_largeTriangle1"
        case "tangram_triangle_lrg2": return "piece_largeTriangle2"
        case "tangram_square": return "piece_square"
        case "tangram_parallelogram": return "piece_parallelogram"
        default: return cvName
        }
    }
    
    /// Emit a simple event
    func emit(_ event: TangramCVEvent) {
        // Change detection for moves
        if case .pieceMoved(let id, let position, let rotation) = event {
            if let lastState = lastPieceStates[id] {
                let positionChanged = abs(lastState.position.x - position.x) > 1 ||
                                    abs(lastState.position.y - position.y) > 1
                let rotationChanged = abs(lastState.rotation - rotation) > 0.01
                
                if !positionChanged && !rotationChanged {
                    return // Skip duplicate
                }
            }
            lastPieceStates[id] = (position, rotation)
            
            // Update CV piece for frame events
            updateCVPiece(id: id, position: position, rotation: rotation)
        }
        
        lastEvent = event
        eventCount += 1
        
        subscribers.values.forEach { handler in
            handler(event)
        }
        
        #if DEBUG
        logEvent(event)
        #endif
    }
    
    /// Update CV piece data for frame emission
    private func updateCVPiece(id: String, position: CGPoint, rotation: CGFloat) {
        // Convert piece ID to CV name format
        let cvName = pieceNameForCV(id)
        let classId = classIdForPiece(id)
        
        // Convert rotation to degrees
        let rotationDegrees = rotation * 180 / .pi
        
        // Create vertices (simplified - would be computed from actual piece geometry)
        let vertices = computeVertices(for: id, at: position, rotation: rotation)
        
        let cvPiece = CVPieceEvent(
            name: cvName,
            classId: classId,
            pose: CVPieceEvent.Pose(
                rotationDegrees: rotationDegrees,
                translation: [Double(position.x), Double(position.y)]
            ),
            vertices: vertices
        )
        
        currentPieces[id] = cvPiece
    }
    
    /// Remove a piece from CV tracking
    func removePiece(id: String) {
        currentPieces.removeValue(forKey: id)
        lastPieceStates.removeValue(forKey: id)
    }
    
    /// Subscribe to simple events
    func subscribe(_ handler: @escaping (TangramCVEvent) -> Void) -> UUID {
        let id = UUID()
        subscribers[id] = handler
        return id
    }
    
    /// Subscribe to frame events
    func subscribeToFrames(_ handler: @escaping (CVFrameEvent) -> Void) -> UUID {
        let id = UUID()
        frameSubscribers[id] = handler
        return id
    }
    
    func unsubscribe(_ id: UUID) {
        subscribers.removeValue(forKey: id)
        frameSubscribers.removeValue(forKey: id)
    }
    
    // MARK: - CV Format Helpers
    
    private func pieceNameForCV(_ id: String) -> String {
        // Map internal IDs to CV names
        if id.contains("smallTriangle1") { return "tangram_triangle_sml" }
        if id.contains("smallTriangle2") { return "tangram_triangle_sml2" }
        if id.contains("mediumTriangle") { return "tangram_triangle_med" }
        if id.contains("largeTriangle1") { return "tangram_triangle_lrg" }
        if id.contains("largeTriangle2") { return "tangram_triangle_lrg2" }
        if id.contains("square") { return "tangram_square" }
        if id.contains("parallelogram") { return "tangram_parallelogram" }
        return id
    }
    
    private func classIdForPiece(_ id: String) -> Int {
        // Map to CV class IDs
        if id.contains("parallelogram") { return 0 }
        if id.contains("square") { return 1 }
        if id.contains("largeTriangle1") { return 2 }
        if id.contains("largeTriangle2") { return 3 }
        if id.contains("mediumTriangle") { return 4 }
        if id.contains("smallTriangle1") { return 5 }
        if id.contains("smallTriangle2") { return 6 }
        return -1
    }
    
    private func computeVertices(for pieceId: String, at position: CGPoint, rotation: CGFloat) -> [[Double]] {
        // Simplified vertex computation - in real implementation would use actual geometry
        let size: CGFloat = 50
        
        // Basic square vertices as example
        let vertices = [
            CGPoint(x: -size/2, y: -size/2),
            CGPoint(x: size/2, y: -size/2),
            CGPoint(x: size/2, y: size/2),
            CGPoint(x: -size/2, y: size/2)
        ]
        
        // Apply rotation and translation
        return vertices.map { vertex in
            let rotatedX = vertex.x * cos(rotation) - vertex.y * sin(rotation)
            let rotatedY = vertex.x * sin(rotation) + vertex.y * cos(rotation)
            return [
                Double(position.x + rotatedX),
                Double(position.y + rotatedY)
            ]
        }
    }
    
    // MARK: - Debug
    
    #if DEBUG
    private func logEvent(_ event: TangramCVEvent) {
        let description: String
        switch event {
        case .pieceMoved(let id, let pos, let rot):
            description = "Moved \(id) to (\(Int(pos.x)), \(Int(pos.y))), rot: \(Int(rot * 180 / .pi))°"
        case .pieceFlipped(let id, let flipped):
            description = "Flipped \(id): \(flipped)"
        case .pieceLifted(let id):
            description = "Lifted \(id)"
        case .piecePlaced(let id):
            description = "Placed \(id)"
        case .frameUpdate:
            description = "Frame update"
        case .validationChanged(let id, let valid):
            description = "Validation \(id): \(valid ? "✓" : "✗")"
        }
        // Removed CV event logging for cleaner console
    }
    #endif
    
    deinit {
        frameTimer?.invalidate()
    }
}