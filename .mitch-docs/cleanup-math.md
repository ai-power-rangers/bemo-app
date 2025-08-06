# TangramEditor Coordinate System Cleanup Plan

## Problem Statement

The TangramEditor has coordinate transformation math scattered across multiple files with inconsistent implementations leading to:
- Pieces disappearing or appearing at wrong positions
- Connection points not aligning correctly
- Recentering pushing pieces off-screen
- Difficult to debug and maintain code

## Current Issues

### 1. Multiple Coordinate Systems
- **Normalized Space**: Vertices from `TangramGeometry.vertices()` in 0-2 range
- **World Space**: Scaled by `TangramConstants.visualScale = 50`
- **Screen Space**: After applying `piece.transform` (rotation + translation)

### 2. Inconsistent Scaling
Different files apply scaling at different stages:
- `PieceView.swift`: Scales in `PieceShape.path()` before transform
- `ConnectionService.swift`: Scales before applying transform
- `PiecePlacementService.swift`: Mixed approaches, some recalculating
- `TangramEditorCoordinator.swift`: Was missing scaling (partially fixed)
- `recenterPuzzle()`: Scaling issues causing pieces to disappear

### 3. Transform Application Issues
- `transform.translatedBy()` applies in rotated coordinate space (wrong!)
- Need to set `tx/ty` directly for world-space translation
- Connection point alignment requires complex vector math repeated in multiple places

## Proposed Solution

### New File: `TangramCoordinateSystem.swift`

**Location**: `/Bemo/Features/Game/Games/TangramEditor/Services/TangramCoordinateSystem.swift`

