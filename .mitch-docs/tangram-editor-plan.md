# Tangram Editor Implementation Plan

## Executive Summary

A comprehensive implementation plan for a CAD-like tangram puzzle editor that integrates with Bemo's game framework. The editor enables creation of puzzle targets with precise mathematical validation and constraint-based connections.

## Current Status

### Completed ✅
- Mathematical piece definitions with exact geometry
- Clean three-layer validation system (geometric, connection, semantic)
- Edge connections supporting different lengths (sliding constraints)
- Connection system with vertex and edge connections
- Constraint-based positioning system
- Polygon overlap detection for convex shapes
- Semantic validation distinguishing valid from invalid overlaps

### In Progress ⏳
- Test migration to new validation API
- SwiftUI editor interface

### Pending 📋
- Visual feedback system
- Puzzle persistence and export
- Undo/redo functionality
- Templates and presets

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

## Migration Checklist

- [x] Implement clean validation system
- [x] Support edge connections with different lengths
- [x] Create geometric detection methods
- [x] Build semantic validation layer
- [ ] Migrate all tests to new API
- [ ] Remove deprecated methods
- [ ] Build SwiftUI interface
- [ ] Add visual feedback
- [ ] Implement persistence
- [ ] Create export functionality