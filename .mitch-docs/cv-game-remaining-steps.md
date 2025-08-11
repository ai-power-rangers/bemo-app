# CV Mock Game - Remaining Implementation Steps

## 🔴 CRITICAL: Smart Validation System Implementation

### Phase 1: Construction Group System
**Priority: IMMEDIATE - This fundamentally changes how validation works**

#### Step 1.1: Create Construction Group Model
**File**: `Models/ConstructionGroup.swift` (NEW)
```swift
struct ConstructionGroup {
    let id: UUID = UUID()
    var pieces: Set<String>                    // Piece IDs in group
    var anchorPiece: String                    // First piece (reference)
    var confidence: Float = 0                  // Construction intent (0-1)
    var lastActivity: Date = Date()            // For timeout/decay
    var validatedConnections: Set<(String, String)> = []
    var validationState: ValidationState = .exploring
    var attemptHistory: [String: Int] = [:]    // Attempts per piece
    var nudgeHistory: NudgeHistory = NudgeHistory()
}

enum ValidationState {
    case scattered      // Pieces spread out
    case exploring      // 2 pieces, no validation
    case constructing   // 3+ pieces, soft validation
    case building       // 4+ pieces, active validation
    case completing     // >60% done, aggressive help
}

struct NudgeHistory {
    var lastNudgeTime: Date?
    var nudgeCount: Int = 0
    var attemptsSinceNudge: Int = 0
    var cooldownMultiplier: Int = 1
}
```

#### Step 1.2: Implement Proximity Detection
**File**: `Services/ConstructionGroupManager.swift` (NEW)
```swift
class ConstructionGroupManager {
    private var groups: [UUID: ConstructionGroup] = [:]
    private let proximityThreshold: CGFloat = 100
    private let angleThreshold: CGFloat = 0.26  // ~15 degrees
    
    func updateGroups(with pieces: [PuzzlePieceNode]) -> [ConstructionGroup]
    func calculateConfidence(for group: ConstructionGroup) -> Float
    func mergeGroups(_ group1: UUID, _ group2: UUID)
    func shouldValidate(group: ConstructionGroup) -> Bool
    func determineNudgeLevel(for group: ConstructionGroup) -> NudgeLevel
}
```

#### Step 1.3: Zone-Based Validation
**File**: `TangramPuzzleScene+Zones.swift` (NEW)
```swift
extension TangramPuzzleScene {
    enum Zone {
        case organization   // Left 1/3 - never validate
        case working       // Middle 1/3 - soft validate
        case construction  // Right 1/3 - full validate
    }
    
    func determineZone(for position: CGPoint) -> Zone
    func validationIntensity(for zone: Zone) -> Float
    func shouldValidateInZone(_ zone: Zone, confidence: Float) -> Bool
}
```

### Phase 2: Intent Detection System

#### Step 2.1: Spatial Signal Detection
**File**: `Services/IntentDetector.swift` (NEW)
```swift
struct SpatialSignals {
    var edgeProximity: Float      // 0-1, how close edges are
    var angleAlignment: Float      // 0-1, how aligned to valid angles
    var clusterDensity: Float      // 0-1, pieces per area
    var centerOfMass: CGPoint      // Group center
}

struct TemporalSignals {
    var placementSpeed: Float      // Time between placements
    var stabilityDuration: Float   // How long stationary
    var focusTime: Float          // Time in same area
    var activityRecency: Float     // Time since last action
}

struct BehavioralSignals {
    var fineAdjustments: Int       // Small rotation count
    var repeatAttempts: Int        // Times piece moved back
    var validConnections: Int      // Successful connections
    var progressionRate: Float     // Valid/total ratio
}
```

#### Step 2.2: Confidence Calculator
**File**: `Services/ConfidenceCalculator.swift` (NEW)
```swift
class ConfidenceCalculator {
    func calculate(spatial: SpatialSignals,
                  temporal: TemporalSignals,
                  behavioral: BehavioralSignals) -> Float {
        
        let spatialScore = spatial.edgeProximity * 0.4 +
                          spatial.angleAlignment * 0.4 +
                          spatial.clusterDensity * 0.2
        
        let temporalScore = temporal.stabilityDuration * 0.5 +
                           temporal.focusTime * 0.3 +
                           temporal.activityRecency * 0.2
        
        let behavioralScore = Float(behavioral.validConnections) * 0.5 +
                             behavioral.progressionRate * 0.5
        
        return spatialScore * 0.3 +
               temporalScore * 0.2 +
               behavioralScore * 0.5
    }
}
```

