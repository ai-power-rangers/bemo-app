# Tangram Editor Implementation Plan

## Executive Summary

A comprehensive implementation plan for a CAD-like tangram puzzle editor that integrates with Bemo's game framework. The editor enables creation of puzzle targets with precise mathematical validation and constraint-based connections.

## Implementation Phases

### Phase 1: Core Validation System ✅ COMPLETE
**Goal:** Build robust geometric validation with clear separation of concerns

**Status:** 100% Complete
- ✅ Mathematical piece definitions with exact geometry
- ✅ Three-layer validation system (geometric, connection, semantic)
- ✅ Polygon overlap detection with proper boundary handling
- ✅ Edge/vertex contact detection
- ✅ Graph connectivity validation

### Phase 2: Connection System ✅ COMPLETE  
**Goal:** Implement constraint-based connections between pieces

**Status:** 100% Complete
- ✅ Vertex-to-vertex connections (rotation constraints)
- ✅ Edge-to-edge connections (sliding constraints)
- ✅ Support for different length edges (partial overlap)
- ✅ Connection validation and constraint satisfaction
- ✅ Full test coverage with new clean API
- ✅ All deprecated methods removed
- ✅ TangramEditorEngine with state management

**Minor Issue:** Missing `removeAllPieces()` method in ConnectionSystem (5 min fix)

### Phase 3: Game Integration 🚧 NOT STARTED
**Goal:** Integrate editor with Bemo's game framework

**Status:** 0% Complete
- ❌ TangramEditorGame class (conforms to Game protocol)
- ❌ Integration with game selection menu
- ❌ Navigation from parent dashboard

### Phase 4: UI Implementation 🚧 NOT STARTED
**Goal:** Build SwiftUI interface for puzzle creation

**Status:** 0% Complete
- ❌ TangramEditorView (main editor interface)
- ❌ TangramEditorViewModel (MVVM pattern)
- ❌ Piece rendering and selection
- ❌ Connection creation workflow
- ❌ Visual feedback system
- ❌ Constraint visualization

### Phase 5: User Interaction 🚧 NOT STARTED
**Goal:** Implement editing workflows

**Status:** 0% Complete
- ❌ Piece manipulation (drag, rotate)
- ❌ Connection point highlighting
- ❌ Snap-to-connection behavior
- ❌ Validation feedback
- ❌ Undo/redo system

### Phase 6: Persistence & Export 🚧 NOT STARTED
**Goal:** Save and share puzzles

**Status:** 0% Complete  
- ❌ Save/load UI
- ❌ Export to gameplay format
- ❌ Puzzle library integration
- ❌ Templates and presets

## Architecture Overview

### Clean Validation System

The validation system separates geometric truth from semantic interpretation:

#### Layer 1: Geometric Detection (Pure Math)
```swift
// Pure geometric relationships - no semantic interpretation
func hasAreaOverlap(_ pieceA: String, _ pieceB: String) -> Bool
func hasEdgeContact(_ pieceA: String, _ pieceB: String) -> Bool  
func hasVertexContact(_ pieceA: String, _ pieceB: String) -> Bool
func getGeometricRelationship(_ pieceA: String, _ pieceB: String) -> GeometricRelationship

enum GeometricRelationship {
    case areaOverlap    // Interior intersection - ALWAYS INVALID
    case edgeContact    // Sharing edge - needs connection
    case vertexContact  // Touching at point - needs connection
    case noContact      // Not touching - breaks connectivity
}
```

#### Layer 2: Connection Management
```swift
// Connection queries and management
func areConnected(_ pieceA: String, _ pieceB: String) -> Bool
func createConnection(type: ConnectionType) -> Connection?
func connectionBetween(_ pieceA: String, _ pieceB: String) -> Connection?
func isConnected() -> Bool // Graph connectivity check
```

#### Layer 3: Semantic Validation
```swift
// High-level validation combining geometry and connections
func hasInvalidAreaOverlaps() -> Bool    // Any area overlaps (always invalid)
func hasUnexplainedContacts() -> Bool    // Touches without connections
func isValidAssembly() -> Bool           // Overall puzzle validity

// Main validation logic
func isValidAssembly() -> Bool {
    return !hasInvalidAreaOverlaps() &&  // No interior overlaps
           !hasUnexplainedContacts() &&  // All touches have connections
           isConnected()                  // All pieces form connected graph
}
```

