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
        let hintType: HintType = timeStuck > 60 ? .fullSolution : .position(
            from: getDefaultStartPosition(for: targetPieceType),
            to: target.position
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
        
        let animationSteps = createAnimationSteps(
            from: nil,
            to: target.transform,
            pieceType: targetPieceType,
            hintType: .position(
                from: getDefaultStartPosition(for: targetPieceType),
                to: target.position
            )
        )
        
        return HintData(
            targetPiece: targetPieceType,
            currentTransform: nil,
            targetTransform: target.transform,
            hintType: .position(
                from: getDefaultStartPosition(for: targetPieceType),
                to: target.position
            ),
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
        
        let startPos = getDefaultStartPosition(for: pieceType)
        let hintType: HintType = .position(from: startPos, to: target.position)
        
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
        // Check position difference
        let positionDiff = hypot(
            current.position.x - target.position.x,
            current.position.y - target.position.y
        )
        
        // Check rotation using proper validator
        let targetRotationRad = atan2(target.transform.b, target.transform.a)
        let currentRotationRad = current.rotation * .pi / 180
        
        // Get flip state from placed piece
        let isFlipped = current.isFlipped
        
        let rotationCorrect = TangramRotationValidator.isRotationValid(
            currentRotation: currentRotationRad,
            targetRotation: targetRotationRad,
            pieceType: current.pieceType,
            isFlipped: isFlipped,
            toleranceDegrees: rotationTolerance
        )
        
        // Check if flip is needed (for parallelogram)
        let needsFlip = current.pieceType == .parallelogram && isFlipNeeded(current, target)
        
        // Determine hint type based on what's wrong
        if needsFlip {
            return .flip
        } else if !rotationCorrect && positionDiff < positionTolerance {
            // Find the nearest valid rotation for the hint
            let nearestRotation = TangramRotationValidator.nearestValidRotation(
                currentRotation: currentRotationRad,
                targetRotation: targetRotationRad,
                pieceType: current.pieceType,
                isFlipped: isFlipped
            )
            return .rotation(degrees: nearestRotation * 180 / .pi)
        } else if positionDiff >= positionTolerance {
            return .position(from: current.position, to: target.position)
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
        
        // Compare placed piece flip state with target
        return placed.isFlipped != targetIsFlipped
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
                steps.append(AnimationStep(
                    duration: 1.5,
                    transform: CGAffineTransform(rotationAngle: CGFloat(degrees * .pi / 180))
                        .translatedBy(x: current.tx, y: current.ty),
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
            
        case .position(let from, let to):
            // Show movement from current to target
            steps.append(AnimationStep(
                duration: 2.0,
                transform: targetTransform,
                description: "Move to position",
                highlightType: .arrow
            ))
            
        case .fullSolution:
            // Complete sequence: show rotation, flip if needed, then position
            let targetRotation = atan2(targetTransform.b, targetTransform.a)
            
            // Step 1: Show piece appearing
            steps.append(AnimationStep(
                duration: 0.5,
                transform: CGAffineTransform.identity,
                description: "Piece appears",
                highlightType: .glow
            ))
            
            // Step 2: Rotate if needed
            if abs(targetRotation) > 0.1 {
                steps.append(AnimationStep(
                    duration: 1.0,
                    transform: CGAffineTransform(rotationAngle: targetRotation),
                    description: "Rotate piece",
                    highlightType: .arrow
                ))
            }
            
            // Step 3: Move to final position
            steps.append(AnimationStep(
                duration: 1.5,
                transform: targetTransform,
                description: "Move to position",
                highlightType: .arrow
            ))
        }
        
        return steps
    }
    
    private func findUnplacedPieces(_ puzzle: GamePuzzleData, _ placedPieces: [PlacedPiece]) -> [TangramPieceType] {
        let placedTypes = Set(placedPieces.map { $0.pieceType })
        let allTypes = Set(puzzle.targetPieces.map { $0.pieceType })
        return Array(allTypes.subtracting(placedTypes))
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
        var transform = CGAffineTransform.identity
        transform = transform.rotated(by: piece.rotation * .pi / 180)
        transform = transform.translatedBy(x: piece.position.x, y: piece.position.y)
        return transform
    }
    
    private func getDefaultStartPosition(for pieceType: TangramPieceType) -> CGPoint {
        // Default positions for pieces at bottom of screen
        // These would typically be where pieces start in the game
        switch pieceType {
        case .smallTriangle1:
            return CGPoint(x: 100, y: 100)
        case .smallTriangle2:
            return CGPoint(x: 200, y: 100)
        case .mediumTriangle:
            return CGPoint(x: 300, y: 100)
        case .square:
            return CGPoint(x: 400, y: 100)
        case .largeTriangle1:
            return CGPoint(x: 150, y: 150)
        case .largeTriangle2:
            return CGPoint(x: 350, y: 150)
        case .parallelogram:
            return CGPoint(x: 250, y: 150)
        }
    }
}