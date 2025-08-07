# Tangram Hint System Design Document

## Overview

This document outlines the comprehensive plan for implementing an intelligent, structured hint system for the Tangram game. The system will provide contextual, progressive hints based on the current game state, user behavior, and piece complexity.

## Goals

1. **Intelligent Assistance**: Provide contextual hints based on player's current situation
2. **Progressive Disclosure**: Start with subtle hints, escalate to complete solutions
3. **Educational Value**: Help players learn strategies, not just solve puzzles
4. **Metrics Tracking**: Capture detailed analytics for learning insights
5. **Visual Clarity**: Use ghost pieces and animations to clearly show solutions

## Current State Analysis

### What Exists Now
- **Basic Toggle**: Binary on/off for showing all target silhouettes
- **Simple Tracking**: `hintsUsed` counter incremented on toggle
- **Visual**: Shows colored outlines when hints enabled
- **Database**: JSONB fields in `learning_events` and `game_sessions` tables

### Limitations
- No intelligence about which piece to hint
- No consideration of player's current struggle
- No progressive hint levels
- Limited metrics tracking
- No visual demonstration of transformations

## Proposed System Architecture

### 1. Service Layer: TangramHintEngine

**Location**: `Bemo/Features/Game/Games/Tangram/Services/TangramHintEngine.swift`

```swift
@MainActor
class TangramHintEngine {
    
    // MARK: - Types
    
    struct HintData {
        let targetPiece: TangramPieceType
        let currentTransform: CGAffineTransform?
        let targetTransform: CGAffineTransform
        let hintType: HintType
        let animationSteps: [AnimationStep]
        let difficulty: PieceDifficulty
        let reason: HintReason
    }
    
    enum HintType {
        case nudge              // Subtle: piece glows or pulses
        case rotation(degrees: Double)  // Show rotation needed
        case flip               // Show flip for parallelogram
        case position(from: CGPoint, to: CGPoint)  // Show drag path
        case fullSolution       // Complete demonstration
    }
    
    enum HintReason {
        case lastMovedIncorrectly
        case stuckTooLong(seconds: TimeInterval)
        case noRecentProgress
        case userRequested
        case firstPiece
    }
    
    enum PieceDifficulty {
        case easy       // Small triangles
        case medium     // Medium triangle, square
        case hard       // Large triangles
        case veryHard   // Parallelogram (can flip)
    }
    
    struct AnimationStep {
        let duration: TimeInterval
        let transform: CGAffineTransform
        let description: String
        let highlightType: HighlightType
    }
    
    enum HighlightType {
        case none
        case pulse
        case glow
        case arrow
    }
}
```

### 2. Hint Selection Algorithm

```swift
func determineNextHint(
    puzzle: GamePuzzleData,
    placedPieces: [PlacedPiece],
    lastMovedPiece: TangramPieceType?,
    timeSinceLastProgress: TimeInterval,
    previousHints: [HintData]
) -> HintData? {
    
    // Priority 1: Last moved piece was incorrect
    if let lastMoved = lastMovedPiece,
       let placed = placedPieces.first(where: { $0.pieceType == lastMoved }),
       placed.validationState != .correct {
        return createHintForIncorrectPiece(lastMoved, placed, puzzle)
    }
    
    // Priority 2: Player stuck for too long (>30 seconds)
    if timeSinceLastProgress > 30 {
        return createHintForStuckPlayer(puzzle, placedPieces)
    }
    
    // Priority 3: Find easiest unplaced piece
    let unplacedPieces = findUnplacedPieces(puzzle, placedPieces)
    if let easiestPiece = selectEasiestPiece(unplacedPieces) {
        return createHintForPiece(easiestPiece, puzzle)
    }
    
    return nil
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
```

### 3. Visual Implementation in SpriteKit

**Updates to**: `TangramPuzzleScene.swift`

