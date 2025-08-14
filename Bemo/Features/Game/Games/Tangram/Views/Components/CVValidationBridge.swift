//
//  CVValidationBridge.swift
//  Bemo
//
//  Bridge between TangramPuzzleScene and TangramValidationEngine for CV integration
//

// WHAT: Adapter that converts scene state to validation engine format and applies results
// ARCHITECTURE: Component bridging View layer (Scene) with Service layer (ValidationEngine)
// USAGE: Scene calls bridge methods which delegate to engine and apply results back to scene

import SpriteKit
import QuartzCore
import Foundation

// MARK: - CGVector Extension for velocity calculations
extension CGVector {
    func length() -> CGFloat {
        return sqrt(dx * dx + dy * dy)
    }
}

/// Bridge between scene and validation engine for clean CV integration
class CVValidationBridge {
    
    // MARK: - Properties
    
    private let validationEngine: TangramValidationEngine
    private weak var scene: TangramPuzzleScene?
    private var lastValidationTime: TimeInterval = 0
    // Max engine rate; real triggers are event-driven via CV frame signature or drag end
    private let validationThrottle: TimeInterval = 0.1 // allow up to 10Hz
    private let placementValidationDelay: TimeInterval = 0.5 // 500ms for placement validation
    private var pendingValidationTask: Task<Void, Never>?
    private var hasUserIntent: Bool = false
    private var lastNudgeShownAt: TimeInterval = 0
    private var lastNudgeTargetId: String?
    // Per-piece nudge buffering and cooldown
    private var pendingPieceNudges: [String: NudgeContent] = [:]
    private var lastPieceNudgeShownAt: [String: TimeInterval] = [:]
    private let pieceNudgeCooldown: TimeInterval = 1.2
    // Gate repeated "Good job" per unchanged orientation (rounded deg + flip)
    private var lastOrientationSignature: [String: (deg: Int, flip: Bool)] = [:]
    
    // MARK: - Initialization
    
    init(scene: TangramPuzzleScene, difficulty: UserPreferences.DifficultySetting) {
        self.scene = scene
        self.validationEngine = TangramValidationEngine(difficulty: difficulty)
    }
    
    // MARK: - Public Interface
    