### Phase 3: Progressive Nudge System

#### Step 3.1: Smart Nudge Manager
**File**: `Services/SmartNudgeManager.swift` (NEW)
```swift
class SmartNudgeManager {
    private var nudgeHistories: [String: NudgeHistory] = [:]
    
    func shouldShowNudge(for piece: PuzzlePieceNode,
                         in group: ConstructionGroup,
                         zone: Zone) -> Bool
    
    func determineNudgeLevel(confidence: Float,
                            attempts: Int,
                            state: ValidationState) -> NudgeLevel
    
    func generateNudge(level: NudgeLevel,
                      failure: ValidationFailure) -> NudgeContent
    
    func applyProgressiveCooldown(history: NudgeHistory) -> TimeInterval
}
```

#### Step 3.2: Visual Nudge Improvements
**File**: `TangramPuzzleScene+Nudges.swift` (UPDATE)
```swift
extension TangramPuzzleScene {
    func showSmartNudge(for piece: PuzzlePieceNode,
                       level: NudgeLevel,
                       content: NudgeContent) {
        switch level {
        case .none:
            return
        case .visual:
            // Subtle color/opacity change only
        case .gentle:
            // Generic text hint
        case .specific:
            // Specific action needed
        case .directed:
            // Arrow showing direction
        case .solution:
            // Ghost piece showing exact placement
        }
    }
}
```

## Priority 1: Core CV Mock Infrastructure ✅ MOSTLY COMPLETE

### 1.1 Complete 4-Section Layout ✅ COMPLETED
**File**: `TangramPuzzleScene.swift`
- [x] Fix section positioning and bounds calculations
- [x] Implement proper safe area handling for all devices
- [x] Add section divider lines/borders for clarity (color-coded)
- [x] Ensure responsive layout for different iPad sizes
- [x] Remove section labels (cleaner look)
- [x] Fix navbar overlap issues
- [x] Consistent scaling across all sections

### 1.2 CV Event Generation System ✅ COMPLETED
**Files**: `PuzzlePieceNode.swift`, `CVEventBus.swift`, `TangramPuzzleScene.swift`
- [x] Generate proper CV format events on piece manipulation
- [x] Implement threshold-based event emission (reduces jitter)
- [x] Add homography matrix calculations (default values)
- [x] Convert SpriteKit coordinates to CV pixel coordinates
- [x] Include proper vertices calculation for each piece
- [x] Add class_id mapping for piece types
- [x] Emit CV frames only when pieces actually move

### 1.3 Movement-Based State System 🆕 NEW PRIORITY
**Files**: `PlacedPiece.swift`, `TangramPuzzleScene.swift`
- [ ] Implement PieceState struct with detection states
- [ ] Add baseline position/rotation tracking
- [ ] Implement movement detection with thresholds
- [ ] Add placement timer (1 second for PLACED state)
- [ ] Create state transition logic
- [ ] Track interaction count per piece
- [ ] Implement state visualization (debug mode)

### 1.4 Physical World Section (Bottom)
**File**: `TangramPuzzleScene.swift`
- [x] Piece spawning in organized positions
- [x] Basic drag functionality
- [ ] Fix rotation gesture (tap & hold for dial)
- [ ] Add flip gesture (double tap)
- [ ] Create piece "pickup" animation
- [ ] Add drop shadow when piece is lifted
- [ ] Implement boundary constraints (keep pieces in section)

## Priority 2: CV Render Section Implementation

### 2.1 Real-time CV Visualization ✅ COMPLETED
**File**: `TangramPuzzleScene.swift` (updateCVRender method)
- [x] Parse incoming CV events
- [x] Create/update piece visualizations
- [x] Apply CV transforms to visual pieces (stable, no jitter)
- [x] Remove old pieces not in frame
- [x] Implement smooth position updates
- [ ] Show piece confidence levels (optional)
- [ ] Add motion trails for moving pieces (optional)

