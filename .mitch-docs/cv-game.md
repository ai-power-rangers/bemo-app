# CV Mock Game - Tangram System Architecture

## Overview

The Tangram CV Mock Game is a transitional implementation that simulates the future computer vision (CV) hardware integration while providing immediate gameplay functionality. The system uses a 4-section layout that bridges physical and digital worlds.

## Architecture Components

### 1. Four-Section Layout

```
┌─────────────────────────────────────────────┐
│                   TOP HALF                   │
│  ┌──────────────┐  ┌──────────────┐         │
│  │  Target      │  │  CV Render   │         │
│  │  (Top Left)  │  │  (Top Right) │         │
│  └──────────────┘  └──────────────┘         │
│                                              │
│                 BOTTOM HALF                  │
│  ┌────────────────────────────────────┐     │
│  │     Physical World Simulation      │     │
│  │     (Bottom - User Interaction)    │     │
│  └────────────────────────────────────┘     │
└─────────────────────────────────────────────┘
```

#### Top Left - Target Section
- Displays the target silhouette from database
- Shows what puzzle the student needs to complete
- Data source: `.mitch-docs/db-output-cat/cat-organized.json`
- Visual feedback for validated pieces

#### Top Right - CV Render Section  
- Real-time visualization of pieces as interpreted by CV
- Shows how the system "sees" the physical pieces
- Updates based on CV events from bottom section
- Will be the primary display when hardware CV is ready

#### Bottom Half - Physical World Simulation
- Mock physical tabletop area
- Drag, drop, rotate, flip pieces
- Emits CV events matching hardware format
- Will be removed when actual CV hardware is integrated

### 2. Event System

#### CV Event Format (Matching Hardware)
```json
{
  "homography": [[0.915, 0.406, 35.684], ...],
  "scale": 2.609,
  "objects": [
    {
      "name": "tangram_square",
      "class_id": 1,
      "pose": {
        "rotation_degrees": -167.576,
        "translation": [679.367, -359.136]
      },
      "vertices": [[706.695, -407.892], ...]
    }
  ]
}
```

#### Event Flow
1. User manipulates piece in Physical World Section
2. `PuzzlePieceNode` generates CV-format event
3. `CVEventBus` broadcasts event to subscribers
4. CV Render Section updates visualization
5. Target Section validates against puzzle solution

### 3. Smart Validation System

#### Construction-Based Validation Strategy
**Core Principle**: Validate based on construction intent, not just movement. Users need space to organize, explore, and build progressively.

##### Natural Workflow Zones
```
[Organization Zone] → [Working Space] → [Construction Area]
   (Left 1/3)          (Middle 1/3)       (Right 1/3)
   - Dump pieces       - Try fits         - Active building
   - Sort by type      - Test angles      - Final placement
   - Never validate     - Soft validate    - Full validate
```

##### Construction Group Detection
```swift
struct ConstructionGroup {
    var pieces: Set<String>           // Piece IDs in group
    var anchorPiece: String          // First piece (reference frame)
    var confidence: Float            // Construction intent (0-1)
    var lastActivity: Date           // For timeout/decay
    var validatedConnections: Set<(String, String)>
}

// Group Formation Criteria
let PROXIMITY_THRESHOLD: CGFloat = 100  // pixels between edges
let GROUP_TIMEOUT: TimeInterval = 30    // seconds of inactivity
```

##### Progressive Validation States
```
SCATTERED (Initial, pieces spread out)
    ↓ (2 pieces within proximity)
EXPLORING (Track patterns, no validation)
    ↓ (3rd piece OR valid connection)
CONSTRUCTING (Soft hints, validate after attempts)
    ↓ (4+ pieces OR 2+ valid connections)
BUILDING (Active validation with nudges)
    ↓ (>60% correctly placed)
COMPLETING (Aggressive help, auto-snap available)
```

##### Intent Detection Signals

**Spatial Signals**
- Edge proximity: < 100px between piece edges
- Angle alignment: Edges within 15° of valid angles
- Cluster density: 3+ pieces in 200px radius

**Temporal Signals**
- Rapid placement: < 5 seconds between pieces
- Stability duration: Stationary for 2+ seconds
- Focus time: 30+ seconds in same area

**Behavioral Signals**
- Fine adjustments: Small rotations < 5°
- Repeated attempts: Moving piece back after displacement
- Progressive construction: Valid connections increasing

