# Tangram Editor Architecture Refactor: Unified Transformation System

## Executive Summary

The Tangram Editor is currently brittle due to fragmented responsibilities across 11+ services, duplicate validation logic, and separate code paths for preview vs actual placement. This proposal outlines a complete refactor to create a unified, reliable transformation system.

## Current Problems

### 1. Fragmented Architecture
```
Current Services (11 files, overlapping responsibilities):
├── PiecePlacementService      → Places pieces
├── PieceManipulationService   → Calculates how pieces can move
├── ConnectionService          → Manages connections
├── ValidationService          → Validates placement
├── PuzzleValidationRules      → Also validates (DUPLICATE!)
├── GeometryService           → Geometry calculations
├── TangramGeometry           → Also geometry (DUPLICATE!)
├── TangramCoordinateSystem   → Coordinate transformations
├── ConstraintManager         → Dynamic constraints
├── TangramEditorCoordinator  → Coordinates placement
└── TangramEditorViewModel    → Manages state across 4 files
```

### 2. Separate Preview vs Actual Logic

**Current Preview Flow:**
```swift
handleRotation() → Calculate transform A → Set ghostTransform → Show preview
```

**Current Placement Flow:**
```swift
confirmRotation() → Use ghostTransform (or not?) → Apply to piece
```

**Problems:**
- Preview and actual use different calculation methods
- If preview validation fails, ghostTransform is nil, so confirm does nothing
- No guarantee preview matches what gets placed
- Preview can show invalid positions (overlapping pieces)

### 3. State Management Chaos
- `ghostTransform` (preview state)
- `previewPiece` (different preview state)
- `manipulatingPieceId` (tracking state)
- `initialManipulationTransforms` (temporary state)
- `manipulationConstraints` (dynamic limits)
- `pieceManipulationModes` (how pieces can move)

### 4. Validation Inconsistencies
- `ValidationService.hasAreaOverlap()` - Basic overlap check
- `PuzzleValidationRules.isValidPlacement()` - Comprehensive validation
- Some paths use one, some use the other, some use neither

## Proposed Solution: Unified Transformation System

### Core Principle
**ONE service, ONE calculation, ONE validation, used for BOTH preview AND placement**

### New Architecture

```
PieceTransformEngine (Single source of truth)
├── Transform Calculation
│   ├── Rotation (vertex-to-vertex, vertex-to-edge)
│   ├── Sliding (edge-to-edge, vertex-to-edge)
│   └── Placement (first piece, connected pieces)
├── Constraint Application
│   ├── Connection constraints
│   ├── Snap points (45° angles, 25% positions)
│   └── Boundary constraints
├── Validation
│   ├── Overlap detection
│   ├── Connection integrity
│   └── Puzzle rules
└── Result
    ├── Valid transform → Show preview → Apply on confirm
    └── Invalid → No preview → No placement
```

## Implementation Plan

### Phase 1: Create Unified Transform Engine

**New File: `PieceTransformEngine.swift`**