### Connection System

#### Connection Types
```swift
enum ConnectionType {
    case vertexToVertex(pieceA: String, vertexA: Int, pieceB: String, vertexB: Int)
    case edgeToEdge(pieceA: String, edgeA: Int, pieceB: String, edgeB: Int)
}
```

#### Constraint System
```swift
enum ConstraintType {
    case rotation(around: CGPoint, range: ClosedRange<Double>)
    case translation(along: CGVector, range: ClosedRange<Double>)
    case fixed
}
```

**Key Features:**
- Vertex connections allow rotation around shared point
- Edge connections allow sliding (shorter edge along longer edge)
- Multiple connections can fully constrain a piece

#### Edge Connections with Different Lengths
A fundamental tangram feature - smaller pieces can slide along larger pieces:
```swift
// Calculate sliding range for different length edges
let slidingRange = max(0, longerEdgeLength - shorterEdgeLength)
Constraint(type: .translation(along: edgeVector, range: 0...slidingRange))
```

### Geometry Engine

#### Core Algorithms

1. **Polygon Overlap Detection** (Simplified for convex polygons):
```swift
func polygonsOverlap(_ vertices1: [CGPoint], _ vertices2: [CGPoint]) -> Bool {
    // 1. Check if any vertex of polygon1 is inside polygon2
    // 2. Check if any vertex of polygon2 is inside polygon1  
    // 3. Check for edge intersections (excluding endpoints)
    // More reliable than complex clipping for convex shapes
}
```

2. **Edge Coincidence Detection**:
```swift
// Full coincidence for same-length edges
func edgesCoincide(_ edgeA: (CGPoint, CGPoint), _ edgeB: (CGPoint, CGPoint)) -> Bool

// Partial coincidence for different-length edges
func edgePartiallyCoincides(shorterEdge: (CGPoint, CGPoint), 
                           longerEdge: (CGPoint, CGPoint)) -> Bool
```

3. **Shared Geometry Detection**:
```swift
func sharedVertices(_ vertices1: [CGPoint], _ vertices2: [CGPoint]) -> Set<CGPoint>
func sharedEdges(_ vertices1: [CGPoint], _ vertices2: [CGPoint]) -> Set<String>
```

## Data Model

### Core Types

```swift
struct TangramPiece: Codable, Identifiable {
    let id: String
    let type: PieceType
    var currentTransform: CGAffineTransform
    var connectionIds: [String]
    
    // Computed properties
    var vertices: [CGPoint]     // Transformed vertices
    var edges: [Edge]           // Edge definitions
    var centroid: CGPoint       // Center point
    var boundingBox: CGRect     // For optimization
}

struct Connection: Codable, Identifiable {
    let id: String
    let type: ConnectionType
    let constraint: Constraint
    let createdAt: Date
}

struct TangramPuzzle: Codable {
    let id: String
    var name: String
    var difficulty: Difficulty
    var pieces: [TangramPiece]
    var connections: [Connection]
    var solutionChecksum: String
}
```

## Validation Rules

### Fundamental Principles

1. **No Area Overlaps**: Pieces cannot have interior intersection
2. **All Contacts Declared**: Every geometric touch needs a connection
3. **Graph Connectivity**: All pieces form single connected component
4. **Connections Satisfied**: Declared connections are geometrically valid

### Validation Flow

```swift
func validatePuzzle() -> ValidationResult {
    // Step 1: Check for area overlaps (always invalid)
    if hasInvalidAreaOverlaps() {
        return .invalid(reason: "Pieces have area overlap")
    }
    
    // Step 2: Check for unexplained contacts
    if hasUnexplainedContacts() {
        return .invalid(reason: "Pieces touch without connection")
    }
    
    // Step 3: Check graph connectivity
    if !isConnected() {
        return .invalid(reason: "Not all pieces connected")
    }
    
    // Step 4: Verify all connections are satisfied
    for connection in connections {
        if !isConnectionGeometricallySatisfied(connection) {
            return .invalid(reason: "Connection not satisfied")
        }
    }
    
    return .valid
}
```

## UI Implementation Plan

### Editor Modes