### 2.2 CV Piece Representation
**New File**: `CVPieceVisualization.swift`
- [ ] Create lightweight piece representations
- [ ] Apply CV pose data (rotation, translation)
- [ ] Show vertices as debug overlay (optional)
- [ ] Color-code by validation state
- [ ] Add confidence indicators

## Priority 2.5: State-Based CV Rendering 🆕 NEW

### 2.5.1 State Visualization in CV Section
**File**: `TangramPuzzleScene.swift`
- [ ] Show piece states with visual indicators
- [ ] DETECTED: Semi-transparent
- [ ] MOVED: Full opacity with highlight
- [ ] PLACED: Stable display
- [ ] VALIDATING: Pulsing effect
- [ ] VALIDATED: Green checkmark
- [ ] INVALID: Red X with nudge arrow

### 2.5.2 Baseline Tracking
- [ ] Store initial positions when pieces first detected
- [ ] Show baseline ghost in debug mode
- [ ] Track movement deltas from baseline
- [ ] Reset baseline on significant moves

## Priority 3: Validation System

### 3.1 Movement-Based Validation ⚠️ CRITICAL
**File**: `TangramPieceValidator.swift`
- [ ] Only validate pieces in PLACED state
- [ ] First MOVED piece becomes anchor (not first detected)
- [ ] Calculate relative positions to anchor and validated pieces
- [ ] Handle anchor piece removal/promotion
- [ ] Support arbitrary puzzle positioning
- [ ] Add tolerance thresholds for validation
- [ ] Skip validation for DETECTED (unmoved) pieces
- [ ] Implement validation cascade (growing network)

### 3.2 Connection Validation
**File**: `TangramPieceValidator.swift`
- [ ] Parse database connection constraints
- [ ] Validate edge-to-edge connections
- [ ] Validate vertex-to-vertex connections
- [ ] Handle rotation constraints
- [ ] Support translation ranges

### 3.3 Visual Feedback & Nudges
**File**: `TangramPuzzleScene.swift`
- [ ] Highlight valid placements in target section
- [ ] Show connection indicators
- [ ] Add success animations
- [ ] Implement automatic nudges after invalid placement:
  - [ ] Rotation nudge (circular arrow)
  - [ ] Flip nudge (flip icon)
  - [ ] Position nudge (directional arrow)
  - [ ] Wrong piece nudge (try different piece)
- [ ] Create completion celebration
- [ ] Show validation only for PLACED pieces

## Priority 4: Database Integration

### 4.1 Puzzle Loading
**File**: `TangramDatabaseLoader.swift`
- [ ] Parse full puzzle format from database
- [ ] Extract piece transforms
- [ ] Process connection data
- [ ] Cache loaded puzzles
- [ ] Handle missing/corrupt data

### 4.2 Solution Validation
**New File**: `PuzzleSolutionValidator.swift`
- [ ] Compare against database solution
- [ ] Handle multiple valid solutions
- [ ] Support approximate matching
- [ ] Calculate completion percentage

## Priority 5: Target Section Enhancements

### 5.1 Silhouette Display
**File**: `TangramPuzzleScene.swift` (target section)
- [ ] Render puzzle silhouette from database
- [ ] Scale to fit section bounds
- [ ] Center within section
- [ ] Add subtle grid background
- [ ] Show puzzle name/difficulty

### 5.2 Progress Visualization
- [ ] Highlight completed pieces in silhouette
- [ ] Show outline for next suggested piece
- [ ] Add progress percentage
- [ ] Animate successful placements

## Priority 6: Hint System Integration

### 6.1 Automatic Nudge System 🆕 NEW
**File**: `TangramNudgeSystem.swift`
- [ ] Detect validation failure reasons
- [ ] Generate appropriate nudge type
- [ ] Display nudge for 3 seconds
- [ ] Track nudge effectiveness
- [ ] Escalate to hints after 3 failed attempts

