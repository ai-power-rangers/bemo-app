//
//  TangramHintEngine.swift
//  Bemo
//
//  Intelligent hint system for Tangram puzzles
//

// WHAT: Provides contextual, progressive hints based on game state and player behavior
// ARCHITECTURE: Service in MVVM-S, used by TangramGameViewModel for hint logic
// USAGE: Call determineNextHint() with current game state to get appropriate hint

import Foundation
import CoreGraphics
import SpriteKit

class TangramHintEngine {
    
    // MARK: - Types
    
    struct HintData: Equatable {
        let targetPiece: TangramPieceType
        let currentTransform: CGAffineTransform?
        let targetTransform: CGAffineTransform
        let hintType: HintType
        let animationSteps: [AnimationStep]
        let difficulty: PieceDifficulty
        let reason: HintReason
        
        static func == (lhs: HintData, rhs: HintData) -> Bool {
            // Compare based on essential properties
            return lhs.targetPiece == rhs.targetPiece &&
                   lhs.hintType == rhs.hintType &&
                   lhs.difficulty == rhs.difficulty
        }
    }
    
    enum HintType: Equatable {
        case nudge                          // Subtle: piece glows or pulses
        case rotation(degrees: Double)      // Show rotation needed
        case flip                          // Show flip for parallelogram
        case position(from: CGPoint, to: CGPoint)  // Show drag path
        case fullSolution                  // Complete demonstration
    }
    
    enum HintReason: Equatable {
        case lastMovedIncorrectly
        case stuckTooLong(seconds: TimeInterval)
        case noRecentProgress
        case userRequested
        case firstPiece
    }
    
    enum PieceDifficulty: Int, Equatable {
        case easy = 1       // Small triangles
        case medium = 2     // Medium triangle, square
        case hard = 3       // Large triangles
        case veryHard = 4   // Parallelogram (can flip)
    }
    
    struct AnimationStep: Equatable {
        let duration: TimeInterval
        let transform: CGAffineTransform
        let description: String
        let highlightType: HighlightType
        
        static func == (lhs: AnimationStep, rhs: AnimationStep) -> Bool {
            return lhs.duration == rhs.duration &&
                   lhs.description == rhs.description &&
                   lhs.highlightType == rhs.highlightType
        }
    }
    
    enum HighlightType: Equatable {
        case none
        case pulse
        case glow
        case arrow
    }
    
    enum FrustrationLevel: Int {
        case none = 0
        case low = 1
        case medium = 2
        case high = 3
    }
    
    // MARK: - Constants
    
    private let stuckThreshold: TimeInterval = 30.0  // 30 seconds without progress
    
    // MARK: - Properties
    
    private var currentDifficulty: UserPreferences.DifficultySetting = .normal
    
    // MARK: - Public Interface
    
    /// Set the difficulty for tolerance calculations
    func setDifficulty(_ difficulty: UserPreferences.DifficultySetting) {
        self.currentDifficulty = difficulty
    }
    
    /// Determine the most appropriate hint based on current game state
    func determineNextHint(
        puzzle: GamePuzzleData,
        placedPieces: [PlacedPiece],
        lastMovedPiece: TangramPieceType?,
        timeSinceLastProgress: TimeInterval,
        previousHints: [HintData] = [],
        validatedTargetIds: Set<String> = [],
        difficultySetting: UserPreferences.DifficultySetting? = nil
    ) -> HintData? {
        
        // Priority 1: Last moved piece was incorrect
        if let lastMoved = lastMovedPiece,
           let placed = placedPieces.first(where: { $0.pieceType == lastMoved }),
           placed.validationState != .correct {
            return createHintForIncorrectPiece(lastMoved, placed, puzzle)
        }
        
        // Priority 2: Player stuck for too long
        if timeSinceLastProgress > stuckThreshold {
            return createHintForStuckPlayer(puzzle, placedPieces, timeSinceLastProgress)
        }
        
        // Priority 3: If there are validated pieces, ALWAYS suggest a connected piece to the validated cluster
        if !validatedTargetIds.isEmpty {
            if let pieceType = selectFrontierConnectedPiece(
                puzzle: puzzle,
                validated: validatedTargetIds,
                placedPieces: placedPieces,
                previousHints: previousHints,
                difficultySetting: difficultySetting
            ) {
                return createHintForPiece(pieceType, puzzle, reason: .userRequested)
            }
            // If adjacency fails, do NOT fall back to disconnected nearest; wait or show none to avoid irrelevant hints
            return nil
        }

        // Priority 4: No validated pieces yet
        if placedPieces.isEmpty {
            // Absolutely first action → show an easy starter
            return createHintForFirstPiece(puzzle)
        }

        // Infer a starting frontier from where the user has begun placing pieces
        if let pieceType = selectFrontierFromPlacedPieces(puzzle: puzzle, placedPieces: placedPieces, previousHints: previousHints) {
            return createHintForPiece(pieceType, puzzle, reason: .userRequested)
        }

        // Last resort: easiest unplaced piece (only when no validated pieces exist)
        let unplacedPieces = findUnplacedPieces(puzzle, placedPieces)
        if let easiestPiece = selectEasiestPiece(unplacedPieces) {
            return createHintForPiece(easiestPiece, puzzle, reason: .userRequested)
        }
        
        return nil
    }
    // MARK: - Connection-aware selection
    