```swift
class TangramPuzzleScene: SKScene {
    
    private var hintGhostNode: SKNode?
    private var hintPathNode: SKShapeNode?
    private var currentHintAnimation: SKAction?
    
    func showStructuredHint(_ hint: TangramHintEngine.HintData) {
        clearCurrentHint()
        
        switch hint.hintType {
        case .nudge:
            showNudgeHint(hint)
        case .rotation(let degrees):
            showRotationHint(hint, degrees: degrees)
        case .flip:
            showFlipHint(hint)
        case .position(let from, let to):
            showPositionHint(hint, from: from, to: to)
        case .fullSolution:
            showFullSolutionHint(hint)
        }
    }
    
    private func showRotationHint(_ hint: HintData, degrees: Double) {
        // Create ghost piece
        let ghost = createGhostPiece(for: hint.targetPiece)
        ghost.alpha = 0.3
        
        // Position at current location
        if let current = findPieceNode(hint.targetPiece) {
            ghost.position = current.position
            ghost.zRotation = current.zRotation
        }
        
        // Create rotation indicator arc
        let arc = createRotationArc(degrees: degrees)
        ghost.addChild(arc)
        
        // Animate rotation
        let rotate = SKAction.rotate(toAngle: CGFloat(degrees * .pi / 180), duration: 1.5)
        let fadeIn = SKAction.fadeAlpha(to: 0.5, duration: 0.3)
        let wait = SKAction.wait(forDuration: 0.5)
        let sequence = SKAction.sequence([fadeIn, wait, rotate])
        
        ghost.run(sequence)
        effectsLayer.addChild(ghost)
        hintGhostNode = ghost
    }
    
    private func showPositionHint(_ hint: HintData, from: CGPoint, to: CGPoint) {
        // Create ghost at target position
        let targetGhost = createGhostPiece(for: hint.targetPiece)
        targetGhost.position = to
        targetGhost.alpha = 0.4
        targetGhost.zPosition = 100
        
        // Apply target transform for correct rotation
        let targetRotation = atan2(hint.targetTransform.b, hint.targetTransform.a)
        targetGhost.zRotation = -targetRotation // Negative for coordinate system
        
        // Create animated path from current to target
        let path = UIBezierPath()
        path.move(to: from)
        
        // Create curved path for visual appeal
        let controlPoint = CGPoint(
            x: (from.x + to.x) / 2,
            y: max(from.y, to.y) + 50
        )
        path.addQuadCurve(to: to, controlPoint: controlPoint)
        
        let pathNode = SKShapeNode(path: path.cgPath)
        pathNode.strokeColor = .systemYellow
        pathNode.lineWidth = 2
        pathNode.lineCap = .round
        pathNode.alpha = 0
        pathNode.zPosition = 99
        
        // Animate path drawing
        let fadeInPath = SKAction.fadeIn(withDuration: 0.3)
        let dashAnimation = createDashAnimation(for: pathNode)
        
        pathNode.run(SKAction.sequence([fadeInPath, dashAnimation]))
        
        effectsLayer.addChild(targetGhost)
        effectsLayer.addChild(pathNode)
        
        hintGhostNode = targetGhost
        hintPathNode = pathNode
        
        // Pulse the target position
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ])
        targetGhost.run(SKAction.repeatForever(pulse))
    }
    
    private func showFullSolutionHint(_ hint: HintData) {
        // Complete animated sequence showing all transformations
        var actions: [SKAction] = []
        
        // Create piece at starting position
        let ghost = createGhostPiece(for: hint.targetPiece)
        ghost.alpha = 0
        
        // Build animation sequence from steps
        for (index, step) in hint.animationSteps.enumerated() {
            // Fade in on first step
            if index == 0 {
                actions.append(SKAction.fadeAlpha(to: 0.5, duration: 0.3))
            }
            
            // Create action for this step
            let stepAction = createStepAnimation(step, for: ghost)
            actions.append(stepAction)
            
            // Add pause between steps
            if index < hint.animationSteps.count - 1 {
                actions.append(SKAction.wait(forDuration: 0.3))
            }
        }
        
        // Add final pulse at target position
        actions.append(SKAction.repeatForever(
            SKAction.sequence([
                SKAction.fadeAlpha(to: 0.6, duration: 0.5),
                SKAction.fadeAlpha(to: 0.3, duration: 0.5)
            ])
        ))
        
        ghost.run(SKAction.sequence(actions))
        effectsLayer.addChild(ghost)
        hintGhostNode = ghost
    }
}
```

### 4. ViewModel Integration

**Updates to**: `TangramGameViewModel.swift`

```swift
@Observable
class TangramGameViewModel {
    // New properties
    var currentHint: TangramHintEngine.HintData?
    var hintHistory: [TangramHintEngine.HintData] = []
    var lastMovedPiece: TangramPieceType?
    var lastProgressTime = Date()
    private let hintEngine = TangramHintEngine()
    
    // Enhanced hint request
    func requestStructuredHint() {
        guard let puzzle = selectedPuzzle else { return }
        
        let timeSinceProgress = Date().timeIntervalSince(lastProgressTime)
        
        // Get intelligent hint
        currentHint = hintEngine.determineNextHint(
            puzzle: puzzle,
            placedPieces: placedPieces,
            lastMovedPiece: lastMovedPiece,
            timeSinceLastProgress: timeSinceProgress,
            previousHints: hintHistory
        )
        
        if let hint = currentHint {
            // Track hint
            hintHistory.append(hint)
            gameState?.incrementHintCount()
            
            // Log to database
            logHintEvent(hint)
            
            // Notify delegate
            delegate?.gameDidRequestHint()
        }
    }
    
    private func logHintEvent(_ hint: TangramHintEngine.HintData) {
        let eventData: [String: Any] = [
            "hint_type": String(describing: hint.hintType),
            "target_piece": hint.targetPiece.rawValue,
            "hint_reason": String(describing: hint.reason),
            "piece_difficulty": String(describing: hint.difficulty),
            "time_since_progress": Date().timeIntervalSince(lastProgressTime),
            "hints_before": hintHistory.count - 1,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Send to Supabase
        Task {
            await databaseService.logLearningEvent(
                childProfileId: currentChildId,
                eventType: "hint_requested",
                gameId: "tangram",
                eventData: eventData
            )
        }
    }
    
    // Track piece movements
    func onPieceMoved(_ pieceType: TangramPieceType) {
        lastMovedPiece = pieceType
    }
    
    // Track progress
    func onPieceCompleted(_ pieceType: TangramPieceType) {
        lastProgressTime = Date()
        lastMovedPiece = nil // Clear since it was successful
    }
}
```