### 6.2 Structured Hints
**File**: `TangramHintEngine.swift`
- [ ] Connect hints to CV sections
- [ ] Show hint in target section
- [ ] Highlight piece in physical section
- [ ] Add arrow/path indicators
- [ ] Implement hint animations
- [ ] Only suggest MOVED or VALIDATED pieces

### 6.2 Hint Types
- [ ] Placement hints (where to put piece)
- [ ] Rotation hints (correct angle)
- [ ] Connection hints (which pieces connect)
- [ ] Sequence hints (order of placement)

## Priority 7: Metrics & Analytics

### 7.1 Event Tracking
**File**: `TangramGameViewModel.swift`
- [ ] Track all CV events
- [ ] Log piece manipulations
- [ ] Record validation attempts
- [ ] Monitor hint usage
- [ ] Calculate efficiency metrics

### 7.2 Database Recording
- [ ] Store session data
- [ ] Record completion times
- [ ] Track learning patterns
- [ ] Generate progress reports

## Priority 8: UI/UX Polish

### 8.1 Visual Design
- [ ] Consistent color scheme across sections
- [ ] Smooth animations and transitions
- [ ] Clear visual hierarchy
- [ ] Accessibility support
- [ ] Dark mode compatibility

### 8.2 User Feedback
- [ ] Loading states
- [ ] Error messages
- [ ] Success celebrations
- [ ] Progress indicators
- [ ] Tutorial/onboarding

## Priority 9: Testing Infrastructure

### 9.1 CV Event Testing
**New File**: `CVEventTests.swift`
- [ ] Test event generation
- [ ] Validate event format
- [ ] Test coordinate transforms
- [ ] Verify frame batching

### 9.2 Validation Testing
**New File**: `ValidationTests.swift`
- [ ] Test all piece configurations
- [ ] Verify anchor logic
- [ ] Test edge cases
- [ ] Performance testing

### 9.3 Integration Testing
- [ ] End-to-end puzzle completion
- [ ] Multi-device testing
- [ ] Network failure handling
- [ ] Data persistence

## Priority 10: Performance Optimization

### 10.1 Rendering Optimization
- [ ] Implement node pooling
- [ ] Optimize texture atlases
- [ ] Reduce draw calls
- [ ] Implement LOD system

### 10.2 Event Processing
- [ ] Batch event updates
- [ ] Throttle validation checks
- [ ] Optimize coordinate transforms
- [ ] Cache validation results

## Implementation Order (REVISED)

### Phase 1: Smart Validation Foundation (IMMEDIATE - 2-3 days)
1. ✅ Fix piece spawning in organization zone (left side)
2. 🔴 Implement Construction Group system (Phase 1.1-1.3)
3. 🔴 Add zone-based validation logic
4. 🔴 Calculate confidence scores for groups
5. 🔴 Prevent validation of scattered pieces

### Phase 2: Intent Detection (Days 3-4)
1. 🔴 Implement spatial signal detection
2. 🔴 Add temporal signal tracking
3. 🔴 Build confidence calculator
4. 🔴 Create behavioral pattern recognition
5. 🔴 Test with various play patterns

### Phase 3: Progressive Nudges (Days 4-5)
1. 🔴 Smart nudge manager implementation
2. 🔴 Progressive nudge levels
3. 🔴 Cooldown system
4. 🔴 Zone-aware nudging
5. 🔴 Visual nudge improvements

### Phase 4: Testing & Refinement (Days 5-7)
1. Test with different puzzle difficulties
2. Tune confidence thresholds
3. Adjust zone boundaries
4. Refine nudge timing
5. Validate CV format compatibility

## Critical Success Factors

### Must Have (MVP)
1. ✅ **Piece Organization Zone** - Left side spawn area
2. 🔴 **Construction Groups** - Detect intent to build
3. 🔴 **Zone-Based Validation** - Don't validate organization area
4. 🔴 **Confidence Scoring** - Know when to validate
5. 🔴 **Progressive Nudging** - Help without annoying

