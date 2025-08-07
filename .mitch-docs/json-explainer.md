# Tangram Puzzle JSON Storage Format

## Overview
This document explains how Tangram puzzles are saved and stored in JSON format, including the coordinate systems, transformations, and data structures used.

## Coordinate System Architecture

The Tangram system uses a **3-tier coordinate system** to manage piece positions:

### 1. Normalized Space (0-2)
Base geometry definitions for all piece types, defined in `TangramGeometry.swift`:
- **Small triangles**: vertices at (0,0), (1,0), (0,1)
- **Large triangles**: vertices at (0,0), (2,0), (0,2)  
- **Square**: vertices at (0,0), (1,0), (1,1), (0,1)
- **Medium triangle**: vertices at (0,0), (√2,0), (0,√2)
- **Parallelogram**: uses √2 calculations for angled sides

### 2. Visual Space (0-100)
Scaled representation for UI display:
- Applied via `visualScale = 50` constant (defined in `TangramConstants.swift`)
- Conversion: `visual = normalized × 50`
- Example: Small triangle (0,0), (1,0), (0,1) becomes (0,0), (50,0), (0,50)

### 3. World Space
Final transformed positions after rotation and translation:
- Applies `CGAffineTransform` to visual coordinates
- **Origin (0,0) is at the top-left corner of the canvas**
- Positive X goes right, positive Y goes down (standard screen coordinates)

## What Gets Saved

Each `TangramPiece` stores the following data:

```json
{
  "id": "uuid-string",           // Unique identifier
  "type": "smallTriangle1",      // Piece type enum
  "transform": {                 // CGAffineTransform components
    "a": 1.0,                    // cos(rotation) - scale x
    "b": 0.0,                    // sin(rotation) - shear
    "c": 0.0,                    // -sin(rotation) - shear  
    "d": 1.0,                    // cos(rotation) - scale y
    "tx": 400.0,                 // x translation in world space
    "ty": 300.0                  // y translation in world space
  },
  "isLocked": true,              // Editor lock state
  "zIndex": 0,                   // Layer ordering
  "connectionPoints": []         // Array of connections to other pieces
}
```

## Transform Matrix Explained

The `CGAffineTransform` is a 2D transformation matrix that combines rotation, scale, and translation:

```
[x']   [a  c  tx] [x]
[y'] = [b  d  ty] [y]
[1 ]   [0  0  1 ] [1]
```

For a pure rotation by angle θ and translation:
- `a = cos(θ)`, `b = sin(θ)`
- `c = -sin(θ)`, `d = cos(θ)`
- `tx` = horizontal offset from origin (0,0)
- `ty` = vertical offset from origin (0,0)

## Connection Storage

Connections between pieces track how they snap together:

```json
{
  "id": "connection-uuid",
  "type": {
    "vertexToVertex": {
      "pieceAId": "uuid-1",
      "vertexA": 0,              // Index of vertex on piece A
      "pieceBId": "uuid-2", 
      "vertexB": 2               // Index of vertex on piece B
    }
  },
  "constraint": "fixed"           // Connection constraint type
}
```

Connection types:
- `vertexToVertex`: Corner to corner connection
- `edgeToEdge`: Edge alignment (pieces can slide)
- `vertexToEdge`: Corner touches an edge

## Piece Types

Seven standard Tangram pieces (defined in `PieceType.swift`):
1. `smallTriangle1` - First small right triangle
2. `smallTriangle2` - Second small right triangle  
3. `mediumTriangle` - Medium right triangle
4. `largeTriangle1` - First large right triangle
5. `largeTriangle2` - Second large right triangle
6. `square` - Square piece
7. `parallelogram` - Parallelogram piece

## Database Storage (Supabase)

Puzzles are stored in the `tangram_puzzles` table with:
- `pieces`: JSONB array of piece configurations
- `connections`: JSONB array of connection definitions
- `solution_checksum`: Hash of piece positions for validation
- `category`: Puzzle category (animals, objects, etc.)
- `difficulty`: 1-5 difficulty rating

## Key Implementation Details

### Vertices are NOT stored directly
- Vertices are calculated from piece type + transform
- Base geometry is defined once per piece type
- Transform is applied to generate world positions

### Positions are absolute, not relative
- All positions are relative to world origin (0,0) at top-left
- Not relative to other pieces or puzzle center
- First piece typically placed at canvas center (e.g., 400,300)

### Transform captures both rotation AND position
- Single matrix encodes all transformations
- Applied after scaling to visual space
- `tx` and `ty` are in scaled visual coordinates (×50)

### Edge/vertex indices are fixed
- Based on geometry definition order
- Vertices numbered 0,1,2 for triangles (clockwise from origin)
- Edges numbered by starting vertex

## Reconstruction Process

To reconstruct a puzzle from JSON:

1. **Load piece data** - Parse JSON to get types and transforms
2. **Apply geometry** - Get base vertices for each piece type
3. **Scale to visual** - Multiply coordinates by 50
4. **Apply transforms** - Use CGAffineTransform to position pieces
5. **Validate connections** - Check piece relationships

## Example: Small Triangle at Canvas Center

For a small triangle placed at canvas center (400, 300) with 45° rotation:

```json
{
  "type": "smallTriangle1",
  "transform": {
    "a": 0.707,    // cos(45°)
    "b": 0.707,    // sin(45°)
    "c": -0.707,   // -sin(45°)
    "d": 0.707,    // cos(45°)
    "tx": 400.0,   // Center x
    "ty": 300.0    // Center y
  }
}
```

The piece's vertices in world space would be:
1. Local (0,0) × 50 = (0,0) → rotated → translated to (400, 300)
2. Local (1,0) × 50 = (50,0) → rotated → translated relative to first vertex
3. Local (0,1) × 50 = (0,50) → rotated → translated relative to first vertex

## File References

Key implementation files:
- `TangramPuzzleData.swift` - Main puzzle data model
- `TangramPieceData.swift` - Individual piece data model  
- `TangramGeometry.swift` - Piece geometry definitions
- `TangramCoordinateSystem.swift` - Coordinate transformations
- `TangramConstants.swift` - Scaling factors and constants
- `TangramEditorViewModel+Persistence.swift` - Save/load logic
- `20250806153407_tangram_puzzles_storage.sql` - Database schema