##### Confidence Scoring
```swift
func calculateConfidence(group: ConstructionGroup) -> Float {
    let proximityScore = calculateProximity(group.pieces)    // 0-1
    let angleScore = calculateAngleAlignment(group.pieces)    // 0-1
    let temporalScore = calculateTemporalCohesion(group)      // 0-1
    let clusterScore = Float(group.pieces.count) / 7.0        // 0-1
    
    return proximityScore * 0.3 +
           angleScore * 0.2 +
           temporalScore * 0.2 +
           clusterScore * 0.3
}

// Validation Thresholds
if confidence > 0.7: validate immediately
if confidence > 0.5: validate after 2 seconds
if confidence < 0.5: observe only
```

#### Validation Principles

1. **First Piece is Always Right**
   - Defines coordinate system
   - Never validated alone
   - Becomes group anchor

2. **Proximity-Triggered Validation**
   - Scattered pieces ignored
   - Only validate construction groups
   - Organization zones never validated

3. **Progressive Strictness**
   ```
   2 pieces:  No feedback, establish baseline
   3 pieces:  Visual hints only (colors/opacity)
   4+ pieces: Nudges after failed attempts
   Majority:  Immediate feedback
   ```

4. **Zone-Based Behavior**
   - Left zone: Organization only
   - Middle zone: Exploration with soft validation
   - Right zone: Active construction with full validation

#### Smart Nudge System