### Should Have (Good UX)
1. **Intent Detection** - Understand user behavior
2. **Smart Nudge Timing** - Right help at right time
3. **Visual State Feedback** - Clear piece states
4. **Hint System Integration** - Manual help button
5. **Completion Celebration** - Reward success

### Nice to Have (Polish)
1. **Auto-snap** - For nearly correct pieces
2. **Ghost pieces** - Show solution hints
3. **Progress indicators** - % complete
4. **Difficulty adaptation** - Adjust based on performance
5. **Analytics tracking** - Learn from usage

## Known Issues to Address

1. **State Management**
   - Need to track piece states persistently
   - Handle state transitions cleanly
   - Visualize states for debugging

2. **Movement Detection**
   - Balance threshold sensitivity
   - Filter accidental bumps vs intentional moves
   - Handle multiple pieces moving simultaneously

3. **Piece Rotation**
   - Current rotation dial not working properly
   - Need smooth rotation with visual feedback

4. **Validation Timing**
   - 1 second placement delay might feel slow
   - Need to balance responsiveness vs stability

5. **Nudge System**
   - Determine optimal nudge display duration
   - Avoid overwhelming user with too many nudges
   - Track which nudges are most helpful

## Success Criteria

The CV mock game is complete when:

1. ✅ User can select and load puzzles
2. ✅ Physical world section allows full manipulation
3. ✅ CV events properly generated and formatted
4. ✅ CV render section shows real-time updates
5. ✅ Target section displays puzzle and progress
6. ✅ Validation works with anchor-based positioning
7. ✅ Hints provide helpful guidance
8. ✅ Completion triggers celebration and metrics
9. ✅ System ready for CV hardware swap
10. ✅ Performance smooth on all iPads

## Risk Mitigation

### Technical Risks
- **CV Format Changes**: Abstract event interface
- **Performance Issues**: Progressive enhancement
- **Validation Complexity**: Start simple, iterate

### Timeline Risks
- **Scope Creep**: Stick to MVP features
- **Testing Time**: Automate early
- **Hardware Delays**: Mock system fully functional

## Notes for Implementation

1. **Keep CV Mock Modular**: Easy to swap with real CV
2. **Document Event Formats**: Critical for integration
3. **Test with Real Data**: Use actual CV output samples
4. **Build Debug Tools**: Event viewer, validation overlay
5. **Plan for Transition**: Clear path to remove mock

## Dependencies

- SpriteKit for physics and rendering
- Combine for event streaming
- CoreData for offline puzzle storage
- Supabase for analytics
- SwiftUI for UI components

## Testing Checklist

- [ ] All 7 piece types work correctly
- [ ] 10+ puzzles load and complete
- [ ] Rotation works smoothly
- [ ] Flipping works correctly
- [ ] Anchor system handles all cases
- [ ] CV events match hardware format
- [ ] Performance > 30 FPS on iPad Air 2+
- [ ] Hints help without giving away solution
- [ ] Metrics properly tracked
- [ ] Graceful error handling

## Key Architecture Insights

### Why Construction Groups?
- **Natural Play Pattern**: Kids naturally cluster pieces when building
- **Intent Detection**: Groups show purposeful construction vs exploration
- **Scalable Validation**: Validate relationships, not absolute positions
- **CV Ready**: Real CV will detect same spatial patterns

### Why Zone-Based Validation?
- **Mimics Physical Table**: Left = pile, Middle = work, Right = build
- **Progressive Engagement**: Gentle introduction to validation
- **Reduces False Positives**: Organization isn't construction
- **User Control**: Players choose when to engage validation

### Why Confidence Scoring?
- **Adaptive System**: Responds to user behavior
- **Prevents Frustration**: Only helps when needed
- **Learning Curve**: System gets smarter over time
- **Data Driven**: Can tune based on analytics

## Migration to Real CV

### What Changes
1. Remove bottom physical world section
2. CV hardware sends real events
3. Calibration for table dimensions
4. Physical piece detection thresholds

### What Stays Same
1. Construction group detection
2. Zone-based validation logic  
3. Confidence scoring system
4. Progressive nudge strategy
5. All validation algorithms

The smart validation system is **hardware agnostic** - it works with mock or real CV events equally well!