```swift
//
//  TangramCoordinateSystem.swift
//  Bemo
//
//  Centralized coordinate system transformations for TangramEditor
//

import Foundation
import CoreGraphics

/// Single source of truth for all coordinate transformations in TangramEditor
class TangramCoordinateSystem {
    
    // MARK: - Basic Transformations
    
    /// Convert from normalized (0-2) to world coordinates (scaled)
    static func normalizedToWorld(_ point: CGPoint) -> CGPoint {
        return CGPoint(x: point.x * TangramConstants.visualScale,
                      y: point.y * TangramConstants.visualScale)
    }
    
    /// Convert array of normalized points to world coordinates
    static func normalizedToWorld(_ points: [CGPoint]) -> [CGPoint] {
        return points.map { normalizedToWorld($0) }
    }
    
    // MARK: - Piece Geometry
    
    /// Get world-space vertices for a piece type (scaled but not transformed)
    static func getWorldVertices(for type: PieceType) -> [CGPoint] {
        return normalizedToWorld(TangramGeometry.vertices(for: type))
    }
    
    /// Get fully transformed vertices for a piece (for rendering/hit testing)
    static func getTransformedVertices(for piece: TangramPiece) -> [CGPoint] {
        let worldVertices = getWorldVertices(for: piece.type)
        return worldVertices.map { $0.applying(piece.transform) }
    }
    
    /// Get world-space edge midpoints for a piece type
    static func getWorldEdgeMidpoints(for type: PieceType) -> [CGPoint] {
        let worldVertices = getWorldVertices(for: type)
        let edges = TangramGeometry.edges(for: type)
        
        return edges.map { edge in
            let start = worldVertices[edge.startVertex]
            let end = worldVertices[edge.endVertex]
            return CGPoint(x: (start.x + end.x) / 2,
                         y: (start.y + end.y) / 2)
        }
    }
    
    // MARK: - Connection Points
    
    /// Calculate all connection points for a piece in screen space
    static func getConnectionPoints(for piece: TangramPiece) -> [PiecePlacementService.ConnectionPoint] {
        let transformedVertices = getTransformedVertices(for: piece)
        var points: [PiecePlacementService.ConnectionPoint] = []
        
        // Add vertex connection points
        for (index, vertex) in transformedVertices.enumerated() {
            points.append(PiecePlacementService.ConnectionPoint(
                type: .vertex(index: index),
                position: vertex,
                pieceId: piece.id
            ))
        }
        
        // Add edge midpoint connection points
        for i in 0..<transformedVertices.count {
            let start = transformedVertices[i]
            let end = transformedVertices[(i + 1) % transformedVertices.count]
            let midpoint = CGPoint(x: (start.x + end.x) / 2,
                                  y: (start.y + end.y) / 2)
            points.append(PiecePlacementService.ConnectionPoint(
                type: .edge(index: i),
                position: midpoint,
                pieceId: piece.id
            ))
        }
        
        return points
    }
    
    /// Get local connection point position for a piece type (not transformed)
    static func getLocalConnectionPoint(
        for type: PieceType,
        connectionType: PiecePlacementService.ConnectionPoint.PointType
    ) -> CGPoint {
        let worldVertices = getWorldVertices(for: type)
        
        switch connectionType {
        case .vertex(let index):
            return worldVertices[index]
            
        case .edge(let index):
            let edges = TangramGeometry.edges(for: type)
            let edge = edges[index]
            let start = worldVertices[edge.startVertex]
            let end = worldVertices[edge.endVertex]
            return CGPoint(x: (start.x + end.x) / 2,
                         y: (start.y + end.y) / 2)
        }
    }
    
    // MARK: - Transform Creation
    
    /// Create a transform with rotation and translation (applies translation in world space)
    static func createTransform(rotation: Double, translation: CGPoint) -> CGAffineTransform {
        var transform = CGAffineTransform.identity
        transform = transform.rotated(by: rotation)
        // Set translation directly in world space (not using translatedBy)
        transform.tx = translation.x
        transform.ty = translation.y
        return transform
    }
    
    /// Create transform for centering a piece at a point
    static func createCenteringTransform(
        type: PieceType,
        center: CGPoint,
        rotation: Double = 0
    ) -> CGAffineTransform {
        // Get bounding box of world vertices
        let worldVertices = getWorldVertices(for: type)
        let minX = worldVertices.map { $0.x }.min() ?? 0
        let maxX = worldVertices.map { $0.x }.max() ?? 0
        let minY = worldVertices.map { $0.y }.min() ?? 0
        let maxY = worldVertices.map { $0.y }.max() ?? 0
        
        let pieceCenter = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        
        // Create transform that centers piece then rotates
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: center.x, y: center.y)
        transform = transform.rotated(by: rotation)
        transform = transform.translatedBy(x: -pieceCenter.x, y: -pieceCenter.y)
        
        return transform
    }
    
    // MARK: - Piece Alignment
    
    /// Calculate transform to align a piece with connection points
    static func calculateAlignmentTransform(
        pieceType: PieceType,
        baseRotation: Double,
        connections: [(canvas: PiecePlacementService.ConnectionPoint, 
                      piece: PiecePlacementService.ConnectionPoint)]
    ) -> CGAffineTransform {
        
        guard !connections.isEmpty else {
            return CGAffineTransform.identity
        }
        
        // Get local positions for the piece's connection points
        var localPositions: [CGPoint] = []
        for conn in connections {
            localPositions.append(getLocalConnectionPoint(for: pieceType, 
                                                         connectionType: conn.piece.type))
        }
        
        if connections.count == 1 {
            // Single point alignment: rotate then translate to match
            let rotationTransform = CGAffineTransform.identity.rotated(by: baseRotation)
            let rotatedLocal = localPositions[0].applying(rotationTransform)
            
            let translation = CGPoint(
                x: connections[0].canvas.position.x - rotatedLocal.x,
                y: connections[0].canvas.position.y - rotatedLocal.y
            )
            
            return createTransform(rotation: baseRotation, translation: translation)
            
        } else if connections.count >= 2 {
            // Two-point alignment: calculate rotation to align vectors, then translate
            
            // Calculate vectors between connection points
            let canvasVector = CGVector(
                dx: connections[1].canvas.position.x - connections[0].canvas.position.x,
                dy: connections[1].canvas.position.y - connections[0].canvas.position.y
            )
            
            let localVector = CGVector(
                dx: localPositions[1].x - localPositions[0].x,
                dy: localPositions[1].y - localPositions[0].y
            )
            
            // Calculate rotation needed to align vectors
            let angleAdjustment = atan2(canvasVector.dy, canvasVector.dx) - 
                                 atan2(localVector.dy, localVector.dx)
            
            let finalRotation = baseRotation + angleAdjustment
            
            // Apply rotation and calculate translation
            let rotationTransform = CGAffineTransform.identity.rotated(by: finalRotation)
            let rotatedLocal = localPositions[0].applying(rotationTransform)
            
            let translation = CGPoint(
                x: connections[0].canvas.position.x - rotatedLocal.x,
                y: connections[0].canvas.position.y - rotatedLocal.y
            )
            
            return createTransform(rotation: finalRotation, translation: translation)
        }
        
        return CGAffineTransform.identity
    }
    
    // MARK: - Bounding Box
    
    /// Calculate bounding box for a piece
    static func getBoundingBox(for piece: TangramPiece) -> (min: CGPoint, max: CGPoint) {
        let vertices = getTransformedVertices(for: piece)
        
        let minX = vertices.map { $0.x }.min() ?? 0
        let maxX = vertices.map { $0.x }.max() ?? 0
        let minY = vertices.map { $0.y }.min() ?? 0
        let maxY = vertices.map { $0.y }.max() ?? 0
        
        return (CGPoint(x: minX, y: minY), CGPoint(x: maxX, y: maxY))
    }
    
    /// Calculate bounding box for multiple pieces
    static func getBoundingBox(for pieces: [TangramPiece]) -> (min: CGPoint, max: CGPoint)? {
        guard !pieces.isEmpty else { return nil }
        
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        for piece in pieces {
            let vertices = getTransformedVertices(for: piece)
            for vertex in vertices {
                minX = min(minX, vertex.x)
                maxX = max(maxX, vertex.x)
                minY = min(minY, vertex.y)
                maxY = max(maxY, vertex.y)
            }
        }
        
        return (CGPoint(x: minX, y: minY), CGPoint(x: maxX, y: maxY))
    }
    
    /// Calculate center point of pieces
    static func getCenter(of pieces: [TangramPiece]) -> CGPoint? {
        guard let bounds = getBoundingBox(for: pieces) else { return nil }
        return CGPoint(x: (bounds.min.x + bounds.max.x) / 2,
                      y: (bounds.min.y + bounds.max.y) / 2)
    }
}
```