    /// Process validation for a piece that was just placed/moved
    func validatePiece(_ piece: PuzzlePieceNode) {
        guard let scene = scene,
              scene.puzzle != nil else { return }
        
        // Cancel any pending validation
        pendingValidationTask?.cancel()
        hasUserIntent = true
        
        // Throttle validation calls
        let now = CACurrentMediaTime()
        let timeSinceLastValidation = now - lastValidationTime
        
        // If piece is moving (high velocity), use throttle; otherwise use placement delay
        let isMoving = (piece.physicsBody?.velocity.length() ?? 0) > 10.0
        let delay = isMoving ? validationThrottle : placementValidationDelay
        
        if timeSinceLastValidation < delay {
            // Schedule validation after delay
            pendingValidationTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    self?.performValidation(for: piece)
                }
            }
            return
        }
        
        performValidation(for: piece)
    }
    
    private func performValidation(for piece: PuzzlePieceNode) {
        guard let scene = scene,
              let puzzle = scene.puzzle else { return }
        
        lastValidationTime = CACurrentMediaTime()
        
        // Create observations from current scene state
        let observations = createObservations(from: scene)
        
        // Process through validation engine; force dwell-based validation immediately after placement/move
        let result = validationEngine.process(
            frame: observations,
            puzzle: puzzle,
            difficulty: scene.difficultySetting,
            options: .init(
                validateOnMove: true,
                enableNudges: true,
                enableHints: true,
                nudgeCooldown: TangramValidationEngine.ValidationOptions.default.nudgeCooldown,
                dwellValidateInterval: 0.0,
                orientationToleranceDeg: TangramValidationEngine.ValidationOptions.default.orientationToleranceDeg,
                rotationNudgeUpperDeg: TangramValidationEngine.ValidationOptions.default.rotationNudgeUpperDeg
            )
        )
        
        // Apply results back to scene
        applyValidationResults(result, to: scene, focusPiece: piece)
    }
    
    /// Process validation for all pieces (batch validation)
    func validateAllPieces() {
        guard let scene = scene,
              let puzzle = scene.puzzle else { return }
        
        // Gate batch validation until a user interaction has occurred
        guard hasUserIntent else { return }

        // Throttle validation and only run if pieces changed significantly
        let now = CACurrentMediaTime()
        if now - lastValidationTime < validationThrottle { return }
        
        // Create observations from all pieces (engine will perform significance gating)
        let observations = createObservations(from: scene)
        lastValidationTime = now
        
        // Process through validation engine
        let result = validationEngine.process(
            frame: observations,
            puzzle: puzzle,
            difficulty: scene.difficultySetting,
            options: .default
        )
        
        // Apply results to all pieces
        applyValidationResults(result, to: scene, focusPiece: nil)
    }
    
    /// Request a hint
    func requestHint(lastMovedPiece: TangramPieceType? = nil) -> TangramHintEngine.HintData? {
        guard let scene = scene,
              scene.puzzle != nil else { return nil }
        
        // Build hint context
        let placedPieces = scene.availablePieces.compactMap { piece -> PlacedPiece? in
            guard let pieceType = piece.pieceType else { return nil }
            
            // Convert to scene coordinates
            let scenePos = scene.physicalWorldSection.convert(piece.position, to: scene)
            
                // Create PlacedPiece without puzzle parameter
                var placed = PlacedPiece(
                pieceType: pieceType,
                position: scenePos,
                    rotation: Double(piece.zRotation) * 180 / Double.pi,
                isFlipped: piece.isFlipped
            )
            
            // Set validation state from scene state
            if let pieceId = piece.name,
                let state = scene.pieceStates[pieceId] {
                // Check if state is validated
                if case .validated = state.state {
                    placed.validationState = .correct
                } else {
                    placed.validationState = .incorrect
                }
            }
            
            return placed
        }
        
        let context = TangramValidationEngine.HintContext(
            validatedTargets: scene.validatedTargets,
            placedPieces: placedPieces,
            lastMovedPiece: lastMovedPiece,
            timeSinceLastProgress: CACurrentMediaTime() - (scene.userData?["lastProgressTime"] as? TimeInterval ?? 0),
            previousHints: scene.userData?["previousHints"] as? [TangramHintEngine.HintData] ?? []
        )
        
        let hint = validationEngine.requestHint(puzzle: scene.puzzle!, context: context)
        if let hint = hint {
            scene.showStructuredHint(hint)
        }
        return hint
    }
    
    // MARK: - Private Helpers
    
    private func createObservations(from scene: TangramPuzzleScene) -> [TangramValidationEngine.PieceObservation] {
        return scene.availablePieces.compactMap { piece in
            guard let pieceType = piece.pieceType,
                  let pieceId = piece.name else { return nil }
            
            // Convert position to scene coordinates
            let scenePos = scene.physicalWorldSection.convert(piece.position, to: scene)
            
            return TangramValidationEngine.PieceObservation(
                pieceId: pieceId,
                pieceType: pieceType,
                position: scenePos,
                rotation: piece.zRotation,
                isFlipped: piece.isFlipped,
                velocity: piece.physicsBody?.velocity ?? .zero,
                timestamp: CACurrentMediaTime()
            )
        }
    }
    
    private func applyValidationResults(
        _ result: TangramValidationEngine.ValidationResult,
        to scene: TangramPuzzleScene,
        focusPiece: PuzzlePieceNode?
    ) {
        // Update validated targets
        if scene.validatedTargets != result.validatedTargets {
            scene.validatedTargets = result.validatedTargets
            scene.onValidatedTargetsChanged?(result.validatedTargets)
        }
        
        // Update piece states and emit events
        for (pieceId, validationState) in result.pieceStates {
            guard let piece = scene.availablePieces.first(where: { $0.name == pieceId }) else { continue }
            
            // Get current state
            let previousState = scene.pieceStates[pieceId]
            let wasValid: Bool = {
                guard let st = previousState?.state else { return false }
                if case .validated = st { return true }
                return false
            }()
            
            // Update piece state
            var pieceState = scene.pieceStates[pieceId] ?? PieceState(pieceId: pieceId, pieceType: piece.pieceType ?? .square)
            
            if validationState.isValid {
                pieceState.markAsValidated(connections: [])
                
                // Bind piece to target
                if let targetId = validationState.targetId {
                    piece.userData?["assignedTargetId"] = targetId
                    
                    // Call scene's validation completion handler
                    scene.completeValidation(piece: piece, targetId: targetId, state: pieceState)
                    
                    // Emit validation changed event
                    if !wasValid {
                        scene.eventBus.emit(.validationChanged(pieceId: targetId, isValid: true))
                    }
                }
            } else {
                pieceState.markAsInvalid(reason: ValidationFailure.wrongPiece)
                scene.pieceStates[pieceId] = pieceState
                piece.pieceState = pieceState
                piece.updateStateIndicator()
                
                // Show failure reason if this is the focus piece
                if piece == focusPiece,
                   let failure = result.failureReasons[pieceId] {
                    scene.handleValidationFailure(piece: piece, failure: failure)
                }
                
                // Emit validation changed event
                if wasValid {
                    if let targetId = piece.userData?["assignedTargetId"] as? String {
                        scene.eventBus.emit(.validationChanged(pieceId: targetId, isValid: false))
                    }
                }
            }
        }
        
        // Orientation-only fills for targets — keep the code but comment out actual use for later step
        // for oid in result.orientedTargets {
        //     if let node = scene.targetSilhouettes[oid],
        //        let rawType = node.userData?["pieceType"] as? String,
        //        let type = TangramPieceType(rawValue: rawType) {
        //         scene.applyOrientedFill(to: node, for: type)
        //     }
        // }

        // Show immediate "Good job" when orientation-only correct; buffer rotate/flip/directed until settled
        let now = CACurrentMediaTime()
        for (pieceId, content) in result.pieceNudges {
            if content.level == .gentle {
                if let last = lastPieceNudgeShownAt[pieceId], (now - last) < pieceNudgeCooldown { continue }
                // De-duplicate by orientation signature
                if let piece = scene.availablePieces.first(where: { $0.name == pieceId }) {
                    let deg = Int((piece.zRotation * 180 / .pi).rounded())
                    let sig = (deg: deg, flip: piece.isFlipped)
                    if let lastSig = lastOrientationSignature[pieceId], lastSig.deg == sig.deg && lastSig.flip == sig.flip {
                        continue
                    }
                    lastOrientationSignature[pieceId] = sig
                }
                scene.showTopNudgeNearMirror(pieceId: pieceId, content: content)
                lastPieceNudgeShownAt[pieceId] = now
            } else {
                pendingPieceNudges[pieceId] = content
            }
        }
        // Flush buffered nudges only for settled pieces
        for (pieceId, content) in pendingPieceNudges {
            guard scene.isPieceSettled(pieceId, now: now) else { continue }
            if let last = lastPieceNudgeShownAt[pieceId], (now - last) < pieceNudgeCooldown { continue }
            scene.showTopNudgeNearMirror(pieceId: pieceId, content: content)
            lastPieceNudgeShownAt[pieceId] = now
            pendingPieceNudges.removeValue(forKey: pieceId)
        }
        
        // Update group mappings
        for (groupId, mapping) in result.groupMappings {
            // Store mapping for future use
            scene.userData?["groupMapping_\(groupId)"] = mapping
        }
        
        // Check for puzzle completion
        if result.validatedTargets.count == scene.puzzle?.targetPieces.count {
            scene.onPuzzleCompleted?()
        }
    }
}