    private func buildAdjacency(for puzzle: GamePuzzleData, difficultySetting: UserPreferences.DifficultySetting? = nil) -> [String: Set<String>] {
        // Build polygon per target id in SK space
        var idToPolygon: [String: [CGPoint]] = [:]
        for t in puzzle.targetPieces {
            let verts = TangramGameGeometry.normalizedVertices(for: t.pieceType)
            let scaled = TangramGameGeometry.scaleVertices(verts, by: TangramGameConstants.visualScale)
            let transformed = TangramGameGeometry.transformVertices(scaled, with: t.transform)
            let sk = transformed.map { TangramPoseMapper.spriteKitPosition(fromRawPosition: $0) }
            idToPolygon[t.id] = sk
        }
        
        // Adjacent if min edge distance < tolerance and edges roughly parallel
        let edgeTolerance: CGFloat = {
            if let d = difficultySetting { return TangramGameConstants.Validation.tolerances(for: d).edgeContact }
            return 14
        }()  // Slightly more generous to ensure adjacency is detected
        var adj: [String: Set<String>] = [:]
        let ids = puzzle.targetPieces.map { $0.id }
        for i in 0..<ids.count {
            for j in (i+1)..<ids.count {
                guard let p1 = idToPolygon[ids[i]], let p2 = idToPolygon[ids[j]] else { continue }
                if polygonsAdjacent(p1, p2, edgeTolerance: edgeTolerance) {
                    adj[ids[i], default: []].insert(ids[j])
                    adj[ids[j], default: []].insert(ids[i])
                }
            }
        }
        return adj
    }
    
    private func polygonsAdjacent(_ a: [CGPoint], _ b: [CGPoint], edgeTolerance: CGFloat) -> Bool {
        // Simple min-edge-distance check with parallelism heuristic
        func edges(_ poly: [CGPoint]) -> [(CGPoint, CGPoint)] {
            guard poly.count > 1 else { return [] }
            return (0..<poly.count).map { i in
                (poly[i], poly[(i+1) % poly.count])
            }
        }
        let ea = edges(a)
        let eb = edges(b)
        for (a0, a1) in ea {
            for (b0, b1) in eb {
                // Distance between segments
                let d = segmentDistance(a0, a1, b0, b1)
                if d <= edgeTolerance {
                    // Check parallelism (dot product of normals ~ 0)
                    let va = CGVector(dx: a1.x - a0.x, dy: a1.y - a0.y)
                    let vb = CGVector(dx: b1.x - b0.x, dy: b1.y - b0.y)
                    let na = CGVector(dx: -va.dy, dy: va.dx)
                    let nb = CGVector(dx: -vb.dy, dy: vb.dx)
                    let dot = na.dx*nb.dx + na.dy*nb.dy
                    let mag = hypot(na.dx, na.dy) * hypot(nb.dx, nb.dy)
                    if mag > 0, abs(dot/mag) < 0.2 { return true }
                }
            }
        }
        return false
    }
    
