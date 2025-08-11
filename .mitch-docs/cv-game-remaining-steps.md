# CV Mock Game - Remaining Implementation Steps

## 🔴 IMMEDIATE NEXT STEPS - Movement-Based Validation

### Step 1: Create PieceState Model
**File**: `Models/PieceState.swift` (NEW)
```swift
enum DetectionState {
    case unobserved
    case detected(baseline: CGPoint, rotation: CGFloat)
    case moved
    case placed(at: Date)
    case validating
    case validated
    case invalid(reason: ValidationFailure)
}

struct PieceState {
    let pieceId: String
    var state: DetectionState = .unobserved
    var currentPosition: CGPoint
    var currentRotation: CGFloat
    var lastMovedTime: Date?
    var interactionCount: Int = 0
    var isAnchor: Bool = false
    var validatedConnections: Set<String> = []
}
```

### Step 2: Update PuzzlePieceNode
**File**: `PuzzlePieceNode.swift`
- Add `pieceState: PieceState` property
- Update state on drag start (MOVED)
- Update state on drag end (PLACED)
- Track interaction count

### Step 3: Implement Movement Detection
**File**: `TangramPuzzleScene.swift`
- Track all piece states in dictionary
- On first detection: establish baseline
- On touch/drag: check movement threshold
- On release: start placement timer
- After 1 second: transition to VALIDATING

### Step 4: Update Validation Logic
**File**: `TangramPieceValidator.swift`
- Only validate PLACED/VALIDATING pieces
- Skip DETECTED pieces entirely
- First MOVED piece = anchor
- Build validation network incrementally

### Step 5: Visual State Indicators
**File**: `TangramPuzzleScene.swift`
- DETECTED: 50% opacity
- MOVED: 100% opacity + glow
- PLACED: Stable display
- VALIDATING: Pulse animation
- VALIDATED: Green checkmark overlay
- INVALID: Red X + nudge arrow

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

## Implementation Order

### Phase 1: Foundation (Week 1) ✅ MOSTLY COMPLETE
1. Fix 4-section layout (1.1) ✅
2. Implement CV event generation (1.2) ✅
3. CV render section (2.1) ✅
4. Movement-based state system (1.3) - 🔴 NEXT PRIORITY
5. Movement-based validation (3.1) - AFTER STATES

### Phase 2: Core Gameplay (Week 2)
1. State-based CV rendering (2.5) - NEW
2. Movement-based validation (3.1)
3. Connection validation (3.2)
4. Database integration (4.1, 4.2)
5. Target section display (5.1)
6. Automatic nudge system (6.1) - NEW

### Phase 3: Polish (Week 3)
1. Visual feedback (3.3)
2. Hint system (6.1, 6.2)
3. Progress visualization (5.2)
4. UI/UX improvements (8.1, 8.2)

### Phase 4: Analytics & Testing (Week 4)
1. Metrics tracking (7.1, 7.2)
2. Testing infrastructure (9.1, 9.2, 9.3)
3. Performance optimization (10.1, 10.2)
4. Bug fixes and refinement

## Critical Path Items

These must be completed for basic functionality:

1. **4-Section Layout** ✅ - COMPLETED
2. **CV Event Generation** ✅ - COMPLETED
3. **Basic CV Render** ✅ - COMPLETED
4. **Movement-Based State System** - 🔴 NEXT CRITICAL
5. **Movement-Based Validation** - REQUIRED FOR GAMEPLAY
6. **Physical World Interactions** - IN PROGRESS (drag works, need rotation/flip)
7. **Database Puzzle Loading** - WORKING (puzzles load)
8. **Automatic Nudge System** - IMPROVES UX SIGNIFICANTLY

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

## Final Deliverables

1. Working 4-section mock CV game
2. Complete event pipeline
3. Full validation system
4. Integrated hint system
5. Analytics tracking
6. Test suite
7. Documentation
8. Migration plan to real CV