## Files to Update

### 1. **PieceView.swift**
**Changes**: Update `PieceShape` to use `TangramCoordinateSystem`

```swift
struct PieceShape: Shape {
    let type: PieceType
    
    func path(in rect: CGRect) -> Path {
        let worldVertices = TangramCoordinateSystem.getWorldVertices(for: type)
        var path = Path()
        
        if let first = worldVertices.first {
            path.move(to: first)
            for vertex in worldVertices.dropFirst() {
                path.addLine(to: vertex)
            }
            path.closeSubpath()
        }
        
        return path
    }
}
```

### 2. **PiecePlacementService.swift**
**Changes**: Simplify to use centralized coordinate system

```swift
func placeFirstPiece(type: PieceType, rotation: Double, canvasSize: CGSize) -> TangramPiece {
    let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
    let transform = TangramCoordinateSystem.createCenteringTransform(
        type: type,
        center: center,
        rotation: rotation
    )
    return TangramPiece(type: type, transform: transform)
}

func placeConnectedPiece(
    type: PieceType,
    rotation: Double,
    connections: [(canvasPoint: ConnectionPoint, piecePoint: ConnectionPoint)],
    existingPieces: [TangramPiece]
) -> TangramPiece? {
    guard !connections.isEmpty else { return nil }
    
    let transform = TangramCoordinateSystem.calculateAlignmentTransform(
        pieceType: type,
        baseRotation: rotation,
        connections: connections.map { (canvas: $0.canvasPoint, piece: $0.piecePoint) }
    )
    
    return TangramPiece(type: type, transform: transform)
}

func getConnectionPoints(for piece: TangramPiece, scale: CGFloat = 1) -> [ConnectionPoint] {
    return TangramCoordinateSystem.getConnectionPoints(for: piece)
}
```

### 3. **ConnectionService.swift**
**Changes**: Use centralized vertex calculations

```swift
private func calculateConstraint(for connectionType: ConnectionType, pieces: [TangramPiece]) -> Constraint? {
    switch connectionType {
    case .vertexToVertex(let pieceAId, let vertexA, let pieceBId, let vertexB):
        guard let pieceA = pieces.first(where: { $0.id == pieceAId }),
              let pieceB = pieces.first(where: { $0.id == pieceBId }) else { 
            return nil 
        }
        
        let verticesA = TangramCoordinateSystem.getTransformedVertices(for: pieceA)
        let verticesB = TangramCoordinateSystem.getTransformedVertices(for: pieceB)
        
        // Rest of logic...
    }
}

func isConnectionSatisfied(_ connection: Connection, pieces: [TangramPiece]) -> Bool {
    // Use TangramCoordinateSystem.getTransformedVertices instead of manual scaling
}
```

### 4. **TangramEditorCoordinator.swift**
**Changes**: Remove duplicate coordinate math

```swift
func validatePiecePlacement(piece: TangramPiece, existingPieces: [TangramPiece]) -> Bool {
    let pieceVertices = TangramCoordinateSystem.getTransformedVertices(for: piece)
    
    for existing in existingPieces {
        let existingVertices = TangramCoordinateSystem.getTransformedVertices(for: existing)
        if geometryService.polygonsOverlap(pieceVertices, existingVertices) {
            return false
        }
    }
    
    return true
}
```

### 5. **TangramEditorViewModel.swift**
**Changes**: Simplify recenterPuzzle and other coordinate operations

