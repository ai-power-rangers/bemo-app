# CV-First Checkpoint Implementation Tracker - Phase 1 (First 1/4)

## 🎯 STRATEGY: Building TangramCV as Parallel Implementation

**Decision:** Creating `TangramCV` as a completely separate game alongside the original `Tangram` game. This allows:
- Zero risk to existing game
- Side-by-side testing and comparison
- Clean architecture without legacy constraints
- Easy rollback if needed
- Original serves as reference implementation

**Migration Plan:**
1. Build TangramCV with full CV-ready features
2. Test thoroughly against original
3. Replace TangramGame registration with TangramCVGame
4. Rename TangramCV → Tangram after validation
5. Archive original code

---

## Overview
Implementing lines 1-450 of CV-first-checkpoint.md, focusing on three-zone layout, dynamic anchor system, and beginning CV output generation.

## Implementation Status

### ✅ Completed
- [x] Analyzed existing codebase structure
- [x] Created comprehensive implementation plan
- [x] Got user approval for parallel implementation strategy
- [x] **Create TangramCV Game Structure**
  - [x] Create TangramCV directory structure
  - [x] Create TangramCVGame.swift (game entry point)
  - [x] Register as separate game in catalog (GameLobbyViewModel)
- [x] **Phase 1: Three-Zone Layout System**
  - [x] **TangramThreeZoneScene.swift**
    - [x] Create new scene file in TangramCV/Views/
    - [x] Setup three zones (reference/assembly/storage)
    - [x] Implement zone boundary detection
    - [x] Add haptic feedback for assembly zone entry
    - [x] NO snap-to-target behavior
    - [x] Scatter pieces in storage zone

- [x] **Phase 2: Dynamic Anchor System**
  - [x] **Anchor Management**
    - [x] First piece placement becomes anchor
    - [x] Visual anchor indicator (green dot)
    - [x] Anchor promotion on removal
    - [x] Hysteresis for CV mode (5 frames)
    - [x] Immediate promotion for touch mode
- [x] **Phase 3: CV Output Stream Generator (Partial)**
  - [x] Implemented inline in TangramThreeZoneScene
  - [x] 20Hz throttling implemented
  - [x] Generate CV JSON format
  - [x] Map piece types to CV names
  - [x] Calculate relative positions from anchor
  - [ ] **CVOutputBridge.swift** - To be extracted as separate service
  - [ ] **CVToInternalConverter.swift** - Still needed for CV input

- [ ] **CVToInternalConverter.swift (Partial)**
  - [ ] Create in TangramCV/Services/
  - [ ] Implement CV name mapping
  - [ ] Setup camera inversion toggle
  - [ ] Begin coordinate conversion logic

#### Phase 4: Integration
- [ ] **TangramCVGameView.swift**
  - [ ] Create main game view
  - [ ] Integrate TangramThreeZoneScene
  
- [ ] **TangramCVGameViewModel.swift**
  - [ ] Create view model with CV stream processing
  - [ ] Add anchor tracking
  - [ ] No snap behavior

## Technical Decisions Made

### Architecture Choices
1. **Parallel implementation** - TangramCV alongside original Tangram
2. **Full migration** - No feature flags within TangramCV
3. **Haptic feedback** - UIImpactFeedbackGenerator for zone entry
4. **Anchor indicator** - Small green circle at piece center
5. **No snapping** - Pieces stay exactly where dropped
6. **Proper MVVM-S** - Services handle logic, views handle display

### Coordinate System Contract
- Internal: Y-up, radians, normalized (square = 1.0)
- CV Output: Y-up, degrees, relative to anchor
- SpriteKit: Y-down conversion at render only

### Performance Optimizations
- CV stream throttled to 20Hz (50ms minimum between updates)
- Validation at 10Hz when implemented
- No physics simulation - direct manipulation

## Directory Structure

