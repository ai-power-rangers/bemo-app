# Tangram Puzzle Game - Comprehensive Implementation Plan

## Executive Summary

Building a Tangram puzzle game that uses computer vision to track physical tangram pieces on a tabletop, validating placements against target puzzles. The game will follow MVVM-S architecture, reuse components from TangramEditor, and provide progressive difficulty with hints and assistance.

## Core Requirements

### Functional Requirements
- Display target puzzle silhouettes with dark/off-black pieces
- Track physical piece placement via CV with coordinates/rotations
- Validate placements based on relative positions from anchor piece
- Dynamic anchor piece selection when primary piece is removed
- Configurable acceptance tolerances for real-world imperfection
- Hint system for stuck players
- Progress tracking and regression handling
- Game exit functionality
- Completion validation

### Technical Requirements
- iOS 17+ with @Observable
- MVVM-S architecture
- Modular design with separation of concerns
- Reuse TangramEditor components where applicable
- Mock CV data for development/testing
- Follow existing codebase conventions

## Architecture Overview

```
TangramPuzzleGame/
├── Game Implementation/
│   └── TangramPuzzleGame.swift (implements Game protocol)
├── ViewModels/
│   ├── TangramPuzzleViewModel.swift (@Observable, main game logic)
│   └── PuzzleSelectionViewModel.swift (puzzle browser)
├── Views/
│   ├── TangramPuzzleView.swift (main game view)
│   ├── PuzzleSelectionView.swift (puzzle selector)
│   ├── PuzzleCanvasView.swift (puzzle display area)
│   └── CVMockControlView.swift (CV testing controls)
├── Services/
│   ├── PuzzleGameService.swift (puzzle loading/management)
│   ├── PuzzleValidationService.swift (placement validation)
│   ├── AnchorManagementService.swift (dynamic anchor selection)
│   └── HintGenerationService.swift (hint system)
├── Models/
│   ├── PuzzleGameState.swift (game state management)
│   ├── PlacedPiece.swift (CV piece tracking)
│   └── ValidationResult.swift (validation outcomes)
└── Reused from TangramEditor/
    ├── TangramGeometry.swift
    ├── PieceType.swift
    ├── TangramPiece.swift
    └── PuzzlePersistenceService.swift
```

## Implementation Phases

## Phase 1: Foundation & Basic Puzzle Loading
**Duration:** 2-3 days  
**Goal:** Basic game structure with puzzle selection and display

### Tasks:
1. **Create Game Protocol Implementation**
   - Implement `TangramPuzzleGame` class conforming to `Game` protocol
   - Configure `GameUIConfig` for puzzle game needs
   - Set up basic game metadata (ID, title, age range)

2. **Build Puzzle Selection System**
   - Create `PuzzleSelectionViewModel` with puzzle loading
   - Implement `PuzzleSelectionView` with grid/list of available puzzles
   - Reuse `PuzzleMetadata` from TangramEditor
   - Filter puzzles by difficulty/category

3. **Implement Basic Game View**
   - Create `TangramPuzzleViewModel` with game state management
   - Build `TangramPuzzleView` with canvas area
   - Display target puzzle as dark silhouette
   - Implement back/quit navigation

4. **Set Up Puzzle Loading Service**
   - Create `PuzzleGameService` for loading bundled puzzles
   - Parse puzzle data from JSON files
   - Convert TangramEditor puzzles to game format

### Testable Outcomes:
- ✅ Click "Tangram Puzzle" in game lobby
- ✅ See puzzle selection screen with available puzzles
- ✅ Select a puzzle and see it displayed as dark silhouette
- ✅ Navigate back to puzzle selection or lobby
- ✅ Puzzles load from bundled data

### Code Example:
```swift
// TangramPuzzleGame.swift
class TangramPuzzleGame: Game {
    let id = "tangram_puzzle"
    let title = "Tangram Puzzles"
    let description = "Solve classic tangram puzzles"
    let recommendedAge = 5...12
    let thumbnailImageName = "tangram_puzzle_thumb"
    
    var gameUIConfig: GameUIConfig {
        GameUIConfig(
            showQuitButton: true,
            showHintButton: true,
            showProgressBar: true,
            showTimer: false,
            showScore: true
        )
    }
    
    func makeGameView(delegate: GameDelegate) -> AnyView {
        AnyView(TangramPuzzleView(
            viewModel: TangramPuzzleViewModel(
                puzzleService: PuzzleGameService(),
                delegate: delegate
            )
        ))
    }
}
```

---

## Phase 2: CV Integration & Piece Tracking
**Duration:** 3-4 days  
**Goal:** Process CV input, track pieces, manage anchor piece system

### Tasks:
1. **Implement CV Processing**
   - Process `RecognizedPiece` arrays in `processRecognizedPieces()`
   - Map CV colors to `PieceType` enum
   - Create `PlacedPiece` model with CV data + game state

2. **Build Anchor Management System**
   - Create `AnchorManagementService` for dynamic anchor selection
   - Implement anchor piece priority (largest piece, most central)
   - Calculate relative positions from anchor
   - Handle anchor piece removal/replacement