```swift
import Foundation
import CoreGraphics

/// Single source of truth for all piece transformations
@MainActor
class PieceTransformEngine {
    
    // MARK: - Types
    
    enum Operation {
        case place(center: CGPoint, rotation: Double)
        case rotate(angle: Double, pivot: CGPoint, connection: Connection?)
        case slide(distance: Double, edge: Edge, connection: Connection?)
        case drag(to: CGPoint)
    }
    
    struct TransformResult {
        let transform: CGAffineTransform
        let isValid: Bool
        let violations: [ValidationViolation]
        let snapIndicators: [SnapIndicator]
    }
    
    struct ValidationViolation {
        enum ViolationType {
            case overlap(with: TangramPiece)
            case connectionBroken(Connection)
            case outOfBounds
        }
        let type: ViolationType
        let severity: Severity
    }
    
    struct SnapIndicator {
        let position: CGPoint
        let type: SnapType
        let isActive: Bool
    }
    
    // MARK: - Core Method
    
    /// Calculate and validate any piece transformation
    /// This is THE ONLY method for calculating transforms
    func calculateTransform(
        for piece: TangramPiece,
        operation: Operation,
        connections: [Connection],
        otherPieces: [TangramPiece],
        canvasSize: CGSize
    ) -> TransformResult {
        
        // Step 1: Calculate raw transform based on operation
        var transform = calculateRawTransform(
            piece: piece,
            operation: operation
        )
        
        // Step 2: Apply connection constraints
        if !connections.isEmpty {
            transform = applyConnectionConstraints(
                transform: transform,
                piece: piece,
                connections: connections,
                otherPieces: otherPieces,
                operation: operation
            )
        }
        
        // Step 3: Apply snap points
        let (snappedTransform, snapIndicators) = applySnapPoints(
            transform: transform,
            piece: piece,
            operation: operation
        )
        
        // Step 4: Validate the final transform
        let violations = validate(
            transform: snappedTransform,
            piece: piece,
            connections: connections,
            otherPieces: otherPieces,
            canvasSize: canvasSize
        )
        
        return TransformResult(
            transform: snappedTransform,
            isValid: violations.isEmpty,
            violations: violations,
            snapIndicators: snapIndicators
        )
    }
    
    // MARK: - Transform Calculation
    
    private func calculateRawTransform(
        piece: TangramPiece,
        operation: Operation
    ) -> CGAffineTransform {
        switch operation {
        case .place(let center, let rotation):
            // Place piece at specific position
            return createPlacementTransform(
                type: piece.type,
                center: center,
                rotation: rotation
            )
            
        case .rotate(let angle, let pivot, let connection):
            // Rotate around pivot point
            return createRotationTransform(
                piece: piece,
                angle: angle,
                pivot: pivot,
                connection: connection
            )
            
        case .slide(let distance, let edge, _):
            // Slide along edge
            return createSlideTransform(
                piece: piece,
                distance: distance,
                edge: edge
            )
            
        case .drag(let position):
            // Free drag to position
            return createDragTransform(
                piece: piece,
                to: position
            )
        }
    }
    
    private func createRotationTransform(
        piece: TangramPiece,
        angle: Double,
        pivot: CGPoint,
        connection: Connection?
    ) -> CGAffineTransform {
        // Get the piece's connected vertex in local space
        let localVertex = getLocalVertex(for: piece, connection: connection)
        let visualVertex = scaleToVisual(localVertex)
        
        // For vertex-to-edge: project after rotation
        if let conn = connection,
           case .vertexToEdge(_, _, let edgePieceId, let edgeIndex) = conn.type {
            // Special handling for vertex-to-edge
            return createVertexToEdgeRotation(
                piece: piece,
                visualVertex: visualVertex,
                angle: angle,
                edgePieceId: edgePieceId,
                edgeIndex: edgeIndex
            )
        } else {
            // Standard rotation around pivot
            var transform = CGAffineTransform.identity
            transform = transform.translatedBy(x: pivot.x, y: pivot.y)
            transform = transform.rotated(by: angle)
            transform = transform.translatedBy(x: -visualVertex.x, y: -visualVertex.y)
            return transform
        }
    }
    
    // MARK: - Connection Constraints
    
    private func applyConnectionConstraints(
        transform: CGAffineTransform,
        piece: TangramPiece,
        connections: [Connection],
        otherPieces: [TangramPiece],
        operation: Operation
    ) -> CGAffineTransform {
        // Ensure connections are maintained
        var adjustedTransform = transform
        
        for connection in connections {
            switch connection.type {
            case .vertexToVertex:
                // Vertex must stay at exact point
                adjustedTransform = maintainVertexToVertex(
                    transform: adjustedTransform,
                    piece: piece,
                    connection: connection,
                    otherPieces: otherPieces
                )
                
            case .vertexToEdge:
                // Vertex must stay on edge line
                adjustedTransform = maintainVertexToEdge(
                    transform: adjustedTransform,
                    piece: piece,
                    connection: connection,
                    otherPieces: otherPieces
                )
                
            case .edgeToEdge:
                // Edges must stay parallel and touching
                adjustedTransform = maintainEdgeToEdge(
                    transform: adjustedTransform,
                    piece: piece,
                    connection: connection,
                    otherPieces: otherPieces
                )
            }
        }
        
        return adjustedTransform
    }
    
    // MARK: - Snap Points
    
    private func applySnapPoints(
        transform: CGAffineTransform,
        piece: TangramPiece,
        operation: Operation
    ) -> (CGAffineTransform, [SnapIndicator]) {
        var snapIndicators: [SnapIndicator] = []
        var snappedTransform = transform
        
        switch operation {
        case .rotate(let angle, let pivot, _):
            // Snap to 45° increments
            let snapAngles = [-180.0, -135.0, -90.0, -45.0, 0.0, 45.0, 90.0, 135.0, 180.0]
            let degrees = angle * 180 / .pi
            
            if let nearestAngle = snapAngles.min(by: { abs($0 - degrees) < abs($1 - degrees) }) {
                let snappedRadians = nearestAngle * .pi / 180
                
                // Recalculate transform with snapped angle
                snappedTransform = createRotationTransform(
                    piece: piece,
                    angle: snappedRadians,
                    pivot: pivot,
                    connection: nil // Already handled in constraints
                )
                
                // Add snap indicators
                for snapAngle in snapAngles {
                    let rad = snapAngle * .pi / 180
                    let indicator = SnapIndicator(
                        position: CGPoint(
                            x: pivot.x + cos(rad) * 50,
                            y: pivot.y + sin(rad) * 50
                        ),
                        type: .rotation(angle: snapAngle),
                        isActive: snapAngle == nearestAngle
                    )
                    snapIndicators.append(indicator)
                }
            }
            
        case .slide(let distance, let edge, _):
            // Snap to 0%, 25%, 50%, 75%, 100%
            let edgeLength = edge.length
            let snapPercentages = [0.0, 0.25, 0.5, 0.75, 1.0]
            let normalizedDistance = distance / edgeLength
            
            if let nearestPercent = snapPercentages.min(by: { 
                abs($0 - normalizedDistance) < abs($1 - normalizedDistance) 
            }) {
                let snappedDistance = nearestPercent * edgeLength
                
                // Recalculate transform with snapped distance
                snappedTransform = createSlideTransform(
                    piece: piece,
                    distance: snappedDistance,
                    edge: edge
                )
                
                // Add snap indicators
                for percent in snapPercentages {
                    let pos = edge.pointAt(percent: percent)
                    let indicator = SnapIndicator(
                        position: pos,
                        type: .slide(percent: percent),
                        isActive: percent == nearestPercent
                    )
                    snapIndicators.append(indicator)
                }
            }
            
        default:
            break
        }
        
        return (snappedTransform, snapIndicators)
    }
    
    // MARK: - Validation
    
    private func validate(
        transform: CGAffineTransform,
        piece: TangramPiece,
        connections: [Connection],
        otherPieces: [TangramPiece],
        canvasSize: CGSize
    ) -> [ValidationViolation] {
        var violations: [ValidationViolation] = []
        
        // Create test piece with new transform
        var testPiece = piece
        testPiece.transform = transform
        
        // Check 1: Overlap with other pieces
        for other in otherPieces where other.id != piece.id {
            if hasAreaOverlap(testPiece, other) {
                violations.append(ValidationViolation(
                    type: .overlap(with: other),
                    severity: .error
                ))
            }
        }
        
        // Check 2: Connection integrity
        for connection in connections {
            if !isConnectionMaintained(
                piece: testPiece,
                connection: connection,
                otherPieces: otherPieces
            ) {
                violations.append(ValidationViolation(
                    type: .connectionBroken(connection),
                    severity: .error
                ))
            }
        }
        
        // Check 3: Canvas bounds
        let vertices = getWorldVertices(for: testPiece)
        let inBounds = vertices.allSatisfy { vertex in
            vertex.x >= 0 && vertex.x <= canvasSize.width &&
            vertex.y >= 0 && vertex.y <= canvasSize.height
        }
        
        if !inBounds {
            violations.append(ValidationViolation(
                type: .outOfBounds,
                severity: .warning
            ))
        }
        
        return violations
    }
}
```