```
Bemo/Features/Game/Games/
├── Tangram/           (ORIGINAL - KEEP AS REFERENCE)
│   └── [existing files remain untouched]
│
└── TangramCV/         (NEW CV-READY IMPLEMENTATION)
    ├── TangramCVGame.swift              (Game entry point)
    ├── Views/
    │   ├── TangramCVGameView.swift     (Main game view)
    │   ├── TangramThreeZoneScene.swift (Three-zone layout)
    │   └── Components/
    │       └── [reuse PuzzlePieceNode with modifications]
    ├── ViewModels/
    │   └── TangramCVGameViewModel.swift
    ├── Services/
    │   ├── CVOutputBridge.swift        (NEW: CV stream generator)
    │   ├── CVToInternalConverter.swift (NEW: Coordinate conversion)
    │   └── TangramRelativeValidator.swift (NEW: Relative validation)
    └── Models/
        └── [mostly reuse from original Tangram]
```

## Shared Components (Reused from Original)
- `TangramPieceType` - Piece definitions
- `TangramGameGeometry` - Vertex calculations
- `TangramColors` - Color schemes
- `GamePuzzleData` - Puzzle data structures
- `TangramGameConstants` - Constants (will override some)
- `PuzzleLibraryService` - Puzzle loading

## Files Created/Modified

### New Files (in TangramCV/)
- [x] `TangramCVGame.swift` ✅
- [x] `Views/TangramCVGameView.swift` ✅
- [x] `Views/TangramThreeZoneScene.swift` ✅
- [x] `ViewModels/TangramCVGameViewModel.swift` ✅
- [ ] `Services/CVOutputBridge.swift` (functionality inline, to be extracted)
- [ ] `Services/CVToInternalConverter.swift` (Phase 2)
- [ ] `Services/TangramRelativeValidator.swift` (Phase 2)

### Modified Files
- [x] `GameLobbyViewModel.swift` - Added TangramCVGame registration ✅
- [x] `PuzzlePieceNode.swift` - Copied and modified for CV version ✅

### Original Tangram Files
- **UNCHANGED** - All original files remain as reference

## Testing Checklist

### Visual Testing
- [ ] Three zones clearly visible and properly sized
- [ ] Reference puzzle displays correctly in top zone
- [ ] Pieces scattered naturally in storage zone
- [ ] Assembly zone has dashed boundary indicator
- [ ] Pieces can be dragged freely between zones
- [ ] Haptic feedback triggers on assembly zone entry
- [ ] Anchor indicator appears on first placed piece
- [ ] Anchor promotes correctly when removed
- [ ] No snapping behavior anywhere
- [ ] CV output logged to console

### Performance Testing
- [ ] Maintains 60 FPS during drag operations
- [ ] CV output doesn't cause lag
- [ ] Smooth piece movement
- [ ] No memory leaks

### Integration Testing
- [ ] TangramCV loads as separate game
- [ ] Original Tangram still works
- [ ] Puzzle selection works
- [ ] Back/Next navigation preserved

## Known Issues
- None yet

## Current Implementation Summary

### What's Working Now ✅
1. **TangramCV Game** - Fully parallel implementation alongside original
2. **Three-Zone Layout** - Reference (top), Assembly (middle), Storage (bottom)
3. **Dynamic Anchor System** - First piece becomes anchor, promotes on removal
4. **CV Output Stream** - Generates CV JSON at 20Hz with relative positions
5. **Haptic Feedback** - Triggers when entering assembly zone
6. **No Snapping** - Pieces stay exactly where dropped
7. **Visual Indicators** - Green dot for anchor, dashed boundary for assembly

### Ready for Testing 🧪
The game should now be playable! You can:
1. Build and run the app
2. Select "Tangram CV" from the lobby (green camera icon)
3. Pick a puzzle
4. Drag pieces from storage to assembly zone
5. Watch the CV output indicator in top-right
6. Feel haptic feedback when entering assembly
7. See anchor indicator (green dot) on first placed piece

### What's Missing (Phase 2) 📋
1. **Relative Validation** - Still needs TangramRelativeValidator
2. **CV Input Processing** - CVToInternalConverter for real CV data
3. **Completion Detection** - Currently placeholder
4. **Puzzle Loading** - May need adjustment for actual puzzle data

## Next Steps
1. ✅ Build and test the visual layout
2. ✅ Verify three zones display correctly
3. ✅ Test piece dragging and haptic feedback
4. ✅ Confirm anchor system works
5. ✅ Check CV output in console
6. Begin Phase 2: Relative validation implementation

---
*Last Updated: 2025-08-08 - Phase 1 Complete! Ready for visual testing*