```swift
func recenterPuzzle() {
    guard !puzzle.pieces.isEmpty else { return }
    guard currentCanvasSize.width > 0 && currentCanvasSize.height > 0 else { return }
    
    // Use centralized bounding box calculation
    guard let currentCenter = TangramCoordinateSystem.getCenter(of: puzzle.pieces) else { return }
    
    let targetCenter = CGPoint(x: currentCanvasSize.width / 2, 
                              y: currentCanvasSize.height / 2)
    let dx = targetCenter.x - currentCenter.x
    let dy = targetCenter.y - currentCenter.y
    
    // Apply translation to all pieces
    for i in 0..<puzzle.pieces.count {
        var transform = puzzle.pieces[i].transform
        transform.tx += dx
        transform.ty += dy
        puzzle.pieces[i].transform = transform
    }
}

func getConnectionPoints(for pieceId: String) -> [ConnectionPoint] {
    guard let piece = puzzle.pieces.first(where: { $0.id == pieceId }) else {
        return []
    }
    return TangramCoordinateSystem.getConnectionPoints(for: piece)
}
```

### 6. **ValidationService.swift**
**Changes**: Use centralized coordinate system

```swift
private func checkOverlaps(pieces: [TangramPiece]) -> [ValidationIssue] {
    var issues: [ValidationIssue] = []
    
    for i in 0..<pieces.count {
        let verticesI = TangramCoordinateSystem.getTransformedVertices(for: pieces[i])
        
        for j in (i+1)..<pieces.count {
            let verticesJ = TangramCoordinateSystem.getTransformedVertices(for: pieces[j])
            
            if geometryService.polygonsOverlap(verticesI, verticesJ) {
                issues.append(.overlappingPieces(pieces[i].id, pieces[j].id))
            }
        }
    }
    
    return issues
}
```

### 7. **GeometryService.swift**
**Changes**: Remove coordinate transformation methods (moved to TangramCoordinateSystem)

- Remove `transformVertices` method (use `TangramCoordinateSystem.getTransformedVertices`)
- Keep pure geometry methods (distance, angles, overlap detection, etc.)

## Implementation Steps

### Phase 1: Create Foundation
1. Create `TangramCoordinateSystem.swift` with all methods
2. Add comprehensive unit tests for coordinate transformations
3. Verify all transformation math is correct

### Phase 2: Update Core Services
1. Update `PiecePlacementService.swift` to use new system
2. Update `ConnectionService.swift` 
3. Update `ValidationService.swift`
4. Clean up `GeometryService.swift`

### Phase 3: Update UI Components
1. Update `PieceView.swift` and `PieceShape`
2. Update `PendingPieceView.swift`
3. Update connection point rendering

### Phase 4: Update ViewModels
1. Update `TangramEditorViewModel.swift`
2. Update `TangramEditorCoordinator.swift`
3. Remove all duplicate coordinate math

### Phase 5: Testing & Cleanup
1. Test all piece placement scenarios
2. Test multi-point connections
3. Test recentering
4. Remove debug logging
5. Document the coordinate system

## Benefits

1. **Single Source of Truth**: All coordinate math in one place
2. **Consistency**: Same transformations applied everywhere
3. **Maintainability**: Fix bugs in one location
4. **Testability**: Unit test transformations independently
5. **Performance**: Avoid redundant calculations
6. **Clarity**: Clear API with descriptive method names
7. **Debugging**: Easier to trace coordinate issues

## Testing Strategy

### Unit Tests for TangramCoordinateSystem
- Test normalized to world conversion
- Test transform creation
- Test single-point alignment
- Test two-point alignment
- Test bounding box calculations
- Test edge cases (identity transforms, zero rotations, etc.)

### Integration Tests
- Test piece placement workflows
- Test connection validation
- Test recentering with multiple pieces
- Test undo/redo with transforms

## Success Criteria

1. No pieces disappear when placed or recentered
2. Connection points align correctly for all connection types
3. Recentering keeps all pieces visible on canvas
4. Transform calculations are consistent across all features
5. Code is more maintainable with less duplication
6. All existing functionality continues to work

## Estimated Effort

- **Creating TangramCoordinateSystem**: 2-3 hours
- **Updating existing files**: 3-4 hours  
- **Testing and debugging**: 2-3 hours
- **Total**: 7-10 hours

## Risk Mitigation

1. **Keep old code during transition**: Don't delete until new system is proven
2. **Incremental updates**: Update one service at a time
3. **Comprehensive testing**: Test each change thoroughly
4. **Version control**: Commit after each successful phase
5. **Fallback plan**: Can revert if issues arise

## Long-term Maintenance

Once implemented, any future coordinate-related bugs or features should:
1. First check if `TangramCoordinateSystem` needs updating
2. Add new methods to the centralized system if needed
3. Never add coordinate math outside of this system
4. Always use the provided API methods
5. Add tests for any new coordinate transformations