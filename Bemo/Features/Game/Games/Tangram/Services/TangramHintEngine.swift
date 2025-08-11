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
    private let rotationTolerance: Double = 15.0      // Degrees
    private let positionTolerance: CGFloat = 50.0     // Points
    
    // MARK: - Public Interface
    
    /// Determine the most appropriate hint based on current game state
    func determineNextHint(
        puzzle: GamePuzzleData,
        placedPieces: [PlacedPiece],
        lastMovedPiece: TangramPieceType?,
        timeSinceLastProgress: TimeInterval,
        previousHints: [HintData] = []
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
        
        // Priority 3: No pieces placed yet - help with first piece
        if placedPieces.isEmpty {
            return createHintForFirstPiece(puzzle)
        }
        
        // Priority 4: Find easiest unplaced piece
        let unplacedPieces = findUnplacedPieces(puzzle, placedPieces)
        if let easiestPiece = selectEasiestPiece(unplacedPieces) {
            return createHintForPiece(easiestPiece, puzzle, reason: .userRequested)
        }
        
        return nil
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