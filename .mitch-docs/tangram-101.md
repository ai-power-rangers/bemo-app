# Tangram 101: Mathematical Foundation and Rules

## The Seven Tangram Pieces

The traditional tangram puzzle consists of **7 geometric pieces** that can be arranged to form countless shapes. All pieces are derived from a square with area 8 square units.

### Piece Specifications

#### 1. Small Triangle (2 pieces)
- **Vertices**: (0,0), (1,0), (0,1)
- **Edge Lengths**: 1, 1, √2
- **Area**: 0.5 square units
- **Angles**: 90°, 45°, 45°
- **Properties**: Right isosceles triangle, smallest piece

#### 2. Medium Triangle (1 piece)
- **Vertices**: (0,0), (√2,0), (0,√2)
- **Edge Lengths**: √2, √2, 2
- **Area**: 1 square unit
- **Angles**: 90°, 45°, 45°
- **Properties**: Right isosceles triangle, twice the area of small triangle

#### 3. Large Triangle (2 pieces)
- **Vertices**: (0,0), (2,0), (0,2)
- **Edge Lengths**: 2, 2, 2√2
- **Area**: 2 square units
- **Angles**: 90°, 45°, 45°
- **Properties**: Right isosceles triangle, four times the area of small triangle

#### 4. Square (1 piece)
- **Vertices**: (0,0), (1,0), (1,1), (0,1)
- **Edge Lengths**: 1, 1, 1, 1
- **Area**: 1 square unit
- **Angles**: 90°, 90°, 90°, 90°
- **Properties**: Only piece with all equal sides and angles

#### 5. Parallelogram (1 piece)
- **Vertices**: (0,0), (√2,0), (√2/2,√2/2), (-√2/2,√2/2)
- **Edge Lengths**: √2, 1, √2, 1
- **Area**: 1 square unit
- **Angles**: 45°, 135°, 45°, 135°
- **Properties**: Only non-right-angle quadrilateral, can be flipped

### Mathematical Relationships

#### Area Conservation
- Total area: 8 square units
- 2 × Small Triangle (0.5) + 1 × Medium Triangle (1) + 2 × Large Triangle (2) + 1 × Square (1) + 1 × Parallelogram (1) = 8

#### Edge Length Relationships
- **Unit length (1)**: Small triangle legs, square sides, parallelogram short sides
- **√2 length**: Small triangle hypotenuse, medium triangle legs, parallelogram long sides
- **2 length**: Medium triangle hypotenuse, large triangle legs
- **2√2 length**: Large triangle hypotenuse

#### Scaling Relationships
- Medium triangle = 2 × Small triangle (by area)
- Large triangle = 4 × Small triangle (by area)
- Large triangle = 2 × Medium triangle (by area)
- All triangles are similar (same angles, proportional sides)

## Tangram Assembly Rules

### Fundamental Validation Principles

#### Geometric Relationships
1. **Area Overlap**: Interior intersection of pieces - ALWAYS INVALID
2. **Edge Contact**: Pieces sharing part or all of an edge - VALID only with connection
3. **Vertex Contact**: Pieces touching at a single point - VALID only with connection
4. **No Contact**: Pieces not touching - INVALID (breaks connectivity)

#### Connection Rules
- **Every contact needs a connection**: Any geometric touching requires a declared connection
- **Connections must be satisfied**: Declared connections must be geometrically valid
- **Graph connectivity**: All pieces must form a single connected component

### Valid Connections

#### 1. Edge-to-Edge Connections
- **Same length edges**: Perfect alignment along entire edge
- **Different length edges**: Shorter edge can slide along longer edge
- **Partial overlap**: A 1-unit edge can connect anywhere along a √2 or 2-unit edge
- **Multiple pieces on one edge**: Several small edges can line up along one large edge
- **Sliding constraint**: Shorter piece can slide along the longer edge
- **Example**: Square's 1-unit edge can slide along medium triangle's √2 edge

#### 2. Vertex-to-Vertex Connections
- **Point contact**: Two or more pieces can share a single vertex
- **Multiple pieces at vertex**: Three or more pieces can meet at one point
- **Rotation freedom**: Pieces can rotate around shared vertex
- **Star configurations**: Many pieces radiating from central point
- **Example**: Three triangles can meet at their 90° vertices