### Phase 2: Update ViewModel to Use Transform Engine

**Updated: `TangramEditorViewModel+PieceOperations.swift`**

```swift
extension TangramEditorViewModel {
    
    // MARK: - Simplified Manipulation Handlers
    
    func handleRotation(pieceId: String, angle: Double) {
        guard let piece = puzzle.pieces.first(where: { $0.id == pieceId }),
              let mode = pieceManipulationModes[pieceId] else { return }
        
        // Get connections for this piece
        let connections = puzzle.connections.filter { $0.involvesPiece(pieceId) }
        let otherPieces = puzzle.pieces.filter { $0.id != pieceId }
        
        // Use unified transform engine
        let result = transformEngine.calculateTransform(
            for: piece,
            operation: .rotate(
                angle: angle,
                pivot: mode.pivot,
                connection: connections.first
            ),
            connections: connections,
            otherPieces: otherPieces,
            canvasSize: uiState.currentCanvasSize
        )
        
        // Update UI based on result
        if result.isValid {
            uiState.ghostTransform = result.transform
            uiState.snapIndicators = result.snapIndicators
            uiState.showSnapIndicator = true
        } else {
            uiState.ghostTransform = nil
            uiState.snapIndicators = []
            uiState.showSnapIndicator = false
            
            // Show validation feedback
            if let firstViolation = result.violations.first {
                switch firstViolation.type {
                case .overlap:
                    toastService.showError("Pieces cannot overlap")
                case .connectionBroken:
                    toastService.showError("Connection would be broken")
                case .outOfBounds:
                    toastService.showWarning("Piece would go out of bounds")
                }
            }
        }
    }
    
    func confirmRotation() {
        guard let pieceId = uiState.manipulatingPieceId,
              let transform = uiState.ghostTransform,
              let pieceIndex = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) else {
            return
        }
        
        // Simply apply the validated transform
        undoManager.saveState(puzzle: puzzle)
        puzzle.pieces[pieceIndex].transform = transform
        
        // Clear UI state
        uiState.ghostTransform = nil
        uiState.manipulatingPieceId = nil
        uiState.snapIndicators = []
        uiState.showSnapIndicator = false
        
        // Update state
        updateManipulationModes()
        validate()
        notifyPuzzleChanged()
    }
    
    func handleSlide(pieceId: String, distance: Double) {
        guard let piece = puzzle.pieces.first(where: { $0.id == pieceId }),
              let mode = pieceManipulationModes[pieceId],
              case .slidable(let edge, _, _) = mode else { return }
        
        // Get connections for this piece
        let connections = puzzle.connections.filter { $0.involvesPiece(pieceId) }
        let otherPieces = puzzle.pieces.filter { $0.id != pieceId }
        
        // Use unified transform engine
        let result = transformEngine.calculateTransform(
            for: piece,
            operation: .slide(
                distance: distance,
                edge: edge,
                connection: connections.first
            ),
            connections: connections,
            otherPieces: otherPieces,
            canvasSize: uiState.currentCanvasSize
        )
        
        // Update UI based on result (same as rotation)
        if result.isValid {
            uiState.ghostTransform = result.transform
            uiState.snapIndicators = result.snapIndicators
            uiState.showSnapIndicator = true
        } else {
            uiState.ghostTransform = nil
            uiState.snapIndicators = []
            uiState.showSnapIndicator = false
        }
    }
    
    func confirmSlide() {
        // Identical to confirmRotation - just apply the ghost transform
        confirmRotation()
    }
}
```

