//
//  ConstructionGroupManager.swift
//  Bemo
//
//  Manages construction groups and calculates confidence
//

// WHAT: Detects and manages groups of pieces showing construction intent
// ARCHITECTURE: Service in MVVM-S, manages validation grouping logic
// USAGE: Updates groups based on piece positions, calculates when to validate

import Foundation
import CoreGraphics
import SpriteKit

class ConstructionGroupManager {
    
    // MARK: - Configuration Constants
    
    private enum Config {
        // Proximity & Grouping
        static let proximityThreshold: CGFloat = 60        // Centroid proximity fallback
        static let edgeAdjacencyTolerance: CGFloat = 16    // Pixel tolerance for edge/vertex contact
        static let angleThreshold: CGFloat = 0.26          // ~15 degrees
        static let groupTimeout: TimeInterval = 30         // Seconds before group expires
        
        // Intent-based validation thresholds (no spatial zones)
        static let constructingThreshold: Float = 0.45 // Higher to avoid premature validation
        static let buildingThreshold: Float = 0.40     // Higher to avoid premature validation
        
        // Confidence Score Weights
        static let spatialWeight: Float = 0.4
        static let temporalWeight: Float = 0.2
        static let behavioralWeight: Float = 0.4
        
        // Spatial Signal Weights
        static let edgeProximityWeight: Float = 0.3
        static let angleAlignmentWeight: Float = 0.5
        static let clusterDensityWeight: Float = 0.2
        
        // Temporal Signal Weights
        static let stabilityWeight: Float = 0.5
        static let focusWeight: Float = 0.3
        static let recencyWeight: Float = 0.2
        
        // Behavioral Signal Weights
        static let connectionWeight: Float = 0.6
        static let progressWeight: Float = 0.4
        
        // Calculation Parameters
        static let boundingRadiusMax: CGFloat = 200
        static let clusterAreaDivisor: CGFloat = 10000
        static let stabilityThresholdSec: TimeInterval = 2
        static let activityTimeoutSec: TimeInterval = 30
        
        // Minimum pieces for validation
        static let minPiecesForValidation: Int = 2
    }
    
    // MARK: - Properties
    
    private var groups: [UUID: ConstructionGroup] = [:]
    
    // MARK: - Public Interface
    
    /// Update groups based on current piece positions
    func updateGroups(with pieces: [PuzzlePieceNode]) -> [ConstructionGroup] {
        // Remove stale groups
        cleanStaleGroups()
        
        // Build proximity map
        let proximityMap = buildProximityMap(pieces)
        
        // Form or update groups
        var updatedGroups: [UUID: ConstructionGroup] = [:]
        var assignedPieces: Set<String> = []
        
        for piece in pieces {
            guard let pieceId = piece.name,
                  !assignedPieces.contains(pieceId) else { continue }
            
            // Find nearby pieces
            let nearbyPieces = proximityMap[pieceId] ?? []
            
            if nearbyPieces.isEmpty {
                // Piece is isolated, remove from any groups
                removePieceFromGroups(pieceId)
            } else {
                // Find or create group for this cluster
                let cluster = findCluster(starting: pieceId, in: proximityMap)
                let group = findOrCreateGroup(for: cluster, pieces: pieces)
                updatedGroups[group.id] = group
                assignedPieces.formUnion(cluster)
            }
        }
        
        groups = updatedGroups
        
        // Update group states and confidence
        for id in groups.keys {
            groups[id]?.updateState()
            if let group = groups[id] {
                groups[id]?.confidence = calculateConfidence(for: group, pieces: pieces)
            }
        }
        
        return Array(groups.values)
    }

    /// Record an attempt for a specific piece inside a group to drive nudge logic
    func recordAttempt(in groupId: UUID, pieceId: String) {
        guard var group = groups[groupId] else { return }
        group.recordAttempt(for: pieceId)
        groups[groupId] = group
    }
    
    /// Calculate confidence score for a group
    func calculateConfidence(for group: ConstructionGroup, pieces: [PuzzlePieceNode]) -> Float {
        guard group.pieces.count >= Config.minPiecesForValidation else { return 0 }
        
        // Get spatial signals
        let spatial = calculateSpatialSignals(for: group, pieces: pieces)
        
        // Get temporal signals
        let temporal = calculateTemporalSignals(for: group)
        
        // Get behavioral signals
        let behavioral = calculateBehavioralSignals(for: group)
        
        // Weight and combine scores
        let spatialScore = spatial.edgeProximity * Config.edgeProximityWeight +
                          spatial.angleAlignment * Config.angleAlignmentWeight +
                          spatial.clusterDensity * Config.clusterDensityWeight
        
        let temporalScore = temporal.stabilityDuration * Config.stabilityWeight +
                           temporal.focusTime * Config.focusWeight +
                           temporal.activityRecency * Config.recencyWeight
        
        let behavioralScore = Float(behavioral.validConnections) / 6.0 * Config.connectionWeight +
                             behavioral.progressionRate * Config.progressWeight
        
        // Final weighted score
        let confidence = spatialScore * Config.spatialWeight +
                        temporalScore * Config.temporalWeight +
                        behavioralScore * Config.behavioralWeight
        
        return min(max(confidence, 0), 1) // Clamp to 0-1
    }
    