#### 3. Mixed Connections
- **Edge and vertex**: One piece's vertex can touch another's edge midpoint
- **Complex junctions**: Multiple pieces can form intricate connection patterns
- **Constraint stacking**: Multiple connections can fully constrain a piece
- **Example**: Small triangle vertex touching middle of square's edge

### Invalid Configurations

#### 1. Area Overlaps
- **No interior overlap**: Pieces cannot overlap in their interior areas
- **Boundary touching only**: Pieces can only touch at edges or vertices
- **No stacking**: All pieces must lie in the same plane
- **Detection**: Any vertex inside another polygon (excluding boundary)

#### 2. Unexplained Contact
- **Touching without connection**: Pieces that touch geometrically but lack a declared connection
- **Accidental contact**: Unintended edge or vertex alignment
- **Fix**: Add connection declaration or adjust piece positions

#### 3. Disconnected Pieces
- **No floating pieces**: Every piece must connect to at least one other piece
- **Connected graph required**: Path must exist between any two pieces
- **Validation**: Graph traversal from any piece must reach all pieces

### Puzzle Validity Rules

#### Connectivity Requirements
1. **Graph connectivity**: All 7 pieces must form a connected graph
2. **Minimum connections**: Each piece needs at least one connection
3. **Path existence**: There must be a path between any two pieces

#### Geometric Constraints
1. **Planar arrangement**: All pieces lie in a 2D plane
2. **No overlaps**: Only edge and vertex contacts allowed
3. **Exact positioning**: Pieces must align precisely at connection points

#### Assembly Properties
1. **Rotation allowed**: Pieces can be rotated to any angle
2. **Flipping allowed**: Parallelogram can be flipped (mirror image)
3. **Translation freedom**: Assembly can be placed anywhere in the plane

## Common Tangram Patterns

### Connection Patterns
- **Star junction**: Multiple pieces meeting at a central vertex
- **Edge chains**: Sequential edge-to-edge connections
- **Nested arrangements**: Smaller pieces fitting into angles of larger pieces
- **Symmetric assemblies**: Mirror or rotational symmetry using piece pairs

### Structural Elements
- **Right angle formations**: Using the 90° angles of triangles and square
- **Diagonal lines**: Created by aligning hypotenuses
- **Parallel edges**: Using parallelogram with triangles
- **Enclosed spaces**: Creating internal boundaries with piece arrangements

## Mathematical Properties

### Angle Combinations
- All angles are multiples of 45°: 45°, 90°, 135°
- Sum of angles meeting at a vertex must be ≤ 360°
- Right angles can combine to form straight lines (180°)

### Length Ratios
- 1 : √2 : 2 : 2√2 forms the complete length system
- These ratios ensure pieces fit together perfectly
- Based on the diagonal of a unit square (√2)

### Symmetry Properties
- All triangles have one line of symmetry
- Square has four lines of symmetry
- Parallelogram has rotational symmetry (180°)
- Many puzzle solutions exhibit overall symmetry

## Puzzle Categories

### By Complexity
1. **Simple shapes**: Using 2-3 pieces
2. **Standard puzzles**: All 7 pieces forming recognizable shapes
3. **Double tangrams**: Two sets (14 pieces) for complex designs
4. **Partial tangrams**: Using subset of pieces

### By Goal
1. **Silhouette puzzles**: Fill a given outline
2. **Creative puzzles**: Make recognizable objects/animals
3. **Geometric puzzles**: Form specific geometric shapes
4. **Pattern puzzles**: Create repeating patterns

## Historical Context

The tangram originated in China during the Song Dynasty (960-1279) and became popular worldwide in the 19th century. The mathematical precision of the piece relationships has made it a valuable tool for teaching geometry, spatial reasoning, and problem-solving.

The name "tangram" possibly derives from the Cantonese "tang" (Chinese) and the Greek "gramma" (something drawn), though its Chinese name "qiqiaoban" means "seven boards of skill."