3. **Create CV Mock System**
   - Build `CVMockControlView` with testing menu
   - Simulate piece placement/removal for each piece type
   - Control rotation, position, and confidence values
   - Test anchor switching scenarios

4. **Visualize Piece Tracking**
   - Show recognized pieces overlaid on puzzle
   - Display anchor piece indicator
   - Show relative position calculations
   - Color code correct/incorrect placements

### Testable Outcomes:
- ✅ CV mock menu appears in development mode
- ✅ Can simulate placing each piece type
- ✅ Pieces appear on screen when "recognized"
- ✅ First piece becomes anchor (highlighted)
- ✅ Removing anchor piece promotes next piece
- ✅ Relative positions update with anchor changes

### Code Example:
```swift
// AnchorManagementService.swift
@Observable
class AnchorManagementService {
    private(set) var anchorPiece: PlacedPiece?
    private(set) var relativePieces: [PlacedPiece] = []
    
    func updatePieces(_ recognized: [RecognizedPiece]) {
        // Select anchor if none exists or current removed
        if anchorPiece == nil || !recognized.contains(where: { $0.id == anchorPiece?.id }) {
            selectNewAnchor(from: recognized)
        }
        
        // Calculate relative positions
        updateRelativePositions(recognized)
    }
    
    private func selectNewAnchor(from pieces: [RecognizedPiece]) {
        // Priority: largest piece > most central > first placed
        anchorPiece = pieces
            .sorted { p1, p2 in
                // Sort by area, then centrality
                let area1 = PieceType(from: p1.color)?.area ?? 0
                let area2 = PieceType(from: p2.color)?.area ?? 0
                return area1 > area2
            }
            .first
            .map { PlacedPiece(from: $0) }
    }
}
```

---

## Phase 3: Validation & Progress System
**Duration:** 4-5 days  
**Goal:** Validate placements, track progress, handle completion

### Tasks:
1. **Build Validation Service**
   - Create `PuzzleValidationService` with tolerance configuration
   - Implement relative position checking
   - Support rotation tolerance (±5 degrees)
   - Position tolerance (±10 points relative)

2. **Implement Progress Tracking**
   - Track correctly placed pieces
   - Show visual feedback for correct placements
   - Handle piece removal (progress regression)
   - Calculate completion percentage

3. **Create Completion System**
   - Detect when puzzle is complete
   - Trigger celebration animation
   - Award XP through `GameDelegate`
   - Transition to next puzzle or selection

4. **Add Tolerance Configuration**
   - Implement difficulty-based tolerances
   - Easy: ±15 points, ±10 degrees
   - Medium: ±10 points, ±5 degrees  
   - Hard: ±5 points, ±3 degrees

### Testable Outcomes:
- ✅ Correct piece placements turn green
- ✅ Incorrect placements show red/feedback
- ✅ Progress bar updates with placements
- ✅ Removing correct piece reduces progress
- ✅ Puzzle completion triggers celebration
- ✅ XP awarded on completion
- ✅ Can progress to next puzzle

### Code Example:
```swift
// PuzzleValidationService.swift
struct ValidationResult {
    let isCorrect: Bool
    let confidence: Double
    let deviations: Deviations
    
    struct Deviations {
        let position: Double  // Distance in points
        let rotation: Double  // Degrees
    }
}

@Observable
class PuzzleValidationService {
    private let positionTolerance: Double = 10.0
    private let rotationTolerance: Double = 5.0
    
    func validatePiece(
        _ placed: PlacedPiece,
        against target: TangramPiece,
        relativeTo anchor: PlacedPiece?
    ) -> ValidationResult {
        
        let relativePosition = calculateRelativePosition(placed, anchor)
        let targetRelative = calculateRelativePosition(target, anchorInPuzzle)
        
        let positionDiff = distance(relativePosition, targetRelative)
        let rotationDiff = angleDifference(placed.rotation, target.rotation)
        
        return ValidationResult(
            isCorrect: positionDiff <= positionTolerance && 
                      rotationDiff <= rotationTolerance,
            confidence: calculateConfidence(positionDiff, rotationDiff),
            deviations: .init(position: positionDiff, rotation: rotationDiff)
        )
    }
}
```

---

## Phase 4: Hints & User Assistance
**Duration:** 3-4 days  
**Goal:** Implement progressive hint system

### Tasks:
1. **Build Hint Generation Service**
   - Detect when player is stuck (no progress for 30s)
   - Generate contextual hints based on state
   - Progressive hint levels (subtle → obvious)

2. **Implement Hint Types**
   - **Level 1:** Highlight next piece to place
   - **Level 2:** Show piece + general area
   - **Level 3:** Show exact placement with animation
   - **Level 4:** Auto-place piece (for accessibility)

3. **Create Hint UI**
   - Hint button in game UI
   - Visual hint overlays
   - Animated placement guides
   - Hint usage tracking

4. **Add Frustration Detection**
   - Monitor failed placement attempts
   - Track time without progress
   - Automatic hint suggestions
   - Parent notification for struggling