### Phase 3: Simplify UI State

**Updated: `TangramEditorUIState.swift`**

```swift
@Observable
class TangramEditorUIState {
    // Canvas state
    var currentCanvasSize: CGSize = .zero
    var zoomLevel: Double = 1.0
    
    // Current manipulation (ONE state for any operation)
    var currentOperation: PieceTransformEngine.Operation?
    var manipulatingPieceId: String?
    var ghostTransform: CGAffineTransform?
    var snapIndicators: [PieceTransformEngine.SnapIndicator] = []
    var showSnapIndicator: Bool = false
    
    // Selection state
    var selectedPieceIds: Set<String> = []
    
    // Feedback
    var validationViolations: [PieceTransformEngine.ValidationViolation] = []
    
    // Remove all the duplicate preview states:
    // - previewPiece (redundant)
    // - previewTransform (redundant)
    // - pendingPieceType (move to operation)
    // - selectedCanvasPoints (move to operation)
}
```

### Phase 4: Consolidate Services

**Services to Delete/Merge:**
1. `PiecePlacementService` → Into `PieceTransformEngine`
2. `PieceManipulationService` → Into `PieceTransformEngine`
3. `GeometryService` → Into `PieceTransformEngine`
4. `ValidationService` → Into `PieceTransformEngine`
5. `PuzzleValidationRules` → Into `PieceTransformEngine`
6. `ConstraintManager` → Into `PieceTransformEngine`

