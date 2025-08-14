//
//  OptimizationValidator.swift
//  Bemo
//
//  Unified validation system using optimization to find minimal movements
//

// WHAT: Implements optimization-based validation to find minimal piece movements for solution
// ARCHITECTURE: Service in MVVM-S, single source of truth for all tangram validation
// USAGE: Call validate() to check placement, findOptimalPlacement() for hints/nudges

import Foundation
import CoreGraphics

/// Unified validator using optimization to find minimal movements to solution
class OptimizationValidator {
    
    // MARK: - Types
    
    struct ValidationResult {
        let isValid: Bool
        let optimalTransform: CGAffineTransform?
        let movementCost: CGFloat
        let rotationNeeded: CGFloat // In radians
        let translationNeeded: CGVector
        let confidence: CGFloat // 0-1, based on how close we are
    }
    
    struct OptimalPlacement {
        let targetId: String
        let transform: CGAffineTransform
        let totalCost: CGFloat
        let translation: CGVector
        let rotation: CGFloat // In radians
    }
    
    // MARK: - Configuration
    
    struct Config {
        let translationWeight: CGFloat
        let rotationWeight: CGFloat
        let positionTolerance: CGFloat
        let rotationTolerance: CGFloat // In radians
        let edgeTolerance: CGFloat
        
        /// Create config from difficulty using unified game constants
        static func fromDifficulty(_ difficulty: UserPreferences.DifficultySetting) -> Config {
            let tolerances = TangramGameConstants.Validation.tolerances(for: difficulty)
            return Config(
                translationWeight: 1.0,
                rotationWeight: 0.5,
                positionTolerance: tolerances.position,
                rotationTolerance: tolerances.rotationDeg * .pi / 180,
                edgeTolerance: tolerances.edgeContact
            )
        }
        
        static let easy = Config.fromDifficulty(.easy)
        static let normal = Config.fromDifficulty(.normal)
        static let hard = Config.fromDifficulty(.hard)
    }
    
    // MARK: - Properties
    
    private let config: Config
    
    // MARK: - Initialization
    
    init(config: Config = .normal) {
        self.config = config
    }
    
    // MARK: - Public Interface
    
    /// Validate a single piece placement against potential targets
    func validate(
        pieceType: TangramPieceType,
        currentPosition: CGPoint,
        currentRotation: CGFloat,
        isFlipped: Bool,
        availableTargets: [GamePuzzleData.TargetPiece]
    ) -> ValidationResult {
        
        // Find the best matching target using symmetric angle + SK-space distances
        var bestMatch: (target: GamePuzzleData.TargetPiece, cost: CGFloat, transform: CGAffineTransform, posDiff: CGFloat, rotDiff: CGFloat)?
        for target in availableTargets where target.pieceType == pieceType {
            let placement = computeOptimalPlacement(
                from: currentPosition,
                fromRotation: currentRotation,
                to: target,
                isFlipped: isFlipped
            )
            // Compute precise residuals in SK space
            let targetPos = extractPosition(from: target.transform)
            let targetRot = extractRotation(from: target.transform)
            let posDiff = hypot(currentPosition.x - targetPos.x, currentPosition.y - targetPos.y)
            let rotDiff = symmetricAngleDistance(for: pieceType,
                                                 a: featureAngle(for: pieceType, angle: currentRotation, flipped: isFlipped),
                                                 b: featureAngle(for: pieceType, angle: targetRot, flipped: false))
            let combinedCost = wt() * posDiff + wr() * rotDiff * 180 / .pi
            if bestMatch == nil || combinedCost < bestMatch!.cost {
                bestMatch = (target, combinedCost, placement.transform, posDiff, rotDiff)
            }
        }
        
        guard let match = bestMatch else {
            return ValidationResult(
                isValid: false,
                optimalTransform: nil,
                movementCost: .infinity,
                rotationNeeded: 0,
                translationNeeded: .zero,
                confidence: 0
            )
        }
        
        // Check if within tolerances using symmetric angle + feature angles
        let isValid = match.posDiff <= config.positionTolerance &&
                      abs(match.rotDiff) <= config.rotationTolerance
        
        // Calculate confidence (0-1 based on proximity)
        let posConfidence = max(0, 1 - match.posDiff / 100)
        let rotConfidence = max(0, 1 - abs(match.rotDiff) / .pi)
        let confidence = (posConfidence + rotConfidence) / 2
        
        return ValidationResult(
            isValid: isValid,
            optimalTransform: match.transform,
            movementCost: match.cost,
            rotationNeeded: match.rotDiff,
            translationNeeded: CGVector(dx: extractPosition(from: match.target.transform).x - currentPosition.x,
                                        dy: extractPosition(from: match.target.transform).y - currentPosition.y),
            confidence: confidence
        )
    }
    