##### Nudge Timing Strategy
**Never Nudge On:**
- First piece placement (it's the anchor!)
- Pieces in organization zone (left 1/3)
- First 5 seconds after any placement
- When confidence < 0.5 (just exploring)
- Pieces > 150px from any other piece

**Smart Nudge When:**
- 3+ attempts at same connection
- Piece placed in construction group (confidence > 0.7)
- After stability timeout (2 seconds stationary)
- User explicitly requests hint (button press)

##### Progressive Nudge Types
```swift
enum NudgeLevel {
    case none           // Silent observation
    case visual         // Color/opacity change only
    case gentle         // "Try rotating" (generic)
    case specific       // "Flip this piece" (specific)
    case directed       // Arrow showing direction
    case solution       // Show exact placement
}

// Nudge progression by validation state
EXPLORING:     .none
CONSTRUCTING:  .visual → .gentle (after 3 attempts)
BUILDING:      .gentle → .specific → .directed
COMPLETING:    .specific → .directed → .solution
```

##### Nudge Cooldown System
```swift
struct NudgeHistory {
    var lastNudgeTime: Date?
    var nudgeCount: Int = 0
    var attemptsSinceNudge: Int = 0
    
    func shouldNudge() -> Bool {
        guard let last = lastNudgeTime else { return true }
        let cooldown = TimeInterval(5 * nudgeCount)  // Progressive cooldown
        return Date().timeIntervalSince(last) > cooldown
    }
}
```

### 4. Data Models

#### Puzzle Data Structure (from Database)
```json
{
  "id": "puzzle_26D26F42",
  "name": "Cat",
  "category": "Animals",
  "difficulty": 4,
  "pieces": [
    {
      "id": "8AFBCDB8",
      "type": "square",
      "transform": {
        "a": 0.707, "b": 0.707,
        "c": -0.707, "d": 0.707,
        "tx": 133.112, "ty": 206.300
      }
    }
  ],
  "connections": [
    {
      "type": { "edgeToEdge": {...} },
      "constraint": { "type": {...} }
    }
  ]
}
```

#### Piece Types
- `largeTriangle1`, `largeTriangle2` 
- `mediumTriangle`
- `smallTriangle1`, `smallTriangle2`
- `square`
- `parallelogram`

### 5. Key Classes

#### Core Components
- `TangramPuzzleScene`: SpriteKit scene managing 4 sections
- `PuzzlePieceNode`: Interactive piece with physics
- `CVEventBus`: Event broadcasting system
- `TangramPieceValidator`: Validation logic
- `TangramGameViewModel`: Game state management

#### Event Types
- `CVFrameEvent`: Complete frame with all pieces
- `CVPieceEvent`: Individual piece state
- `TangramCVEvent`: Internal simplified events

### 6. User Interactions

#### Physical World Section (Bottom)
- **Drag**: Move pieces around tabletop (triggers MOVED state)
- **Tap & Hold**: Show rotation dial
- **Double Tap**: Flip piece
- **Release**: Piece enters PLACED state, validation begins

#### Generated CV Events
- `pieceDetected`: First time CV sees piece (establish baseline)
- `pieceMoved`: Position/rotation changed beyond threshold
- `pieceFlipped`: Piece flipped
- `pieceLifted`: Piece picked up (MOVED state)
- `piecePlaced`: Piece set down (PLACED state)
- `validationChanged`: Validation result updated

#### State-Based Behavior
- **DETECTED pieces**: No validation, just tracking
- **MOVED pieces**: Visual feedback showing activity
- **PLACED pieces**: Begin validation after placement timeout
- **VALIDATED pieces**: Show success feedback, become reference for others
- **INVALID pieces**: Show nudges (rotation, flip, position hints)

### 7. Hint System

#### Nudge System (Automatic)
Triggered after piece placement when validation fails:
- **Rotation Nudge**: "Try rotating" - piece in right area, wrong angle
- **Flip Nudge**: "Try flipping" - correct position but needs flip
- **Position Nudge**: Arrow showing direction - close but not aligned
- **Wrong Piece Nudge**: "Try a different piece" - after multiple attempts

#### Hint Types (Manual Request)
- **Placement Hints**: Where to place next piece
- **Rotation Hints**: Correct orientation for selected piece
- **Connection Hints**: Which pieces connect to validated pieces
- **Sequence Hints**: Suggested order of placement

#### Hint Triggers
- **Automatic Nudges**: Immediately after invalid placement
- **Progressive Hints**: No progress for 30+ seconds
- **Multiple Failed Attempts**: Same piece tried 3+ times
- **Manual Request**: Student asks for help

### 8. Metrics & Analytics

#### Tracked Data
- Completion time per puzzle
- Hints used count
- Piece manipulation patterns
- Validation attempts
- Success/failure rates

#### Database Tables
- `game_sessions`: Session tracking
- `learning_events`: Individual events
- `puzzle_completions`: Completion records
- `hint_usage`: Hint analytics

## Transition Plan

### Current State (Mock CV)
1. Bottom section simulates physical world
2. Manual drag/drop generates CV events
3. Top sections respond to mock events

### Future State (Real CV)
1. Remove bottom section entirely
2. Real CV hardware sends events
3. Top sections become full interface
4. iPad-only display for students

## Technical Considerations

### Coordinate Systems
- CV uses pixel coordinates
- SpriteKit uses scene coordinates
- Transform matrices handle conversion
- Relative positioning for validation

### Movement Detection
**Real CV Considerations:**
- Table vibrations filtered by movement threshold
- Lighting changes don't affect position tracking
- Hand occlusion handled by last-known-good position
- Multiple pieces moving simultaneously tracked

**Mock Game Mapping:**
- Touch events map directly to state transitions
- Drag = MOVED, Release = PLACED
- Simulates real CV timing delays

### Performance
- Event batching at 30 FPS
- Efficient scene node updates
- Minimal validation calculations
- Smooth animation transitions

### Error Handling
- Invalid piece positions
- Missing puzzle data
- CV event parsing errors
- Network connectivity issues

## File Structure

```
Tangram/
├── Events/
│   ├── CVEvent.swift         # Event definitions
│   └── CVEventBus.swift      # Event broadcasting
├── Views/
│   ├── TangramPuzzleScene.swift  # Main 4-section scene
│   ├── TangramSpriteView.swift   # SwiftUI wrapper
│   └── Components/
│       └── PuzzlePieceNode.swift # Interactive pieces
├── Services/
│   ├── TangramPieceValidator.swift   # Validation logic
│   └── TangramGameplayService.swift  # Game mechanics
└── Models/
    ├── GamePuzzleData.swift      # Puzzle structure
    └── PlacedPiece.swift         # Piece state
```

## Usage Flow

1. **Puzzle Selection**
   - Load puzzle from database
   - Parse target configuration
   - Initialize scene sections

2. **Gameplay**
   - Pieces appear in physical section
   - User manipulates pieces
   - CV events generated
   - Real-time validation
   - Visual feedback

3. **Completion**
   - All pieces validated
   - Metrics recorded
   - XP awarded
   - Next puzzle option

## Development Guidelines

### Adding New Features
1. Maintain CV event format compatibility
2. Test with multiple puzzle configurations
3. Ensure smooth transition to real CV
4. Keep sections independent

### Testing
- Mock various CV hardware responses
- Test edge cases (pieces off-screen, etc.)
- Validate against all puzzle types
- Performance testing with many pieces

### Debugging
- CV event logging in debug mode
- Visual debugging overlays
- Validation state indicators
- Frame rate monitoring

## Future Enhancements

### Phase 1 (Current)
- Complete mock CV implementation
- Full puzzle library integration
- Comprehensive hint system
- Analytics tracking

### Phase 2 (Hardware Integration)
- CV hardware connection
- Remove physical simulation
- Optimize for iPad-only display
- Advanced pattern recognition

### Phase 3 (Advanced Features)
- Multi-player support
- Custom puzzle creation
- AI-powered hints
- Adaptive difficulty