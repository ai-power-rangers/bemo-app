//
//  TangramPuzzleScene+Zones.swift
//  Bemo
//
//  Zone-based validation logic for tangram puzzle
//

// WHAT: Extension that divides play area into zones with different validation rules
// ARCHITECTURE: View extension in MVVM-S, extends scene with spatial awareness
// USAGE: Determines validation behavior based on piece location

import SpriteKit
import Foundation

extension TangramPuzzleScene {
    
    /// Zone types in the play area
    enum Zone: String {
        case organization   // Left 1/3 - piece storage, never validate
        case working       // Middle 1/3 - exploration, soft validate
        case construction  // Right 1/3 - active building, full validate
        
        var validationIntensity: Float {
            switch self {
            case .organization: return 0.0
            case .working: return 0.5
            case .construction: return 1.0
            }
        }
        
        var shouldValidate: Bool {
            switch self {
            case .organization: return false
            case .working, .construction: return true
            }
        }
        
        var nudgeDelay: TimeInterval {
            switch self {
            case .organization: return .infinity
            case .working: return 5.0
            case .construction: return 2.0
            }
        }
        
        var description: String {
            switch self {
            case .organization: return "Organization Zone"
            case .working: return "Working Space"
            case .construction: return "Construction Area"
            }
        }
    }
    
    /// Determine which zone a position is in
    func determineZone(for position: CGPoint) -> Zone {
        // Convert to scene coordinates if needed
        let scenePos = physicalWorldSection.convert(position, to: self)
        
        // Get physical world bounds
        let leftBound = physicalBounds.minX
        let rightBound = physicalBounds.maxX
        let width = rightBound - leftBound
        
        // Calculate zone boundaries
        let organizationBoundary = leftBound + width / 3
        let workingBoundary = leftBound + (2 * width / 3)
        
        // Determine zone based on X position
        if scenePos.x < organizationBoundary {
            return .organization
        } else if scenePos.x < workingBoundary {
            return .working
        } else {
            return .construction
        }
    }
    
    /// Check if validation should occur in a zone with given confidence
    func shouldValidateInZone(_ zone: Zone, confidence: Float) -> Bool {
        guard zone.shouldValidate else { return false }
        
        // Zone-specific confidence thresholds
        switch zone {
        case .organization:
            return false // Never validate
        case .working:
            return confidence > 0.6 // Higher threshold for working space
        case .construction:
            return confidence > 0.3 // Lower threshold for construction area
        }
    }
    
    /// Get validation intensity for a zone
    func validationIntensity(for zone: Zone) -> Float {
        return zone.validationIntensity
    }
    
    /// Calculate weighted zone for a group of pieces
    func calculateGroupZone(for pieces: Set<String>) -> Zone {
        var zoneWeights: [Zone: Int] = [:]
        
        for piece in availablePieces {
            guard let pieceId = piece.name,
                  pieces.contains(pieceId) else { continue }
            
            let zone = determineZone(for: piece.position)
            zoneWeights[zone, default: 0] += 1
        }
        
        // Return zone with most pieces
        if let dominantZone = zoneWeights.max(by: { $0.value < $1.value })?.key {
            return dominantZone
        }
        
        return .organization // Default to safest zone
    }
    
    /// Visual helper to show zones (debug mode)
    func showZoneOverlay() {
        // Remove existing overlay
        physicalWorldSection.childNode(withName: "zoneOverlay")?.removeFromParent()
        
        let overlay = SKNode()
        overlay.name = "zoneOverlay"
        overlay.zPosition = -10
        
        let width = physicalBounds.width / 3
        let height = physicalBounds.height
        
        // Organization zone (left)
        let orgZone = SKShapeNode(rectOf: CGSize(width: width, height: height))
        orgZone.fillColor = SKColor.systemRed.withAlphaComponent(0.1)
        orgZone.strokeColor = SKColor.clear
        orgZone.position = CGPoint(x: -width, y: 0)
        overlay.addChild(orgZone)
        
        let orgLabel = SKLabelNode(text: "ORGANIZE")
        orgLabel.fontSize = 20
        orgLabel.fontColor = SKColor.systemRed.withAlphaComponent(0.3)
        orgLabel.position = CGPoint(x: -width, y: -height/2 + 20)
        overlay.addChild(orgLabel)
        
        // Working zone (middle)
        let workZone = SKShapeNode(rectOf: CGSize(width: width, height: height))
        workZone.fillColor = SKColor.systemYellow.withAlphaComponent(0.1)
        workZone.strokeColor = SKColor.clear
        workZone.position = CGPoint(x: 0, y: 0)
        overlay.addChild(workZone)
        
        let workLabel = SKLabelNode(text: "WORK")
        workLabel.fontSize = 20
        workLabel.fontColor = SKColor.systemYellow.withAlphaComponent(0.3)
        workLabel.position = CGPoint(x: 0, y: -height/2 + 20)
        overlay.addChild(workLabel)
        
        // Construction zone (right)
        let constZone = SKShapeNode(rectOf: CGSize(width: width, height: height))
        constZone.fillColor = SKColor.systemGreen.withAlphaComponent(0.1)
        constZone.strokeColor = SKColor.clear
        constZone.position = CGPoint(x: width, y: 0)
        overlay.addChild(constZone)
        
        let constLabel = SKLabelNode(text: "BUILD")
        constLabel.fontSize = 20
        constLabel.fontColor = SKColor.systemGreen.withAlphaComponent(0.3)
        constLabel.position = CGPoint(x: width, y: -height/2 + 20)
        overlay.addChild(constLabel)
        
        physicalWorldSection.addChild(overlay)
    }
    
    /// Hide zone overlay
    func hideZoneOverlay() {
        physicalWorldSection.childNode(withName: "zoneOverlay")?.removeFromParent()
    }
    
    /// Adjust validation based on zone
    func adjustValidationForZone(_ piece: PuzzlePieceNode) -> Bool {
        guard let pieceId = piece.name else { return false }
        
        let zone = determineZone(for: piece.position)
        
        // Never validate in organization zone
        if zone == .organization {
            // Clear any validation state
            if var state = pieceStates[pieceId] {
                if case .invalid = state.state {
                    state.resetToDetected()
                    pieceStates[pieceId] = state
                    piece.pieceState = state
                    piece.updateStateIndicator()
                }
            }
            return false
        }
        
        return true
    }
    
    /// Get nudge level adjusted for zone
    func nudgeLevelForZone(_ baseLevel: NudgeLevel, in zone: Zone) -> NudgeLevel {
        switch zone {
        case .organization:
            return .none // No nudges in organization
        case .working:
            // Reduce nudge intensity in working space
            return max(.none, NudgeLevel(rawValue: baseLevel.rawValue - 1) ?? .none)
        case .construction:
            return baseLevel // Full nudge intensity
        }
    }
}