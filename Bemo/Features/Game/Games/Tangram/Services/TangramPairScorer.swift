//
//  TangramPairScorer.swift
//  Bemo
//
//  Pair scoring and selection logic for Tangram validation
//

// WHAT: Scores observed piece pairs against target pairs using geometric similarity
// ARCHITECTURE: Service that uses TargetPairLibrary to find best matching pairs
// USAGE: Called by TangramValidationEngine to select anchor pairs

import Foundation
import CoreGraphics

class TangramPairScorer {
    
    // MARK: - Types
    
    struct OrientedPieceInfo {
        let observation: TangramValidationEngine.PieceObservation
        let bestTargetId: String
        let orientationDeltaDeg: CGFloat
        let flipOK: Bool
    }
    
    struct ScoredPair {
        let pair: (TangramValidationEngine.PieceObservation, TangramValidationEngine.PieceObservation)
        let targetPair: (GamePuzzleData.TargetPiece, GamePuzzleData.TargetPiece)
        let score: CGFloat
        let reason: String
    }
    
    // MARK: - Public Methods
    
    /// Find oriented pieces from observations
    func findOrientedPieces(
        from observations: [TangramValidationEngine.PieceObservation],
        puzzle: GamePuzzleData,
        orientationToleranceDeg: CGFloat
    ) -> [OrientedPieceInfo] {
        var oriented: [OrientedPieceInfo] = []
        
        for obs in observations {
            let candidates = puzzle.targetPieces.filter { $0.pieceType == obs.pieceType }
            guard !candidates.isEmpty else { continue }
            
            let pieceFeature = TangramGeometryHelpers.pieceFeatureAngle(
                rotation: obs.rotation,
                pieceType: obs.pieceType,
                isFlipped: obs.isFlipped
            )
            
            var best: (id: String, deltaDeg: CGFloat, flipOK: Bool)?
            for target in candidates {
                let targetFeature = TangramGeometryHelpers.targetFeatureAngle(
                    transform: target.transform,
                    pieceType: obs.pieceType
                )
                
                let symDiff = TangramRotationValidator.rotationDifferenceToNearest(
                    currentRotation: pieceFeature,
                    targetRotation: targetFeature,
                    pieceType: obs.pieceType,
                    isFlipped: obs.isFlipped
                )
                
                let delta = abs(symDiff) * 180 / .pi
                let targetFlipped = TangramGeometryHelpers.isTransformFlipped(target.transform)
                let flipOK = (obs.pieceType != .parallelogram) || (obs.isFlipped != targetFlipped)
                
                if best == nil || delta < best!.deltaDeg {
                    best = (target.id, delta, flipOK)
                }
            }
            
            if let b = best, b.flipOK, b.deltaDeg <= max(5, orientationToleranceDeg) {
                oriented.append(OrientedPieceInfo(
                    observation: obs,
                    bestTargetId: b.id,
                    orientationDeltaDeg: b.deltaDeg,
                    flipOK: b.flipOK
                ))
            }
        }
        
        return oriented
    }
    
    /// Select best pair from oriented pieces using library scoring
    func selectBestPair(
        from orientedPieces: [OrientedPieceInfo],
        puzzle: GamePuzzleData,
        pairLibrary: TargetPairLibrary?,
        focusPieceId: String?
    ) -> ScoredPair? {
        guard orientedPieces.count >= 2 else { return nil }
        
        var bestPair: ScoredPair?
        
        for i in 0..<(orientedPieces.count - 1) {
            for j in (i + 1)..<orientedPieces.count {
                let obs0 = orientedPieces[i].observation
                let obs1 = orientedPieces[j].observation
                
                // Try library scoring first
                if let library = pairLibrary,
                   let targetMatch = findBestTargetPair(
                       observedPair: (p0: obs0, p1: obs1),
                       puzzle: puzzle,
                       library: library,
                       focusPieceId: focusPieceId
                   ) {
                    var score = targetMatch.score
                    
                    // Add orientation bonus
                    let orientBonus = (orientedPieces[i].orientationDeltaDeg + orientedPieces[j].orientationDeltaDeg) / 2.0
                    score += orientBonus * 0.5
                    
                    // Focus piece preference
                    let hasFocus = focusPieceId != nil &&
                        (obs0.pieceId == focusPieceId || obs1.pieceId == focusPieceId)
                    if hasFocus {
                        score *= 0.6  // 40% bonus
                    }
                    
                    let candidate = ScoredPair(
                        pair: (obs0, obs1),
                        targetPair: (targetMatch.t0, targetMatch.t1),
                        score: score,
                        reason: hasFocus ? "focus+library" : "library"
                    )
                    
                    if bestPair == nil || score < bestPair!.score {
                        bestPair = candidate
                    }
                } else {
                    // Fallback: distance-based scoring
                    let d = TangramGeometryHelpers.distance(from: obs0.position, to: obs1.position)
                    let hasFocus = focusPieceId != nil &&
                        (obs0.pieceId == focusPieceId || obs1.pieceId == focusPieceId)
                    var score = d
                    if hasFocus { score *= 0.7 }
                    
                    // Need to find target pieces for fallback case
                    if let t0 = puzzle.targetPieces.first(where: { $0.pieceType == obs0.pieceType }),
                       let t1 = puzzle.targetPieces.first(where: { $0.pieceType == obs1.pieceType }) {
                        let candidate = ScoredPair(
                            pair: (obs0, obs1),
                            targetPair: (t0, t1),
                            score: score,
                            reason: hasFocus ? "focus+distance" : "distance"
                        )
                        
                        if bestPair == nil || score < bestPair!.score {
                            bestPair = candidate
                        }
                    }
                }
            }
        }
        
        return bestPair
    }
    