    /// Determine if a group should validate
    func shouldValidate(group: ConstructionGroup) -> Bool {
        // Check validation state
        guard group.validationState.shouldValidate else { return false }
        
        // Check minimum group size
        guard group.pieces.count >= Config.minPiecesForValidation else { return false }
        
        // Intent-based thresholds based on validation state (no zones)
        switch group.validationState {
        case .constructing:
            return group.confidence > Config.constructingThreshold
        case .building:
            return group.confidence > Config.buildingThreshold
        case .completing:
            return true
        default:
            return false
        }
    }
    
    /// Determine nudge level for a group
    func determineNudgeLevel(for group: ConstructionGroup) -> NudgeLevel {
        guard group.validationState.shouldValidate else { return .none }
        
        let baseLevel: NudgeLevel
        
        switch group.validationState {
        case .constructing:
            baseLevel = group.confidence > 0.7 ? .gentle : .visual
        case .building:
            baseLevel = group.confidence > 0.7 ? .specific : .gentle
        case .completing:
            baseLevel = .directed
        default:
            baseLevel = .none
        }
        
        // Escalate based on attempts
        let maxAttempts = group.attemptHistory.values.max() ?? 0
        if maxAttempts > 5 && baseLevel.rawValue < NudgeLevel.solution.rawValue {
            return NudgeLevel(rawValue: baseLevel.rawValue + 1) ?? baseLevel
        }
        
        return baseLevel
    }
    
    /// Merge two groups when pieces connect
    func mergeGroups(_ group1Id: UUID, _ group2Id: UUID) {
        guard let group1 = groups[group1Id],
              let group2 = groups[group2Id],
              group1Id != group2Id else { return }
        
        var merged = group1
        merged.pieces.formUnion(group2.pieces)
        merged.validatedConnections.formUnion(group2.validatedConnections)
        
        // Merge attempt histories
        for (piece, attempts) in group2.attemptHistory {
            merged.attemptHistory[piece] = max(
                merged.attemptHistory[piece] ?? 0,
                attempts
            )
        }
        
        // Keep most recent activity
        merged.lastActivity = max(group1.lastActivity, group2.lastActivity)
        
        // Update anchor if needed
        if merged.anchorPiece == nil {
            merged.anchorPiece = group2.anchorPiece
        }
        
        groups[group1Id] = merged
        groups.removeValue(forKey: group2Id)
    }
    
    /// Record a validated connection
    func recordConnection(_ piece1: String, _ piece2: String, in groupId: UUID) {
        guard var group = groups[groupId] else { return }
        
        let connection = PieceConnection(piece1, piece2, valid: true)
        group.validatedConnections.insert(connection)
        group.lastActivity = Date()
        groups[groupId] = group
    }
    
    // MARK: - Private Helpers
    
    private func cleanStaleGroups() {
        groups = groups.filter { _, group in
            !group.isStale(timeout: Config.groupTimeout)
        }
    }
    
    private func buildProximityMap(_ pieces: [PuzzlePieceNode]) -> [String: Set<String>] {
        var proximityMap: [String: Set<String>] = [:]
        
        for i in 0..<pieces.count {
            guard let id1 = pieces[i].name else { continue }
            proximityMap[id1] = []
            
            for j in (i+1)..<pieces.count {
                guard let id2 = pieces[j].name else { continue }
                
                // Centroid distance fallback
                let centerDistance = hypot(
                    pieces[i].position.x - pieces[j].position.x,
                    pieces[i].position.y - pieces[j].position.y
                )
                
                // Polygon edge/vertex adjacency detection (physical realism: touching pieces are connected)
                let polyDistance = minimumPolygonDistance(between: pieces[i], and: pieces[j])
                
                if centerDistance < Config.proximityThreshold || polyDistance <= Config.edgeAdjacencyTolerance {
                    proximityMap[id1]?.insert(id2)
                    proximityMap[id2, default: []].insert(id1)
                }
            }
        }
        
        return proximityMap
    }