    /// Find optimal placement for all pieces in a puzzle
    func findOptimalPuzzlePlacement(
        currentPieces: [PlacedPiece],
        targetPuzzle: GamePuzzleData
    ) -> (globalTransform: CGAffineTransform, totalCost: CGFloat) {
        
        // Step 1: Calculate centroids
        let currentCentroid = calculateCentroid(of: currentPieces.map { $0.position })
        let targetCentroid = calculateCentroid(of: targetPuzzle.targetPieces.map { 
            extractPosition(from: $0.transform)
        })
        
        // Step 2: Find optimal global rotation by grid search
        var bestRotation: CGFloat = 0
        var bestCost: CGFloat = .infinity
        
        let rotationSteps = 72 // Every 5 degrees
        for step in 0..<rotationSteps {
            let theta = CGFloat(step) * 2 * .pi / CGFloat(rotationSteps)
            let cost = calculateRotationCost(
                theta: theta,
                currentPieces: currentPieces,
                targetPuzzle: targetPuzzle,
                currentCentroid: currentCentroid,
                targetCentroid: targetCentroid
            )
            
            if cost < bestCost {
                bestCost = cost
                bestRotation = theta
            }
        }
        
        // Step 3: Calculate optimal translation for best rotation
        // rotationMatrix not needed; compose directly in the final transform
        let optimalTranslation = CGVector(
            dx: currentCentroid.x - targetCentroid.x * cos(bestRotation) + targetCentroid.y * sin(bestRotation),
            dy: currentCentroid.y - targetCentroid.x * sin(bestRotation) - targetCentroid.y * cos(bestRotation)
        )
        
        // Combine into global transform
        let globalTransform = CGAffineTransform.identity
            .rotated(by: bestRotation)
            .translatedBy(x: optimalTranslation.dx, y: optimalTranslation.dy)
        
        return (globalTransform, bestCost)
    }
    
    /// Find the optimal placement for a single piece
    func findOptimalPlacement(
        pieceType: TangramPieceType,
        currentPosition: CGPoint,
        currentRotation: CGFloat,
        isFlipped: Bool,
        targetPuzzle: GamePuzzleData,
        excludeTargets: Set<String> = []
    ) -> OptimalPlacement? {
        
        let availableTargets = targetPuzzle.targetPieces.filter { 
            $0.pieceType == pieceType && !excludeTargets.contains($0.id)
        }
        
        var bestPlacement: OptimalPlacement?
        
        for target in availableTargets {
            let placement = computeOptimalPlacement(
                from: currentPosition,
                fromRotation: currentRotation,
                to: target,
                isFlipped: isFlipped
            )
            // Refine total cost with symmetric angle distance at current pose
            let targetRot = extractRotation(from: target.transform)
            let pf = featureAngle(for: pieceType, angle: currentRotation, flipped: isFlipped)
            let tf = featureAngle(for: pieceType, angle: targetRot, flipped: false)
            let rotDiff = symmetricAngleDistance(for: pieceType, a: pf, b: tf)
            let targetPos = extractPosition(from: target.transform)
            let posDiff = hypot(currentPosition.x - targetPos.x, currentPosition.y - targetPos.y)
            let refinedCost = wt() * posDiff + wr() * rotDiff * 180 / .pi
            
            if bestPlacement == nil || refinedCost < bestPlacement!.totalCost {
                bestPlacement = OptimalPlacement(
                    targetId: placement.targetId,
                    transform: placement.transform,
                    totalCost: refinedCost,
                    translation: placement.translation,
                    rotation: placement.rotation
                )
            }
        }
        
        return bestPlacement
    }
    
    // MARK: - Private Helpers
    
    private func computeOptimalPlacement(
        from currentPos: CGPoint,
        fromRotation currentRot: CGFloat,
        to target: GamePuzzleData.TargetPiece,
        isFlipped: Bool
    ) -> OptimalPlacement {
        
        let targetPos = extractPosition(from: target.transform)
        let targetRot = extractRotation(from: target.transform)
        
        // Calculate movement needed
        let translation = CGVector(dx: targetPos.x - currentPos.x, dy: targetPos.y - currentPos.y)
        let pf = featureAngle(for: target.pieceType, angle: currentRot, flipped: isFlipped)
        let tf = featureAngle(for: target.pieceType, angle: targetRot, flipped: false)
        let rotation = symmetricAngleDistance(for: target.pieceType, a: pf, b: tf)
        
        // Calculate cost using weights (keep in consistent units)
        let translationCost = hypot(translation.dx, translation.dy) * config.translationWeight
        let rotationCost = abs(rotation) * 180 / .pi * config.rotationWeight
        let totalCost = translationCost + rotationCost
        
        // Build optimal transform
        let optimalTransform = CGAffineTransform.identity
            .rotated(by: targetRot)
            .translatedBy(x: targetPos.x, y: targetPos.y)
        
        return OptimalPlacement(
            targetId: target.id,
            transform: optimalTransform,
            totalCost: totalCost,
            translation: translation,
            rotation: rotation
        )
    }
    