1. **Place Mode**: Add pieces from palette
2. **Connect Mode**: Create connections between pieces
3. **Edit Mode**: Adjust existing connections within constraints
4. **Validate Mode**: Check puzzle validity

### Connection Creation Workflow

1. User selects first piece
2. Highlights available connection points (vertices/edges)
3. User selects connection point
4. User selects second piece
5. Highlights compatible connection points
6. User selects matching point
7. System calculates valid positions
8. User adjusts within constraints (rotation/sliding)
9. Connection validated and saved

### Visual Feedback System

```swift
enum ConnectionPointState {
    case available     // Blue highlight
    case selected      // Yellow highlight
    case connected     // Green highlight
    case invalid       // Red highlight
}

enum ValidationState {
    case valid         // Green border
    case warning       // Yellow border (e.g., disconnected)
    case invalid       // Red border (e.g., overlap)
}
```

### Constraint Visualization

- **Rotation constraints**: Arc showing valid rotation range
- **Translation constraints**: Line showing sliding range
- **Fixed constraints**: Lock icon
- **Multiple constraints**: Stacked indicators

## Testing Strategy

### Unit Tests
- Geometric calculations (overlap, edge detection, vertex matching)
- Connection validation (vertex-to-vertex, edge-to-edge)
- Constraint system (rotation, translation, fixed)
- Graph connectivity algorithms

### Integration Tests
- Full puzzle validation scenarios
- Connection creation and deletion
- Piece transformation with constraints
- Export/import functionality
- Edge cases (multiple connections, complex assemblies)

### Test Migration Plan
Replace confusing old API calls with clear new ones:
```swift
// OLD (confusing)
XCTAssertTrue(hasOverlaps())  // What does this mean?

// NEW (clear)
XCTAssertTrue(hasAreaOverlap("piece1", "piece2"))  // Geometric truth
XCTAssertTrue(hasUnexplainedContacts())            // Semantic validation
XCTAssertTrue(isValidAssembly())                   // Overall validity
```

## Performance Optimizations

- **Bounding box pre-checks**: Quick rejection before detailed checks
- **Vertex caching**: Cache transformed vertices
- **Lazy constraint evaluation**: Only compute when needed
- **Spatial indexing**: For assemblies with many pieces

## Integration with Bemo

### Game Protocol Conformance
```swift
struct TangramEditorGame: Game {
    func makeGameView(delegate: GameDelegate?) -> AnyView
    func processRecognizedPieces(_ pieces: [RecognizedPiece]) -> PlayerActionOutcome
    // Editor doesn't use CV but conforms to protocol
}
```

### Navigation Flow
1. Parent Dashboard → Create Puzzle
2. Editor opens with empty canvas
3. Create/edit puzzle
4. Save to puzzle library
5. Available in game selection

## Future Enhancements

- **AI-assisted creation**: Suggest valid connections
- **Difficulty analysis**: Automatically rate puzzle difficulty
- **Solution hints**: Step-by-step assembly guidance
- **Multiplayer editing**: Collaborative puzzle creation
- **Animation system**: Smooth transitions for solutions
- **Template library**: Pre-built shapes and patterns

## Technical Status

### Core Logic (Phases 1-2) ✅ COMPLETE
- [x] Clean validation system implemented
- [x] Edge connections with different lengths
- [x] Geometric detection methods  
- [x] Semantic validation layer
- [x] All tests migrated to new API
- [x] All deprecated methods removed
- [x] Connection system fully functional
- [x] Engine layer implemented

**Technical Debt:** ZERO (except missing `removeAllPieces()` - 5 min fix)

### UI & Integration (Phases 3-6) 🚧 NOT STARTED
- [ ] TangramEditorGame class
- [ ] SwiftUI interface
- [ ] Visual feedback system
- [ ] Persistence UI
- [ ] Export functionality
- [ ] Game framework integration

## Next Steps

### Immediate (Before Phase 3)
1. Add `removeAllPieces()` method to ConnectionSystem
2. Verify TangramEditorEngine compiles with the fix

### Phase 3: Game Integration
1. Create TangramEditorGame class conforming to Game protocol
2. Wire up makeGameView() to return editor interface
3. Add to game selection in lobby

### Phase 4: Basic UI
1. Create TangramEditorView with piece rendering
2. Create TangramEditorViewModel
3. Implement basic piece selection and movement
4. Show validation status