### Testable Outcomes:
- ✅ Hint button appears in UI
- ✅ First hint highlights next piece type
- ✅ Second hint shows placement area
- ✅ Third hint animates exact placement
- ✅ Hints reduce XP reward appropriately
- ✅ Auto-hints after prolonged inactivity

### Code Example:
```swift
// HintGenerationService.swift
enum HintLevel {
    case pieceHighlight      // Which piece to place
    case placementArea       // General area on puzzle
    case exactPlacement      // Precise position/rotation
    case autoPlace          // Automatically place piece
}

@Observable
class HintGenerationService {
    private var hintLevel = 0
    private var lastProgressTime = Date()
    
    func generateHint(
        for puzzle: TangramPuzzle,
        currentState: PuzzleGameState
    ) -> HintData {
        
        // Find next best piece to place
        let unplacedPieces = findUnplacedPieces(puzzle, currentState)
        let nextPiece = selectOptimalNextPiece(unplacedPieces)
        
        hintLevel += 1
        
        switch HintLevel(rawValue: min(hintLevel, 3)) {
        case .pieceHighlight:
            return HintData.highlightPiece(nextPiece.type)
        case .placementArea:
            return HintData.showArea(nextPiece.type, area: nextPiece.boundingBox)
        case .exactPlacement:
            return HintData.showExact(nextPiece)
        case .autoPlace:
            return HintData.autoPlace(nextPiece)
        }
    }
}
```

---

## Phase 5: Polish & Edge Cases
**Duration:** 2-3 days  
**Goal:** Handle edge cases, polish UX, optimize performance

### Tasks:
1. **Handle Edge Cases**
   - Multiple solutions for same puzzle
   - Pieces placed outside expected area
   - Rapid piece addition/removal
   - CV noise and false positives
   - Network/loading failures

2. **Polish User Experience**
   - Smooth animations for piece snapping
   - Sound effects for correct/incorrect
   - Haptic feedback on key events
   - Loading states and error messages
   - Tutorial for first-time players

3. **Optimize Performance**
   - Efficient validation algorithms
   - Debounce CV updates
   - Cache puzzle data
   - Minimize view redraws
   - Profile and fix bottlenecks

4. **Add Analytics**
   - Track puzzle completion times
   - Monitor hint usage patterns
   - Record common failure points
   - Parent dashboard integration

### Testable Outcomes:
- ✅ Smooth 60fps during piece movement
- ✅ No crashes with rapid piece changes
- ✅ Graceful handling of CV errors
- ✅ Clear feedback for all actions
- ✅ Tutorial explains game mechanics
- ✅ Parent dashboard shows progress

---

## Testing Strategy

### Development Testing with CV Mock
```swift
struct CVMockControlView: View {
    @Binding var mockPieces: [RecognizedPiece]
    
    var body: some View {
        VStack {
            Text("CV Simulator")
            
            ForEach(PieceType.allCases) { type in
                HStack {
                    Text(type.name)
                    Button("Place Correct") { 
                        placePiece(type, correct: true) 
                    }
                    Button("Place Wrong") { 
                        placePiece(type, correct: false) 
                    }
                    Button("Remove") { 
                        removePiece(type) 
                    }
                }
            }
            
            Button("Clear All") { mockPieces.removeAll() }
            Button("Complete Puzzle") { placeAllCorrect() }
            Button("Scramble") { scramblePieces() }
        }
    }
}
```

### Test Scenarios
1. **Happy Path:** Place all pieces correctly in order
2. **Anchor Switching:** Remove first piece mid-game
3. **Progress/Regress:** Add pieces, remove some, re-add
4. **Hint Flow:** Request hints at various stages
5. **Edge Cases:** Rapid changes, out-of-bounds, rotations

---

## Success Metrics

### Phase Completion Criteria
- **Phase 1:** Basic game loads and displays puzzles
- **Phase 2:** CV mock system works, anchor management functional
- **Phase 3:** Validation accurate to specified tolerances
- **Phase 4:** Hints helpful and progressive
- **Phase 5:** Smooth, polished experience

### Overall Success Metrics
- 95% puzzle completion accuracy
- <100ms validation response time
- Hints reduce stuck time by >50%
- No crashes in 1000 piece placements
- Parent satisfaction with progress tracking

---

## Implementation Timeline

**Total Duration:** 14-17 days

```
Week 1:
  Mon-Wed: Phase 1 (Foundation)
  Thu-Fri: Phase 2 start (CV Integration)

Week 2:  
  Mon-Tue: Phase 2 complete
  Wed-Fri: Phase 3 (Validation)

Week 3:
  Mon-Tue: Phase 4 (Hints)
  Wed-Thu: Phase 5 (Polish)
  Fri: Final testing & deployment
```

---

## Next Steps

1. Start with Phase 1 foundation
2. Create `TangramPuzzleGame` class
3. Implement puzzle selection view
4. Begin reusing TangramEditor components
5. Set up CV mock system early for testing

This plan provides a structured, testable approach to building the Tangram puzzle game while maximizing reuse of existing components and following established architectural patterns.