    private func calculateRotationCost(
        theta: CGFloat,
        currentPieces: [PlacedPiece],
        targetPuzzle: GamePuzzleData,
        currentCentroid: CGPoint,
        targetCentroid: CGPoint
    ) -> CGFloat {
        
        var totalCost: CGFloat = 0
        
        for piece in currentPieces {
            // Center the piece position
            let centered = CGPoint(
                x: piece.position.x - currentCentroid.x,
                y: piece.position.y - currentCentroid.y
            )
            
            // Find matching target
            guard let target = targetPuzzle.targetPieces.first(where: { 
                $0.pieceType == piece.pieceType 
            }) else { continue }
            
            let targetPos = extractPosition(from: target.transform)
            let targetCentered = CGPoint(
                x: targetPos.x - targetCentroid.x,
                y: targetPos.y - targetCentroid.y
            )
            
            // Rotate current position
            let rotated = CGPoint(
                x: centered.x * cos(theta) - centered.y * sin(theta),
                y: centered.x * sin(theta) + centered.y * cos(theta)
            )
            
            // Calculate distance
            let dist = hypot(rotated.x - targetCentered.x, rotated.y - targetCentered.y)
            
            // Calculate rotation difference (feature angle + symmetry)
            let currentRotation = piece.rotation * .pi / 180
            let targetRotation = extractRotation(from: target.transform)
            let pieceFeature = featureAngle(for: piece.pieceType, angle: currentRotation + theta, flipped: piece.isFlipped)
            let targetFeature = featureAngle(for: piece.pieceType, angle: targetRotation, flipped: false)
            let rotDiff = symmetricAngleDistance(for: piece.pieceType, a: pieceFeature, b: targetFeature)
            
            // Add to cost
            totalCost += dist * config.translationWeight + abs(rotDiff) * config.rotationWeight
        }
        
        return totalCost
    }
    
    private func calculateCentroid(of points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sum = points.reduce(CGPoint.zero) { 
            CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) 
        }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }
    
    private func extractPosition(from transform: CGAffineTransform) -> CGPoint {
        let raw = CGPoint(x: transform.tx, y: transform.ty)
        return TangramPoseMapper.spriteKitPosition(fromRawPosition: raw)
    }
    
    private func extractRotation(from transform: CGAffineTransform) -> CGFloat {
        let raw = atan2(transform.b, transform.a)
        return TangramPoseMapper.spriteKitAngle(fromRawAngle: raw)
    }
    
    private func angleDifference(_ a1: CGFloat, _ a2: CGFloat) -> CGFloat {
        var diff = a2 - a1
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        return diff
    }

    // MARK: - Shape-aware helpers
    private func period(for type: TangramPieceType) -> CGFloat {
        switch type {
        case .square: return .pi / 2
        case .smallTriangle1, .smallTriangle2, .mediumTriangle, .largeTriangle1, .largeTriangle2, .parallelogram:
            return .pi
        }
    }
    private func symmetricAngleDistance(for type: TangramPieceType, a: CGFloat, b: CGFloat) -> CGFloat {
        let P = period(for: type)
        var d = fmod(a - b, P)
        if d > P / 2 { d -= P }
        if d < -P / 2 { d += P }
        return abs(d)
    }
    private func featureAngle(for type: TangramPieceType, angle: CGFloat, flipped: Bool) -> CGFloat {
        let canonicalTarget: CGFloat = (type.isTriangle ? (.pi / 4) : 0)
        let canonicalPiece: CGFloat = (type.isTriangle ? (3 * .pi / 4) : 0)
        return TangramRotationValidator.normalizeAngle(angle + (flipped ? -canonicalPiece : canonicalPiece) - canonicalTarget)
    }

    // Unified weights accessors (so we can tweak centrally)
    private func wt() -> CGFloat { config.translationWeight }
    private func wr() -> CGFloat { config.rotationWeight }
}

// MARK: - Difficulty Support

extension OptimizationValidator {
    convenience init(difficulty: UserPreferences.DifficultySetting) {
        self.init(config: Config.fromDifficulty(difficulty))
    }
}