    // Compute minimum distance between two piece polygons in the current coordinate space
    private func minimumPolygonDistance(between a: PuzzlePieceNode, and b: PuzzlePieceNode) -> CGFloat {
        func transformedVertices(for piece: PuzzlePieceNode) -> [CGPoint] {
            guard let type = piece.pieceType else { return [] }
            // 1) Base vertices in local piece space
            let base = TangramGameGeometry.scaleVertices(
                TangramGameGeometry.normalizedVertices(for: type),
                by: TangramGameConstants.visualScale
            )
            // 2) Apply flip
            let flipped: [CGPoint]
            if piece.isFlipped {
                flipped = base.map { CGPoint(x: -$0.x, y: $0.y) }
            } else {
                flipped = base
            }
            // 3) Apply rotation around origin (piece path is centered at 0,0)
            let cosA = cos(piece.zRotation)
            let sinA = sin(piece.zRotation)
            let rotated = flipped.map { v in CGPoint(x: v.x * cosA - v.y * sinA, y: v.x * sinA + v.y * cosA) }
            // 4) Translate to piece.position
            let translated = rotated.map { CGPoint(x: $0.x + piece.position.x, y: $0.y + piece.position.y) }
            return translated
        }
        func edges(_ poly: [CGPoint]) -> [(CGPoint, CGPoint)] {
            guard poly.count >= 2 else { return [] }
            return (0..<poly.count).map { i in (poly[i], poly[(i+1) % poly.count]) }
        }
        func segmentDistance(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ p4: CGPoint) -> CGFloat {
            // Standard segment-segment distance
            let u = CGVector(dx: p2.x - p1.x, dy: p2.y - p1.y)
            let v = CGVector(dx: p4.x - p3.x, dy: p4.y - p3.y)
            let w = CGVector(dx: p1.x - p3.x, dy: p1.y - p3.y)
            let a = u.dx*u.dx + u.dy*u.dy
            let b = u.dx*v.dx + u.dy*v.dy
            let c = v.dx*v.dx + v.dy*v.dy
            let d = u.dx*w.dx + u.dy*w.dy
            let e = v.dx*w.dx + v.dy*w.dy
            let denom = a*c - b*b
            var sc: CGFloat = 0
            var tc: CGFloat = 0
            func clamp(_ x: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { max(lo, min(hi, x)) }
            if denom < 1e-6 {
                sc = 0
                tc = clamp(e/c, 0, 1)
            } else {
                sc = clamp((b*e - c*d)/denom, 0, 1)
                tc = clamp((a*e - b*d)/denom, 0, 1)
            }
            let dpx = w.dx + sc*u.dx - tc*v.dx
            let dpy = w.dy + sc*u.dy - tc*v.dy
            return hypot(dpx, dpy)
        }
        let pa = transformedVertices(for: a)
        let pb = transformedVertices(for: b)
        if pa.isEmpty || pb.isEmpty { return .greatestFiniteMagnitude }
        let ea = edges(pa)
        let eb = edges(pb)
        var minDist: CGFloat = .greatestFiniteMagnitude
        for (a0, a1) in ea {
            for (b0, b1) in eb {
                let d = segmentDistance(a0, a1, b0, b1)
                if d < minDist { minDist = d }
                if minDist == 0 { return 0 }
            }
        }
        return minDist
    }
    
    private func findCluster(starting: String, in proximityMap: [String: Set<String>]) -> Set<String> {
        var cluster: Set<String> = [starting]
        var toProcess: Set<String> = proximityMap[starting] ?? []
        
        while !toProcess.isEmpty {
            let current = toProcess.removeFirst()
            cluster.insert(current)
            
            if let neighbors = proximityMap[current] {
                for neighbor in neighbors {
                    if !cluster.contains(neighbor) {
                        toProcess.insert(neighbor)
                    }
                }
            }
        }
        
        return cluster
    }
    
    private func findOrCreateGroup(for cluster: Set<String>, pieces: [PuzzlePieceNode]) -> ConstructionGroup {
        // Check if any piece in cluster belongs to existing group
        for (_, group) in groups {
            if !group.pieces.isDisjoint(with: cluster) {
                var updated = group
                updated.pieces = cluster
                updated.lastActivity = Date()
                
                // Set anchor if not set
                if updated.anchorPiece == nil {
                    updated.anchorPiece = cluster.first
                }
                
                // Calculate center of mass
                updated.centerOfMass = calculateCenterOfMass(for: cluster, pieces: pieces)
                updated.boundingRadius = calculateBoundingRadius(for: cluster, pieces: pieces, center: updated.centerOfMass)
                
                return updated
            }
        }
        
        // Create new group
        var newGroup = ConstructionGroup()
        newGroup.pieces = cluster
        newGroup.anchorPiece = cluster.first
        newGroup.centerOfMass = calculateCenterOfMass(for: cluster, pieces: pieces)
        newGroup.boundingRadius = calculateBoundingRadius(for: cluster, pieces: pieces, center: newGroup.centerOfMass)
        
        return newGroup
    }
    
    private func removePieceFromGroups(_ pieceId: String) {
        for id in groups.keys {
            groups[id]?.pieces.remove(pieceId)
            if groups[id]?.pieces.isEmpty == true {
                groups.removeValue(forKey: id)
            }
        }
    }
    
    private func calculateCenterOfMass(for pieces: Set<String>, pieces allPieces: [PuzzlePieceNode]) -> CGPoint {
        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        var count = 0
        
        for piece in allPieces {
            if let id = piece.name, pieces.contains(id) {
                sumX += piece.position.x
                sumY += piece.position.y
                count += 1
            }
        }
        
        guard count > 0 else { return .zero }
        return CGPoint(x: sumX / CGFloat(count), y: sumY / CGFloat(count))
    }
    
    private func calculateBoundingRadius(for pieces: Set<String>, pieces allPieces: [PuzzlePieceNode], center: CGPoint) -> CGFloat {
        var maxDistance: CGFloat = 0
        
        for piece in allPieces {
            if let id = piece.name, pieces.contains(id) {
                let distance = hypot(piece.position.x - center.x, piece.position.y - center.y)
                maxDistance = max(maxDistance, distance)
            }
        }
        
        return maxDistance
    }
    
    private func calculateSpatialSignals(for group: ConstructionGroup, pieces: [PuzzlePieceNode]) -> SpatialSignals {
        var signals = SpatialSignals()
        
        // Edge proximity (closer = higher score)
        signals.edgeProximity = Float(max(0, 1 - (group.boundingRadius / Config.boundingRadiusMax)))
        
        // Cluster density (more pieces in smaller area = higher)
        let area = .pi * group.boundingRadius * group.boundingRadius
        signals.clusterDensity = area > 0 ? Float(group.pieces.count) / Float(area / Config.clusterAreaDivisor) : 0
        
        // Calculate actual angle alignment
        signals.angleAlignment = calculateAngleAlignment(for: group, pieces: pieces)
        
        signals.centerOfMass = group.centerOfMass
        
        return signals
    }
    
    private func calculateAngleAlignment(for group: ConstructionGroup, pieces: [PuzzlePieceNode]) -> Float {
        // Calculate alignment score based on piece rotations
        let groupPieces = pieces.filter { piece in
            guard let id = piece.name else { return false }
            return group.pieces.contains(id)
        }
        
        guard groupPieces.count > 1 else { return 0 }
        
        var alignmentScore: Float = 0
        var pairCount = 0
        
        // Check angle alignment between all pairs
        for i in 0..<groupPieces.count {
            for j in (i+1)..<groupPieces.count {
                let angle1 = groupPieces[i].zRotation
                let angle2 = groupPieces[j].zRotation
                
                // Calculate minimum angular difference
                let diff = abs(angle1 - angle2)
                
                // Check for 90-degree alignments (common in tangrams)
                let modDiff = diff.truncatingRemainder(dividingBy: .pi / 2)
                if modDiff < Config.angleThreshold || modDiff > (.pi / 2 - Config.angleThreshold) {
                    alignmentScore += 1
                } else {
                    alignmentScore += max(0, 1 - Float(modDiff / Config.angleThreshold))
                }
                
                pairCount += 1
            }
        }
        
        return pairCount > 0 ? alignmentScore / Float(pairCount) : 0
    }
    
    private func calculateTemporalSignals(for group: ConstructionGroup) -> TemporalSignals {
        var signals = TemporalSignals()
        
        let timeSinceActivity = Date().timeIntervalSince(group.lastActivity)
        
        // Activity recency (more recent = higher)
        signals.activityRecency = max(0, Float(1 - timeSinceActivity / Config.activityTimeoutSec))
        
        // Stability (pieces not moving much)
        signals.stabilityDuration = timeSinceActivity > Config.stabilityThresholdSec ? 1 : 
                                    Float(timeSinceActivity / Config.stabilityThresholdSec)
        
        // Focus time based on group age and activity
        let groupAge = Date().timeIntervalSince(group.createdAt)
        signals.focusTime = min(1, Float(groupAge / 10)) // Ramps up over 10 seconds
        
        return signals
    }
    
    private func calculateBehavioralSignals(for group: ConstructionGroup) -> BehavioralSignals {
        var signals = BehavioralSignals()
        
        signals.validConnections = group.validatedConnections.count
        signals.repeatAttempts = group.attemptHistory.values.reduce(0, +)
        
        // Progression rate
        let totalAttempts = max(1, signals.repeatAttempts)
        signals.progressionRate = Float(signals.validConnections) / Float(totalAttempts)
        
        return signals
    }
}