    private func segmentDistance(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ p4: CGPoint) -> CGFloat {
        // Compute min distance between two segments
        func clamp(_ x: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { max(lo, min(hi, x)) }
        let u = CGVector(dx: p2.x - p1.x, dy: p2.y - p1.y)
        let v = CGVector(dx: p4.x - p3.x, dy: p4.y - p3.y)
        let w0 = CGVector(dx: p1.x - p3.x, dy: p1.y - p3.y)
        let a = u.dx*u.dx + u.dy*u.dy
        let b = u.dx*v.dx + u.dy*v.dy
        let c = v.dx*v.dx + v.dy*v.dy
        let d = u.dx*w0.dx + u.dy*w0.dy
        let e = v.dx*w0.dx + v.dy*w0.dy
        let denom = a*c - b*b
        var sc: CGFloat, tc: CGFloat
        if denom < 1e-6 {
            sc = 0
            tc = clamp(e/c, 0, 1)
        } else {
            sc = clamp((b*e - c*d)/denom, 0, 1)
            tc = clamp((a*e - b*d)/denom, 0, 1)
        }
        let dpx = w0.dx + sc*u.dx - tc*v.dx
        let dpy = w0.dy + sc*u.dy - tc*v.dy
        return hypot(dpx, dpy)
    }
    
    // New frontier-based, connection-aware selection that avoids repeating the same disconnected piece
    private func selectFrontierConnectedPiece(puzzle: GamePuzzleData,
                                              validated: Set<String>,
                                              placedPieces: [PlacedPiece],
                                              previousHints: [HintData],
                                              difficultySetting: UserPreferences.DifficultySetting? = nil) -> TangramPieceType? {
        let adj = buildAdjacency(for: puzzle, difficultySetting: difficultySetting)
        let allIds = Set(puzzle.targetPieces.map { $0.id })
        let unvalidatedIds = allIds.subtracting(validated)

        // Find the largest connected component within the validated set
        let component = largestValidatedComponent(validated: validated, adjacency: adj)
        if component.isEmpty { return nil }

        // Frontier = neighbors of component that are unvalidated
        var frontier: Set<String> = []
        for v in component {
            if let ns = adj[v] {
                for n in ns where unvalidatedIds.contains(n) {
                    frontier.insert(n)
                }
            }
        }
        if frontier.isEmpty { return nil }

        // Build scoring
        // Compute centroid of component for proximity
        let centroid: CGPoint = centroidOf(ids: component, puzzle: puzzle)
        // Recent hint penalty to avoid repeating same piece type endlessly
        let recentPieceTypes = Set(previousHints.suffix(2).map { $0.targetPiece })
        // Prefer candidates near any incorrectly placed piece the user is trying
        let incorrectTypesNearby: Set<TangramPieceType> = Set(placedPieces.filter { $0.validationState != .correct }.map { $0.pieceType })

        var best: (type: TangramPieceType, score: CGFloat)?
        for id in frontier {
            guard let t = puzzle.targetPieces.first(where: { $0.id == id }) else { continue }
            let neighbors = adj[id] ?? []
            let neighborsOpened = neighbors.filter { unvalidatedIds.contains($0) }.count
            let neighborValidatedCount = neighbors.filter { component.contains($0) }.count
            let posRaw = TangramPoseMapper.rawPosition(from: t.transform)
            let posSK = TangramPoseMapper.spriteKitPosition(fromRawPosition: posRaw)
            let proximity = 1 / max(1, hypot(posSK.x - centroid.x, posSK.y - centroid.y))
            let diffPenalty: CGFloat = CGFloat(getPieceDifficulty(t.pieceType).rawValue) * 0.06
            let repeatPenalty: CGFloat = recentPieceTypes.contains(t.pieceType) ? 0.5 : 0.0
            let userIntentBoost: CGFloat = incorrectTypesNearby.contains(t.pieceType) ? 0.4 : 0.0

            // Score weights: prioritize tying into current cluster (neighborValidatedCount), next openings, then proximity
            let score = CGFloat(neighborValidatedCount) * 5
                     + CGFloat(neighborsOpened) * 3
                     + proximity * 1.5
                     + userIntentBoost
                     - diffPenalty
                     - repeatPenalty

            if best == nil || score > best!.score { best = (t.pieceType, score) }
        }

        return best?.type
    }

    private func largestValidatedComponent(validated: Set<String>, adjacency: [String: Set<String>]) -> Set<String> {
        var visited: Set<String> = []
        var best: Set<String> = []
        for start in validated where !visited.contains(start) {
            var comp: Set<String> = []
            var stack: [String] = [start]
            visited.insert(start)
            while let v = stack.popLast() {
                comp.insert(v)
                for n in (adjacency[v] ?? []) where validated.contains(n) && !visited.contains(n) {
                    visited.insert(n)
                    stack.append(n)
                }
            }
            if comp.count > best.count { best = comp }
        }
        return best
    }

    private func centroidOf(ids: Set<String>, puzzle: GamePuzzleData) -> CGPoint {
        var sum = CGPoint.zero; var count: CGFloat = 0
        for id in ids {
            if let t = puzzle.targetPieces.first(where: { $0.id == id }) {
                let raw = TangramPoseMapper.rawPosition(from: t.transform)
                let sk = TangramPoseMapper.spriteKitPosition(fromRawPosition: raw)
                sum.x += sk.x; sum.y += sk.y; count += 1
            }
        }
        if count == 0 { return .zero }
        return CGPoint(x: sum.x/count, y: sum.y/count)
    }

    // Fallback when adjacency fails: nearest remaining target to the centroid of validated cluster
    private func selectNearestToValidated(puzzle: GamePuzzleData,
                                          validated: Set<String>,
                                          previousHints: [HintData]) -> TangramPieceType? {
        let centroid = centroidOf(ids: validated, puzzle: puzzle)
        let remaining = Set(puzzle.targetPieces.map { $0.id }).subtracting(validated)
        let recent = Set(previousHints.suffix(2).map { $0.targetPiece })
        var best: (type: TangramPieceType, dist: CGFloat)?
        for id in remaining {
            guard let t = puzzle.targetPieces.first(where: { $0.id == id }) else { continue }
            let raw = TangramPoseMapper.rawPosition(from: t.transform)
            let sk = TangramPoseMapper.spriteKitPosition(fromRawPosition: raw)
            let d = hypot(sk.x - centroid.x, sk.y - centroid.y)
            let penalty: CGFloat = recent.contains(t.pieceType) ? 30 : 0
            let adj = d + penalty
            if best == nil || adj < best!.dist { best = (t.pieceType, adj) }
        }
        return best?.type
    }

    // Infer frontier using placed pieces when no validated targets yet
    private func selectFrontierFromPlacedPieces(puzzle: GamePuzzleData,
                                                placedPieces: [PlacedPiece],
                                                previousHints: [HintData]) -> TangramPieceType? {
        let adj = buildAdjacency(for: puzzle)
        // Project placed pieces onto nearest targets of the same type within a loose threshold
        var seed: Set<String> = []
        for p in placedPieces {
            // Only consider stationary or slowly moving pieces to avoid noise
            if !p.isPlacedLongEnough() { continue }
            var best: (id: String, dist: CGFloat)?
            for t in puzzle.targetPieces where t.pieceType == p.pieceType {
                let raw = TangramPoseMapper.rawPosition(from: t.transform)
                let sk = TangramPoseMapper.spriteKitPosition(fromRawPosition: raw)
                let d = hypot(p.position.x - sk.x, p.position.y - sk.y)
                if best == nil || d < best!.dist { best = (t.id, d) }
            }
            if let best = best, best.dist < 140 { // generous to capture intent
                seed.insert(best.id)
            }
        }
        if seed.isEmpty { return nil }

        // Build frontier around projected seed
        var frontier: Set<String> = []
        for s in seed {
            if let ns = adj[s] {
                frontier.formUnion(ns.filter { !seed.contains($0) })
            }
        }
        if frontier.isEmpty { return nil }

        let centroid = centroidOf(ids: seed, puzzle: puzzle)
        let recentTypes = Set(previousHints.suffix(2).map { $0.targetPiece })

        var bestPick: (type: TangramPieceType, score: CGFloat)?
        for id in frontier {
            guard let t = puzzle.targetPieces.first(where: { $0.id == id }) else { continue }
            let neighbors = adj[id] ?? []
            let neighborSeedCount = neighbors.filter { seed.contains($0) }.count
            let raw = TangramPoseMapper.rawPosition(from: t.transform)
            let sk = TangramPoseMapper.spriteKitPosition(fromRawPosition: raw)
            let proximity = 1 / max(1, hypot(sk.x - centroid.x, sk.y - centroid.y))
            let diffPenalty: CGFloat = CGFloat(getPieceDifficulty(t.pieceType).rawValue) * 0.05
            let repeatPenalty: CGFloat = recentTypes.contains(t.pieceType) ? 0.4 : 0.0
            let score = CGFloat(neighborSeedCount) * 5 + proximity * 1.5 - diffPenalty - repeatPenalty
            if bestPick == nil || score > bestPick!.score { bestPick = (t.pieceType, score) }
        }
        return bestPick?.type
    }
    
    // MARK: - Hint Creation
    
    private func createHintForIncorrectPiece(
        _ pieceType: TangramPieceType,
        _ placed: PlacedPiece,
        _ puzzle: GamePuzzleData
    ) -> HintData? {
        
        guard let target = puzzle.targetPieces.first(where: { $0.pieceType == pieceType }) else {
            return nil
        }
        
        // Determine what's wrong with the placement
        let currentTransform = createTransformFromPlacedPiece(placed)
        let hintType = determineHintType(current: placed, target: target)
        
        // Create animation steps based on what needs correction
        let animationSteps = createAnimationSteps(
            from: currentTransform,
            to: target.transform,
            pieceType: pieceType,
            hintType: hintType
        )
        
        return HintData(
            targetPiece: pieceType,
            currentTransform: currentTransform,
            targetTransform: target.transform,
            hintType: hintType,
            animationSteps: animationSteps,
            difficulty: getPieceDifficulty(pieceType),
            reason: .lastMovedIncorrectly
        )
    }
    
    private func createHintForStuckPlayer(
        _ puzzle: GamePuzzleData,
        _ placedPieces: [PlacedPiece],
        _ timeStuck: TimeInterval
    ) -> HintData? {
        
        // Find the easiest unplaced piece
        let unplacedPieces = findUnplacedPieces(puzzle, placedPieces)
        guard let targetPieceType = selectEasiestPiece(unplacedPieces),
              let target = puzzle.targetPieces.first(where: { $0.pieceType == targetPieceType }) else {
            return nil
        }
        
        // For stuck players, provide more complete hints
        // Convert target position to SK space
        let rawPos = TangramPoseMapper.rawPosition(from: target.transform)
        let targetPosSK = TangramPoseMapper.spriteKitPosition(fromRawPosition: rawPos)
        
        let hintType: HintType = timeStuck > 60 ? .fullSolution : .position(
            from: getDefaultStartPosition(for: targetPieceType),
            to: targetPosSK
        )
        
        let animationSteps = createAnimationSteps(
            from: nil,
            to: target.transform,
            pieceType: targetPieceType,
            hintType: hintType
        )
        
        return HintData(
            targetPiece: targetPieceType,
            currentTransform: nil,
            targetTransform: target.transform,
            hintType: hintType,
            animationSteps: animationSteps,
            difficulty: getPieceDifficulty(targetPieceType),
            reason: .stuckTooLong(seconds: timeStuck)
        )
    }
    
    private func createHintForFirstPiece(_ puzzle: GamePuzzleData) -> HintData? {
        // For first piece, suggest an easy one
        let firstPieceType = selectEasiestPiece(puzzle.targetPieces.map { $0.pieceType })
        guard let targetPieceType = firstPieceType,
              let target = puzzle.targetPieces.first(where: { $0.pieceType == targetPieceType }) else {
            return nil
        }
        
        // Convert target position to SK space
        let rawPos = TangramPoseMapper.rawPosition(from: target.transform)
        let targetPosSK = TangramPoseMapper.spriteKitPosition(fromRawPosition: rawPos)
        
        let hintType: HintType = .position(
            from: getDefaultStartPosition(for: targetPieceType),
            to: targetPosSK
        )
        
        let animationSteps = createAnimationSteps(
            from: nil,
            to: target.transform,
            pieceType: targetPieceType,
            hintType: hintType
        )
        
        return HintData(
            targetPiece: targetPieceType,
            currentTransform: nil,
            targetTransform: target.transform,
            hintType: hintType,
            animationSteps: animationSteps,
            difficulty: getPieceDifficulty(targetPieceType),
            reason: .firstPiece
        )
    }
    
    private func createHintForPiece(
        _ pieceType: TangramPieceType,
        _ puzzle: GamePuzzleData,
        reason: HintReason
    ) -> HintData? {
        
        guard let target = puzzle.targetPieces.first(where: { $0.pieceType == pieceType }) else {
            return nil
        }
        
        // Convert target position to SK space
        let rawPos = TangramPoseMapper.rawPosition(from: target.transform)
        let targetPosSK = TangramPoseMapper.spriteKitPosition(fromRawPosition: rawPos)
        
        let startPos = getDefaultStartPosition(for: pieceType)
        let hintType: HintType = .position(from: startPos, to: targetPosSK)
        
        let animationSteps = createAnimationSteps(
            from: nil,
            to: target.transform,
            pieceType: pieceType,
            hintType: hintType
        )
        
        return HintData(
            targetPiece: pieceType,
            currentTransform: nil,
            targetTransform: target.transform,
            hintType: hintType,
            animationSteps: animationSteps,
            difficulty: getPieceDifficulty(pieceType),
            reason: reason
        )
    }
    
    // MARK: - Helper Methods
    
    private func determineHintType(current: PlacedPiece, target: GamePuzzleData.TargetPiece) -> HintType {
        // Get tolerances from unified source based on difficulty
        let tolerances = TangramGameConstants.Validation.tolerances(for: currentDifficulty)
        let rotationTolerance = tolerances.rotationDeg
        let positionTolerance = tolerances.position
        
        // Convert target position to SK space for comparison
        let rawPosition = TangramPoseMapper.rawPosition(from: target.transform)
        let targetPositionSK = TangramPoseMapper.spriteKitPosition(fromRawPosition: rawPosition)
        
        // Check position difference in SK space
        let positionDiff = hypot(
            current.position.x - targetPositionSK.x,
            current.position.y - targetPositionSK.y
        )
        
        // Compute feature angles for proper comparison
        // Use the actual piece canonical (135° for triangles, not 45°)
        let pieceCanonical: CGFloat
        switch current.pieceType {
        case .smallTriangle1, .smallTriangle2, .mediumTriangle, .largeTriangle1, .largeTriangle2:
            pieceCanonical = 3 * .pi / 4  // 135° - actual hypotenuse direction
        case .square:
            pieceCanonical = 0
        case .parallelogram:
            pieceCanonical = 0
        }
        let adjustedLocalBaseline = current.isFlipped ? -pieceCanonical : pieceCanonical
        let currentFeatureAngle = TangramRotationValidator.normalizeAngle(current.rotation * .pi / 180 + adjustedLocalBaseline)
        
        // Compute target feature angle from the baked vertices
        let targetFeatureAngle = computeTargetFeatureAngle(from: target)
        
        // Check if rotation is correct using feature angles
        let rotationCorrect = TangramRotationValidator.isRotationValid(
            currentRotation: currentFeatureAngle,
            targetRotation: targetFeatureAngle,
            pieceType: current.pieceType,
            isFlipped: current.isFlipped,
            toleranceDegrees: rotationTolerance
        )
        
        // Check if flip is needed (for parallelogram)
        let needsFlip = current.pieceType == .parallelogram && isFlipNeeded(current, target)
        
        // Determine hint type based on what's wrong
        if needsFlip {
            return .flip
        } else if !rotationCorrect && positionDiff < positionTolerance {
            // Find the nearest valid rotation in feature space
            let nearestFeatureAngle = TangramRotationValidator.nearestValidRotation(
                currentRotation: currentFeatureAngle,
                targetRotation: targetFeatureAngle,
                pieceType: current.pieceType,
                isFlipped: current.isFlipped
            )
            // Convert back to node zRotation for display
            let nearestNodeZ = nearestFeatureAngle - adjustedLocalBaseline
            return .rotation(degrees: nearestNodeZ * 180 / .pi)
        } else if positionDiff >= positionTolerance {
            return .position(from: current.position, to: targetPositionSK)
        } else {
            return .nudge
        }
    }
    
    private func isFlipNeeded(_ placed: PlacedPiece, _ target: GamePuzzleData.TargetPiece) -> Bool {
        // Only relevant for parallelogram
        guard placed.pieceType == .parallelogram else { return false }
        
        // Check if transform has negative determinant (indicates flip)
        let targetDeterminant = target.transform.a * target.transform.d - target.transform.b * target.transform.c
        let targetIsFlipped = targetDeterminant < 0
        
        // Flip is needed when current state MATCHES target state (inverted logic)
        // Due to coordinate system handedness, our parallelogram is mirrored
        // This aligns with validator logic: flipValid = (isFlipped != targetIsFlipped)
        return placed.isFlipped == targetIsFlipped
    }
    
    private func createAnimationSteps(
        from currentTransform: CGAffineTransform?,
        to targetTransform: CGAffineTransform,
        pieceType: TangramPieceType,
        hintType: HintType
    ) -> [AnimationStep] {
        
        var steps: [AnimationStep] = []
        
        switch hintType {
        case .nudge:
            // Simple pulse at current position
            steps.append(AnimationStep(
                duration: 0.5,
                transform: currentTransform ?? targetTransform,
                description: "Attention needed",
                highlightType: .pulse
            ))
            
        case .rotation(let degrees):
            // Show rotation animation
            if let current = currentTransform {
                let targetAngleRad = CGFloat(degrees * .pi / 180)
                let rawPos = TangramPoseMapper.rawPosition(from: current)
                let skPos = TangramPoseMapper.spriteKitPosition(fromRawPosition: rawPos)
                
                // Create transform for display
                var skTransform = CGAffineTransform.identity
                skTransform = skTransform.rotated(by: targetAngleRad)
                skTransform = skTransform.translatedBy(x: skPos.x, y: skPos.y)
                
                steps.append(AnimationStep(
                    duration: 1.5,
                    transform: skTransform,
                    description: "Rotate to \(Int(degrees))°",
                    highlightType: .arrow
                ))
            }
            
        case .flip:
            // Show flip animation for parallelogram
            if let current = currentTransform {
                var flipped = current
                flipped.a = -flipped.a  // Flip horizontally
                steps.append(AnimationStep(
                    duration: 0.8,
                    transform: flipped,
                    description: "Flip piece",
                    highlightType: .glow
                ))
            }
            
        case .position(_, let toPos):
            // Show movement from current to target
            // Get TRUE expected SK rotation (no baseline adjustment)
            let rawAngle = TangramPoseMapper.rawAngle(from: targetTransform)
            let targetZRotation = TangramPoseMapper.spriteKitAngle(fromRawAngle: rawAngle)
            
            // Create transform for target position
            var skTransform = CGAffineTransform.identity
            skTransform = skTransform.rotated(by: targetZRotation)
            skTransform = skTransform.translatedBy(x: toPos.x, y: toPos.y)
            
            steps.append(AnimationStep(
                duration: 2.0,
                transform: skTransform,
                description: "Move to position",
                highlightType: .arrow
            ))
            
        case .fullSolution:
            // Complete sequence: show rotation, flip if needed, then position
            // Get TRUE expected SK rotation (no baseline adjustment)
            let rawAngle = TangramPoseMapper.rawAngle(from: targetTransform)
            let targetZRotation = TangramPoseMapper.spriteKitAngle(fromRawAngle: rawAngle)
            
            let rawPos = TangramPoseMapper.rawPosition(from: targetTransform)
            let targetPosSK = TangramPoseMapper.spriteKitPosition(fromRawPosition: rawPos)
            
            // Step 1: Show piece appearing at default position
            let startPos = getDefaultStartPosition(for: pieceType)
            var startTransform = CGAffineTransform.identity
            startTransform = startTransform.translatedBy(x: startPos.x, y: startPos.y)
            steps.append(AnimationStep(
                duration: 0.5,
                transform: startTransform,
                description: "Piece appears",
                highlightType: .glow
            ))
            
            // Step 2: Rotate if needed
            if abs(targetZRotation) > 0.1 {
                var rotateTransform = CGAffineTransform.identity
                rotateTransform = rotateTransform.rotated(by: targetZRotation)
                rotateTransform = rotateTransform.translatedBy(x: startPos.x, y: startPos.y)
                steps.append(AnimationStep(
                    duration: 1.0,
                    transform: rotateTransform,
                    description: "Rotate piece",
                    highlightType: .arrow
                ))
            }
            
            // Step 3: Move to final position
            var finalTransform = CGAffineTransform.identity
            finalTransform = finalTransform.rotated(by: targetZRotation)
            finalTransform = finalTransform.translatedBy(x: targetPosSK.x, y: targetPosSK.y)
            steps.append(AnimationStep(
                duration: 1.5,
                transform: finalTransform,
                description: "Move to position",
                highlightType: .arrow
            ))
        }
        
        return steps
    }
    
    private func findUnplacedPieces(_ puzzle: GamePuzzleData, _ placedPieces: [PlacedPiece]) -> [TangramPieceType] {
        // Only consider pieces that are correctly placed as "done"
        // This ensures hints are given for:
        // 1. Pieces not placed at all
        // 2. Pieces placed incorrectly
        let correctlyPlacedTypes = Set(
            placedPieces
                .filter { $0.validationState == .correct }
                .map { $0.pieceType }
        )
        
        let allTypes = Set(puzzle.targetPieces.map { $0.pieceType })
        
        // Return pieces that still need to be placed correctly
        return Array(allTypes.subtracting(correctlyPlacedTypes))
    }
    
    private func selectEasiestPiece(_ pieces: [TangramPieceType]) -> TangramPieceType? {
        // Difficulty order: small triangles < medium triangle < square < large triangles < parallelogram
        let difficultyOrder: [TangramPieceType] = [
            .smallTriangle1, .smallTriangle2,
            .mediumTriangle,
            .square,
            .largeTriangle1, .largeTriangle2,
            .parallelogram
        ]
        
        for pieceType in difficultyOrder {
            if pieces.contains(pieceType) {
                return pieceType
            }
        }
        return pieces.first
    }
    
    private func getPieceDifficulty(_ piece: TangramPieceType) -> PieceDifficulty {
        switch piece {
        case .smallTriangle1, .smallTriangle2:
            return .easy
        case .mediumTriangle, .square:
            return .medium
        case .largeTriangle1, .largeTriangle2:
            return .hard
        case .parallelogram:
            return .veryHard
        }
    }
    
    private func createTransformFromPlacedPiece(_ piece: PlacedPiece) -> CGAffineTransform {
        // Create transform from placed piece position and rotation
        // Convert from SK space back to raw for comparison
        let skAngle = piece.rotation * .pi / 180
        let rawAngle = TangramPoseMapper.rawAngle(fromSpriteKitAngle: skAngle)
        let rawPos = TangramPoseMapper.rawPosition(fromSpriteKitPosition: piece.position)
        
        var transform = CGAffineTransform.identity
        transform = transform.rotated(by: rawAngle)
        transform = transform.translatedBy(x: rawPos.x, y: rawPos.y)
        return transform
    }
    
    private func computeTargetFeatureAngle(from target: GamePuzzleData.TargetPiece) -> CGFloat {
        // Compute target feature angle consistently with TangramPuzzleScene
        // Get the canonical feature angle for this piece type
        let canonicalFeatureSK = TangramGameConstants.CanonicalFeatures.canonicalFeatureAngle(for: target.pieceType)
        
        // Get the rotation from the transform
        let rawAngle = TangramPoseMapper.rawAngle(from: target.transform)
        let expectedZRotationSK = TangramPoseMapper.spriteKitAngle(fromRawAngle: rawAngle)
        
        // Add the rotation to the canonical to get the target feature angle
        return TangramRotationValidator.normalizeAngle(canonicalFeatureSK + expectedZRotationSK)
    }
    
    private func getDefaultStartPosition(for pieceType: TangramPieceType) -> CGPoint {
        // Default positions matching the actual piece layout in TangramPuzzleScene
        // These are approximations when we can't access the actual scene
        // Return positions in SpriteKit space (Y-up) to match scene layout
        let screenWidth: CGFloat = 390  // iPhone standard width
        let screenHeight: CGFloat = 844  // iPhone standard height
        
        let pieceSize: CGFloat = 80
        let margin: CGFloat = 40
        let minX = pieceSize + margin  // 120
        let maxX = screenWidth - pieceSize - margin  // 270
        let maxY = screenHeight * 0.35  // ~295 (bottom 35% of screen)
        
        // Map pieces to their typical grid positions (index order)
        let pieceOrder: [TangramPieceType] = [
            .smallTriangle1,   // index 0: col 0, row 0
            .smallTriangle2,   // index 1: col 1, row 0
            .mediumTriangle,   // index 2: col 2, row 0
            .square,           // index 3: col 0, row 1
            .largeTriangle1,   // index 4: col 1, row 1
            .largeTriangle2,   // index 5: col 2, row 1
            .parallelogram     // index 6: col 0, row 2
        ]
        
        guard let index = pieceOrder.firstIndex(of: pieceType) else {
            // Fallback to center-bottom if piece not found
            return CGPoint(x: screenWidth / 2, y: 150)
        }
        
        let cols = 3
        let rows = 3
        let col = index % cols
        let row = index / cols
        
        // Calculate position matching the scene's layout logic
        let xRange = maxX - minX  // 150
        let yRange = maxY - pieceSize  // ~175
        
        let x = minX + (xRange / CGFloat(cols)) * (CGFloat(col) + 0.5)
        let y = pieceSize + (yRange / CGFloat(rows)) * (CGFloat(row) + 0.5)
        
        // Return in SpriteKit coordinates (Y-up) to match scene
        return CGPoint(x: x, y: y)  // Already in SK space
    }
    
    /// Gets the actual position of a piece from the scene if available
    /// Falls back to default position if scene is not accessible
    func getActualPiecePosition(for pieceType: TangramPieceType, 
                               availablePieces: [String: PuzzlePieceNode]?,
                               piecesLayer: SKNode?,
                               scene: SKScene?) -> CGPoint {
        // Try to get actual position from scene
        if let pieces = availablePieces,
           let piece = pieces[pieceType.rawValue],
           let layer = piecesLayer,
           let scene = scene {
            // Convert piece position from piecesLayer to scene space
            return layer.convert(piece.position, to: scene)
        }
        
        // Fallback to default approximation
        return getDefaultStartPosition(for: pieceType)
    }
    
    /// Extracts rotation angle from CGAffineTransform with robust floating-point handling
    /// Handles cases where sin/cos values have floating-point precision errors (e.g., 180° rotations)
    
    // MARK: - Protocol Conformance
    
    /// Generates appropriate hint based on game state (HintProviding protocol)
    func generateHint(gameState: PuzzleGameState, lastMovedPiece: TangramPieceType?) -> HintData {
        // Use existing determineNextHint logic, but return a default hint if none found
        if let hint = determineNextHint(
            puzzle: gameState.targetPuzzle,
            placedPieces: [],  // Could be extended to track placed pieces in game state
            lastMovedPiece: lastMovedPiece,
            timeSinceLastProgress: 0,
            previousHints: []
        ) {
            return hint
        }
        
        // Return a default hint for the first piece
        return createHintForFirstPiece(gameState.targetPuzzle) ?? HintData(
            targetPiece: .square,
            currentTransform: nil,
            targetTransform: .identity,
            hintType: .nudge,
            animationSteps: [],
            difficulty: .easy,
            reason: .userRequested
        )
    }
    
    /// Calculates frustration level based on game state (HintProviding protocol)
    func calculateFrustrationLevel(gameState: PuzzleGameState) -> FrustrationLevel {
        // Determine frustration based on hints used and time elapsed
        let hintsUsed = gameState.hintsUsed
        
        switch hintsUsed {
        case 0:
            return .none
        case 1...2:
            return .low
        case 3...5:
            return .medium
        default:
            return .high
        }
    }
}