### 5. Database Schema Updates

```sql
-- No schema changes needed, but documenting JSONB structure
-- learning_events.event_data for hint events:
{
  "hint_type": "rotation|flip|position|fullSolution|nudge",
  "target_piece": "largeTriangle1",
  "hint_reason": "lastMovedIncorrectly|stuckTooLong|noRecentProgress",
  "piece_difficulty": "easy|medium|hard|veryHard",
  "time_since_progress": 45.2,
  "hints_before": 2,
  "timestamp": 1691234567.89
}

-- game_sessions.session_data enhanced:
{
  "total_hints_used": 5,
  "hint_types_used": ["rotation", "position", "fullSolution"],
  "avg_time_between_hints": 22.3,
  "pieces_placed_after_hint": ["square", "parallelogram"],
  "completion_with_hints": true,
  "hint_effectiveness": 0.8  // % of hints that led to correct placement
}
```

## Hint Progression Strategy

### Level 1: Nudge (Subtle)
- Piece that needs attention glows or pulses
- No explicit solution shown
- Used when player is close but needs focus

### Level 2: Orientation (Rotation/Flip)
- Shows the correct orientation needed
- Ghost piece demonstrates rotation
- Flip animation for parallelogram

### Level 3: Position
- Shows target position with ghost piece
- Animated path from current to target
- Maintains current rotation if correct

### Level 4: Full Solution
- Complete step-by-step demonstration
- Shows rotation, flip (if needed), then position
- Each step clearly animated with pauses

## Metrics & Analytics

### Per-Hint Metrics
- Time to request hint
- Hint type and reason
- Success rate (did hint lead to correct placement?)
- Time from hint to successful placement

### Per-Session Metrics
- Total hints used
- Hint progression (did they need escalating hints?)
- Completion time with/without hints
- Learning curve (hints needed over multiple sessions)

### Analytics Insights
- Which pieces require most hints?
- At what time threshold do players need help?
- Do hints improve learning over time?
- Correlation between hint usage and retention

## Implementation Timeline

### Phase 1: Core Engine (Week 1)
- [ ] Create TangramHintEngine service
- [ ] Implement hint selection algorithm
- [ ] Add basic hint data structures

### Phase 2: Visual System (Week 1-2)
- [ ] Ghost piece rendering
- [ ] Animation system for hints
- [ ] Path visualization for position hints
- [ ] Rotation/flip indicators

### Phase 3: Integration (Week 2)
- [ ] ViewModel updates
- [ ] Scene integration
- [ ] Database logging
- [ ] UI button updates

### Phase 4: Testing & Tuning (Week 3)
- [ ] Tune timing thresholds
- [ ] Adjust difficulty rankings
- [ ] Test hint effectiveness
- [ ] Optimize animations

## Success Criteria

1. **Reduced Frustration**: Players don't abandon puzzles
2. **Learning Progress**: Fewer hints needed over time
3. **Appropriate Timing**: Hints appear when needed, not too early
4. **Clear Communication**: Visual hints are immediately understood
5. **Data Collection**: Rich analytics for learning insights

## Future Enhancements

1. **Adaptive Difficulty**: Adjust hint timing based on player skill
2. **Voice Guidance**: Audio hints for younger players
3. **Hint Preferences**: Parents can configure hint behavior
4. **Achievement System**: Rewards for completing without hints
5. **ML Integration**: Predict when hints needed based on patterns

## Technical Considerations

### Performance
- Animations use SKAction for smooth performance
- Ghost pieces reuse existing geometry
- Hint calculations cached when possible

### Accessibility
- Hints work with VoiceOver
- Visual hints have text alternatives
- Colorblind-friendly indicators

### Testing
- Unit tests for TangramHintEngine
- Integration tests for hint flow
- UI tests for animations
- A/B testing for effectiveness

## Conclusion

This hint system transforms the current binary on/off approach into an intelligent, progressive assistance system that adapts to player behavior and provides clear, animated guidance. It maintains the MVVM-S architecture while adding sophisticated hint capabilities that will improve player experience and provide valuable learning analytics.