**Services to Keep:**
- `ConnectionService` → Focused on connection management only
- `PuzzlePersistenceService` → Focused on save/load only
- `ToastService` → UI feedback only
- `UndoRedoManager` → History management only
- `ThumbnailGenerator` → Thumbnail generation only

### Phase 5: Update View Layer

**Updated: `PieceView.swift`**

```swift
struct PieceView: View {
    let piece: TangramPiece
    let isGhost: Bool
    let snapIndicators: [PieceTransformEngine.SnapIndicator]
    let onManipulation: (PieceTransformEngine.Operation) -> Void
    let onConfirm: () -> Void
    
    var body: some View {
        ZStack {
            // Piece shape
            PieceShape(type: piece.type)
                .fill(isGhost ? Color.blue.opacity(0.5) : pieceColor)
                .transformEffect(piece.transform)
            
            // Snap indicators
            ForEach(snapIndicators, id: \.position) { indicator in
                SnapIndicatorView(indicator: indicator)
            }
        }
        .gesture(manipulationGesture)
    }
    
    var manipulationGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Determine operation type and notify
                let operation = determineOperation(from: value)
                onManipulation(operation)
            }
            .onEnded { _ in
                onConfirm()
            }
    }
}
```

## Benefits of This Approach

### 1. Single Source of Truth
- ONE service calculates ALL transforms
- ONE validation pipeline
- ONE set of rules

### 2. Preview = Actual
- Preview uses `transformEngine.calculateTransform()`
- Confirm applies the exact same transform
- No divergence possible

### 3. Simplified State
- Remove duplicate state variables
- Clear separation of concerns
- Predictable data flow

### 4. Maintainable
- Add new features in one place
- Fix bugs in one place
- Test in one place

### 5. Reliable
- If preview shows, placement works
- If preview doesn't show, placement is invalid
- No surprises

## Migration Strategy

### Step 1: Create `PieceTransformEngine` (New file)
- Implement core transform calculation
- Port validation logic from existing services
- Add comprehensive tests

### Step 2: Update ViewModel (Modify existing)
- Replace fragmented logic with engine calls
- Simplify state management
- Remove redundant code

### Step 3: Clean up Services (Delete/merge)
- Gradually remove redundant services
- Move useful utilities to engine
- Keep only focused, single-purpose services

### Step 4: Update Views (Modify existing)
- Simplify gesture handling
- Use unified state
- Remove duplicate preview logic

## Testing Strategy

### Unit Tests for Transform Engine
```swift
func testVertexToVertexRotation() {
    let result = engine.calculateTransform(
        for: piece,
        operation: .rotate(angle: 45, pivot: point),
        connections: [vertexConnection],
        otherPieces: []
    )
    
    XCTAssertTrue(result.isValid)
    XCTAssertEqual(getVertex(piece, transform: result.transform), pivot)
}

func testOverlapPrevention() {
    let result = engine.calculateTransform(
        for: piece,
        operation: .rotate(angle: 90, pivot: point),
        connections: [],
        otherPieces: [overlappingPiece]
    )
    
    XCTAssertFalse(result.isValid)
    XCTAssertEqual(result.violations.first?.type, .overlap)
}
```

### Integration Tests
- Test complete manipulation flows
- Verify preview matches placement
- Test all connection types

## Success Criteria

1. ✅ ONE service handles all transformations
2. ✅ Preview and actual placement use identical logic
3. ✅ No duplicate validation code
4. ✅ Overlapping pieces impossible
5. ✅ Connections always maintained
6. ✅ Predictable, testable behavior

## Timeline

- **Day 1-2**: Implement `PieceTransformEngine`
- **Day 3**: Update ViewModel to use engine
- **Day 4**: Remove redundant services
- **Day 5**: Update views and test
- **Day 6-7**: Debug and polish

## Conclusion

The current architecture is fundamentally broken due to fragmentation and duplication. This proposal creates a unified, reliable system where:

1. **One service** calculates transforms
2. **One validation** pipeline ensures correctness
3. **Preview equals placement** - always

This isn't a patch - it's fixing the root cause of all the brittleness.