    /// Find best matching target pair using library
    func findBestTargetPair(
        observedPair: (p0: TangramValidationEngine.PieceObservation, p1: TangramValidationEngine.PieceObservation),
        puzzle: GamePuzzleData,
        library: TargetPairLibrary,
        focusPieceId: String? = nil
    ) -> (t0: GamePuzzleData.TargetPiece, t1: GamePuzzleData.TargetPiece, score: CGFloat)? {
        // Compute observed pair vector
        let vObs = TangramGeometryHelpers.vector(from: observedPair.p0.position, to: observedPair.p1.position)
        let lenObs = TangramGeometryHelpers.vectorLength(vObs)
        guard lenObs > 1e-3 else { return nil }
        
        let hasFocus = focusPieceId != nil &&
            (observedPair.p0.pieceId == focusPieceId || observedPair.p1.pieceId == focusPieceId)
        
        // Get candidate entries by type
        let typeKey = [observedPair.p0.pieceType.rawValue, observedPair.p1.pieceType.rawValue].sorted().joined(separator: "|")
        guard let candidateEntries = library.entriesByTypePair[typeKey], !candidateEntries.isEmpty else {
            #if DEBUG
            print("[PAIR-SCORING] No entries found for type pair: \(typeKey)")
            #endif
            return nil
        }
        
        var bestMatch: (entry: TargetPairLibrary.Entry, score: CGFloat)?
        
        for entry in candidateEntries {
            let matchesForward = (entry.typeA == observedPair.p0.pieceType && entry.typeB == observedPair.p1.pieceType)
            let matchesReverse = (entry.typeA == observedPair.p1.pieceType && entry.typeB == observedPair.p0.pieceType)
            
            guard matchesForward || matchesReverse else { continue }
            
            let adjustedVector: CGVector
            if matchesReverse {
                adjustedVector = CGVector(dx: -entry.vectorSK.dx, dy: -entry.vectorSK.dy)
            } else {
                adjustedVector = entry.vectorSK
            }
            
            let score = scorePairAgainstTarget(
                observedVector: vObs,
                observedLength: lenObs,
                targetVector: adjustedVector,
                targetLength: entry.length,
                hasFocusPiece: hasFocus
            )
            
            if bestMatch == nil || score < bestMatch!.score {
                let orderedEntry = matchesReverse ?
                    TargetPairLibrary.Entry(
                        idA: entry.idB, idB: entry.idA,
                        typeA: entry.typeB, typeB: entry.typeA,
                        vectorSK: adjustedVector,
                        angleRad: atan2(adjustedVector.dy, adjustedVector.dx),
                        length: entry.length
                    ) : entry
                bestMatch = (orderedEntry, score)
            }
        }
        
        if let best = bestMatch,
           let t0 = puzzle.targetPieces.first(where: { $0.id == best.entry.idA }),
           let t1 = puzzle.targetPieces.first(where: { $0.id == best.entry.idB }) {
            #if DEBUG
            print("[PAIR-SCORING] Best match: \(t0.pieceType.rawValue)-\(t1.pieceType.rawValue) targets=\(t0.id.suffix(4))-\(t1.id.suffix(4)) score=\(Int(best.score)) hasFocus=\(hasFocus) from \(candidateEntries.count) candidates")
            #endif
            return (t0, t1, best.score)
        }
        
        #if DEBUG
        print("[PAIR-SCORING] No match found for \(observedPair.p0.pieceType.rawValue)-\(observedPair.p1.pieceType.rawValue)")
        #endif
        return nil
    }
    
    // MARK: - Private Methods
    
    private func scorePairAgainstTarget(
        observedVector: CGVector,
        observedLength: CGFloat,
        targetVector: CGVector,
        targetLength: CGFloat,
        hasFocusPiece: Bool = false
    ) -> CGFloat {
        // Angle residual - rotation invariant
        let observedAngle = TangramGeometryHelpers.vectorAngle(observedVector)
        let targetAngle = TangramGeometryHelpers.vectorAngle(targetVector)
        
        var angleDiff = abs(TangramGeometryHelpers.angleDifference(observedAngle, targetAngle))
        
        // Consider 180° rotation for symmetry
        let flippedAngleDiff = abs(TangramGeometryHelpers.angleDifference(observedAngle, targetAngle + .pi))
        angleDiff = min(angleDiff, flippedAngleDiff)
        
        // Length residual
        let lengthDiff = abs(observedLength - targetLength)
        
        // Compute score (lower is better)
        var score = (angleDiff * 180 / .pi) * 2.0 + lengthDiff * 0.5
        
        // Focus bonus
        if hasFocusPiece {
            score *= 0.8  // 20% bonus
        }
        
        return score
    }
}