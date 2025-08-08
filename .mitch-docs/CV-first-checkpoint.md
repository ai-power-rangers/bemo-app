# CV-First Checkpoint: Tangram Game Transformation Plan

## Executive Summary

This plan transforms the Tangram game to simulate the physical world experience where users build puzzles on a "table" (middle zone), exactly as they would with physical pieces under a CV camera. Every action generates CV-formatted output, and validation uses relative positioning with dynamic anchor management.

## Definitive Implementation Decisions

### 1. CV↔Game Type Mapping (LOCKED)
```swift
enum TangramPieceType: String {
    case square, smallTriangle1, smallTriangle2, mediumTriangle, 
         largeTriangle1, largeTriangle2, parallelogram
}

// Immutable mapping - NEVER change
func mapCVNameToType(_ name: String) -> TangramPieceType? {
    switch name {
    case "tangram_square":         return .square
    case "tangram_triangle_sml":   return .smallTriangle1  // Red small triangle
    case "tangram_triangle_sml2":  return .smallTriangle2  // Blue small triangle  
    case "tangram_triangle_med":   return .mediumTriangle
    case "tangram_triangle_lrg":   return .largeTriangle1  // Green large triangle
    case "tangram_triangle_lrg2":  return .largeTriangle2  // Yellow large triangle
    case "tangram_parallelogram":  return .parallelogram
    default: return nil
    }
}
```

### 2. Coordinate System Contract
- **Internal Math**: Always Y-up, radians CCW, normalized units
- **CV Input**: Post-homography table plane coordinates, Y-up, degrees CCW
- **SpriteKit Render**: Y-down conversion ONLY at draw time (zRotation is radians CCW)
- **Single Conversion Point**: All transforms happen in `CVToInternalConverter`
- **Angle Direction**: All rotations are counter-clockwise positive in their respective coordinate systems

### 3. Scale Normalization
- **Canonical Unit**: Square side = 1.0
- **All pieces scaled relative to square**
- **Similarity alignment** during validation for scale/rotation invariance

### 4. Symmetry Rules (FIXED)
```swift
func getRotationalSymmetry(for type: TangramPieceType) -> Double {
    switch type {
    case .square: return 90.0          // 4-fold symmetry
    case .smallTriangle1, .smallTriangle2, 
         .mediumTriangle, .largeTriangle1, 
         .largeTriangle2: return 180.0  // 2-fold symmetry
    case .parallelogram: return 360.0   // No rotational symmetry
    }
}
```

### 5. Parallelogram Flip Detection
```swift
func isFlipped(transform: CGAffineTransform) -> Bool {
    let determinant = transform.a * transform.d - transform.b * transform.c
    return determinant < 0  // Negative = flipped
}
```

### 6. Tolerance Values (Normalized Units)
```swift
struct ValidationTolerance {
    let position: Double  // In square-side units
    let rotation: Double  // In degrees
    
    static let easy = ValidationTolerance(position: 0.40, rotation: 15.0)
    static let standard = ValidationTolerance(position: 0.25, rotation: 10.0)
    static let precise = ValidationTolerance(position: 0.15, rotation: 5.0)
    static let expert = ValidationTolerance(position: 0.08, rotation: 3.0)
}
```

### 7. CV Stream Configuration
- **Emission Rate**: Max 20Hz (50ms minimum between updates)
- **Settle Time**: 200ms after piece drop before validation
- **Schema Version**: All JSON includes `"schema_version": 1`
- **Object IDs**: Each piece has stable `object_id` field

### 8. Anchor Management Policy
- **Touch Mode**: First piece placed = anchor
- **CV Mode**: Largest piece with hysteresis (avoid flicker)
- **Removal**: Next oldest/largest piece promotes
- **Forced Anchor**: Optional override for testing

### 9. Camera Inversion
- **Setup Toggle**: `isCameraInverted` configuration flag
- **Not Auto-Detected**: Manual setting based on hardware setup
- **Default**: false (normal orientation)

### 10. Vertex Ordering
- **Contract**: CV outputs vertices clockwise from canonical corner
- **Enforcement**: Single reordering function if needed
- **Canonical Corner**: Top-left for squares, right-angle vertex for triangles

## Core Concept: Physical World Simulation

### Three-Zone Layout
1. **Top 1/3**: Reference puzzle display (read-only, shows target arrangement)
2. **Middle 1/3**: Assembly area ("physical table" where CV would look)
3. **Bottom 1/3**: Piece storage (scattered pieces, initial state)

### Key Paradigm Shift
- **NOT** placing pieces on top of a target
- **Building** freely in the assembly area
- **First piece placed** becomes initial anchor point
- **Dynamic anchor promotion** if anchor is removed
- All validation is **relative** to current anchor
- Simulates exactly what CV sees in physical world

## Current State Analysis

### What We Have ✅
1. **Fully functional drag/drop/rotate/flip gameplay** (`TangramPuzzleScene.swift`)
   - Touch-based piece manipulation (lines 273-513)
   - Rotation dial for precise rotation (lines 816-853)
   - Flip functionality for parallelogram
   - ~~Visual feedback and snap preview~~ (TO BE REMOVED)

2. **Absolute position validation** (`TangramPieceValidator.swift`)
   - ~~Position tolerance: 35 pixels~~ (TO BE RELATIVE)
   - ~~Rotation tolerance: 4 degrees~~ (TO BE RELATIVE)
   - Transform-based validation with flip detection

3. **Transform-based coordinate system**
   - 3-tier: Normalized (0-2) → Visual (0-100) → World (screen pixels)
   - CGAffineTransform for piece positioning
   - SpriteKit integration with Y-axis flipped

4. **Hint system with relative positioning concepts** (`TangramHintEngine.swift`)
   - Already considers piece relationships
   - Progressive hint difficulty
   - ~~Animation-based guidance~~ (TO BE UPDATED)

### What Needs to Change ❌
1. **Remove ALL snap-to-target behavior**
2. **Three-zone layout implementation**
3. **Dynamic anchor system (first-placed, then promotes)**
4. **Relative position map comparison**
5. **CV output stream for EVERY action**
6. **No absolute position validation**

## Architecture Overview

```
Bottom Zone (Piece Storage - Scattered)
    ↓ [User drags piece up]
Middle Zone (Assembly Area - "Physical Table")
    ↓ [First piece placed = initial anchor]
    ↓ [If anchor removed, next piece promotes to anchor]
    ↓ [All pieces positioned relative to current anchor]
    ↓ [Generate CV output on every action]
    ↓
CV Format Output Stream
    ↓
Relative Position Map (User's Assembly)
    ↓ [Compare maps]
Relative Position Map (Target Puzzle)
    ↓
Validation Result (pieces correct/incorrect)
    ↑
Top Zone (Reference Display - Visual Guide Only)
```

## Implementation Plan

### Phase 1: Three-Zone Layout System (Priority: CRITICAL)

#### 1.1 Create Three-Zone Scene Layout

```swift
// Location: Bemo/Features/Game/Games/Tangram/Views/TangramThreeZoneScene.swift

class TangramThreeZoneScene: SKScene {
    // Zone definitions
    private var referenceZone: SKNode!     // Top 1/3 - shows target
    private var assemblyZone: SKNode!      // Middle 1/3 - "physical table"
    private var storageZone: SKNode!       // Bottom 1/3 - scattered pieces
    
    // Assembly tracking
    private var anchorPiece: PuzzlePieceNode?  // First piece placed
    private var assembledPieces: [PuzzlePieceNode] = []
    private var cvOutputStream: [String: Any] = [:]
    
    override func didMove(to view: SKView) {
        setupZones()
        loadReferenceDisplay()
        scatterPiecesInStorage()
    }
    
    private func setupZones() {
        let zoneHeight = size.height / 3
        
        // Top zone - Reference display (non-interactive)
        referenceZone = SKNode()
        referenceZone.position = CGPoint(x: 0, y: size.height * 2/3)
        addChild(referenceZone)
        
        // Middle zone - Assembly area (main interaction zone)
        assemblyZone = SKNode()
        assemblyZone.position = CGPoint(x: 0, y: size.height * 1/3)
        addChild(assemblyZone)
        
        // Add visual boundary for assembly zone
        let assemblyBoundary = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: zoneHeight))
        assemblyBoundary.strokeColor = .systemBlue.withAlphaComponent(0.3)
        assemblyBoundary.lineWidth = 2
        assemblyBoundary.lineDashPattern = [10, 5]
        assemblyZone.addChild(assemblyBoundary)
        
        // Bottom zone - Storage area
        storageZone = SKNode()
        storageZone.position = CGPoint(x: 0, y: 0)
        addChild(storageZone)
    }
}
```

#### 1.2 Dynamic Anchor System with Promotion

```swift
extension TangramThreeZoneScene {
    
    /// Handle piece placement in assembly zone
    private func handlePiecePlacement(_ piece: PuzzlePieceNode, at position: CGPoint) {
        // Check if piece is in assembly zone
        guard isInAssemblyZone(position) else { return }
        
        // First piece becomes the initial anchor
        if anchorPiece == nil && !assembledPieces.isEmpty {
            promoteNewAnchor()
        } else if anchorPiece == nil {
            setAsAnchor(piece)
        }
        
        // Add to assembled pieces
        if !assembledPieces.contains(piece) {
            assembledPieces.append(piece)
        }
        
        // Generate CV output immediately
        generateCVOutputStream()
    }
    
    /// Handle piece removal from assembly zone
    private func handlePieceRemoval(_ piece: PuzzlePieceNode) {
        // Remove from assembled pieces
        assembledPieces.removeAll { $0 == piece }
        
        // If this was the anchor, promote a new one
        if piece == anchorPiece {
            anchorPiece = nil
            piece.isAnchor = false
            removeAnchorIndicator(from: piece)
            
            // Promote new anchor if pieces remain
            if !assembledPieces.isEmpty {
                promoteNewAnchor()
            }
        }
        
        // Regenerate CV output with new anchor
        generateCVOutputStream()
    }
    
    /// Promote a new anchor from existing pieces with hysteresis
    private func promoteNewAnchor() {
        // For CV mode: use largest piece with hysteresis
        // For touch mode: use oldest piece (first placed)
        
        let newAnchor: PuzzlePieceNode?
        if isCVMode {
            // Find largest piece that has been stable for N frames
            newAnchor = assembledPieces
                .filter { hasBeenStableForFrames($0, frames: 5) }  // Require 5 stable frames
                .max { p1, p2 in
                    getPieceArea(p1.pieceType) < getPieceArea(p2.pieceType)
                }
        } else {
            // Touch mode: oldest piece (first in array)
            newAnchor = assembledPieces.first
        }
        
        if let newAnchor = newAnchor {
            setAsAnchor(newAnchor)
            print("🔄 Anchor promoted to: \(newAnchor.pieceType?.rawValue ?? "unknown")")
        }
    }
    
    /// Check if piece has been stable for N frames (prevents anchor thrashing)
    private func hasBeenStableForFrames(_ piece: PuzzlePieceNode, frames: Int) -> Bool {
        guard let stability = pieceStabilityFrames[piece.id ?? ""] else { return false }
        return stability >= frames
    }
    
    /// Set a piece as the anchor
    private func setAsAnchor(_ piece: PuzzlePieceNode) {
        // Clear any existing anchor
        if let oldAnchor = anchorPiece {
            oldAnchor.isAnchor = false
            removeAnchorIndicator(from: oldAnchor)
        }
        
        // Set new anchor
        anchorPiece = piece
        piece.isAnchor = true
        
        // Visual feedback for anchor
        let anchorIndicator = SKShapeNode(circleOfRadius: 5)
        anchorIndicator.fillColor = .systemGreen
        anchorIndicator.position = .zero
        anchorIndicator.name = "anchorIndicator"
        piece.addChild(anchorIndicator)
        
        print("🎯 Anchor established: \(piece.pieceType?.rawValue ?? "unknown")")
    }
    
    private func removeAnchorIndicator(from piece: PuzzlePieceNode) {
        piece.childNode(withName: "anchorIndicator")?.removeFromParent()
    }
    
    private func isInAssemblyZone(_ position: CGPoint) -> Bool {
        let zoneHeight = size.height / 3
        return position.y >= zoneHeight && position.y < zoneHeight * 2
    }
}
```

### Phase 2: CV Output Stream Generator (Priority: CRITICAL)

#### 2.1 Single-Boundary CV Conversion

```swift
// Location: Bemo/Features/Game/Games/Tangram/Services/CVToInternalConverter.swift

/**
 * CVToInternalConverter - Single boundary for CV↔Internal coordinate conversion
 * 
 * ============================================================================
 * COORDINATE SYSTEM CONTRACT (LOCKED):
 * ============================================================================
 * - Rotations: Counter-clockwise positive (CCW+)
 * - CV Input: Y-up coordinate system, degrees
 * - Internal: Y-up coordinate system, radians  
 * - Units: Normalized to square side = 1.0
 * - SpriteKit: Y-down at render only, zRotation is radians CCW
 * 
 * ============================================================================
 * HOMOGRAPHY HANDLING POLICY:
 * ============================================================================
 * - CV coordinates assumed POST-homography (table-plane aligned)
 * - If "homography_applied": false, we apply the provided matrix
 * - If "homography_applied": true or missing, coordinates used as-is
 * - Non-identity matrix presence alone is NOT an error
 * 
 * ============================================================================
 * SCALE CALIBRATION PRECEDENCE:
 * ============================================================================
 * 1. Square vertices (most reliable) → direct measurement
 * 2. Large triangle leg → equals square side
 * 3. Medium triangle leg → multiply by √2
 * 4. Small triangle leg → multiply by 2
 * - Calibration cached in UserDefaults for session persistence
 * 
 * ============================================================================
 * VERTEX CANONICALIZATION:
 * ============================================================================
 * - Square/Parallelogram: Start from min(y), then min(x), order clockwise
 * - Triangles: Start from right-angle vertex (opposite hypotenuse), order clockwise
 * - Applied to ALL pieces before any flip/rotation detection
 * 
 * ============================================================================
 * CONFIGURATION:
 * ============================================================================
 * - Camera Inversion: Manual toggle via isCameraInverted (persisted)
 * - Difficulty Level: Persisted in UserDefaults
 * - Scale Calibration: Persisted in UserDefaults
 * 
 * Schema Version: 1
 */
class CVToInternalConverter {
    
    // Configuration - all persisted in UserDefaults
    var isCameraInverted: Bool {
        get { UserDefaults.standard.bool(forKey: "camera_inverted") }
        set { UserDefaults.standard.set(newValue, forKey: "camera_inverted") }
    }
    
    private var squareSideInCV: Double {
        get { 
            UserDefaults.standard.double(forKey: "cv_square_scale") != 0 
                ? UserDefaults.standard.double(forKey: "cv_square_scale") 
                : 1.0  // Default if not calibrated
        }
        set { UserDefaults.standard.set(newValue, forKey: "cv_square_scale") }
    }
    
    /// Calibrate scale from CV data with fallback to other pieces
    func calibrateScale(from cvData: [String: Any]) {
        guard let objects = cvData["objects"] as? [[String: Any]], !objects.isEmpty else { return }
        
        // Try square first (most reliable)
        if let square = objects.first(where: { ($0["name"] as? String) == "tangram_square" }),
           let vertices = square["vertices"] as? [[Double]], vertices.count >= 4 {
            let side1 = hypot(vertices[1][0] - vertices[0][0], vertices[1][1] - vertices[0][1])
            let side2 = hypot(vertices[2][0] - vertices[1][0], vertices[2][1] - vertices[1][1])
            squareSideInCV = (side1 + side2) / 2.0
            UserDefaults.standard.set(squareSideInCV, forKey: "cv_square_scale")
            return
        }
        
        // Fallback to large triangle (leg = square side in standard tangram)
        if let largeTri = objects.first(where: { 
            let name = $0["name"] as? String
            return name == "tangram_triangle_lrg" || name == "tangram_triangle_lrg2"
        }), let vertices = largeTri["vertices"] as? [[Double]], vertices.count == 3 {
            let rightAngleIdx = findRightAngleVertex(vertices)
            let leg1Idx = (rightAngleIdx + 1) % 3
            let leg2Idx = (rightAngleIdx + 2) % 3
            let legLength = hypot(vertices[leg1Idx][0] - vertices[rightAngleIdx][0],
                                 vertices[leg1Idx][1] - vertices[rightAngleIdx][1])
            squareSideInCV = legLength  // Large triangle leg = square side
            UserDefaults.standard.set(squareSideInCV, forKey: "cv_square_scale")
            return
        }
        
        // Fallback to medium triangle (leg = square side / √2)
        if let medTri = objects.first(where: { ($0["name"] as? String) == "tangram_triangle_med" }),
           let vertices = medTri["vertices"] as? [[Double]], vertices.count == 3 {
            let rightAngleIdx = findRightAngleVertex(vertices)
            let leg1Idx = (rightAngleIdx + 1) % 3
            let legLength = hypot(vertices[leg1Idx][0] - vertices[rightAngleIdx][0],
                                 vertices[leg1Idx][1] - vertices[rightAngleIdx][1])
            squareSideInCV = legLength * sqrt(2.0)  // Medium triangle leg = square/√2
            UserDefaults.standard.set(squareSideInCV, forKey: "cv_square_scale")
            return
        }
        
        // Final fallback to small triangle (leg = square side / 2)
        if let smallTri = objects.first(where: { 
            let name = $0["name"] as? String
            return name == "tangram_triangle_sml" || name == "tangram_triangle_sml2"
        }), let vertices = smallTri["vertices"] as? [[Double]], vertices.count == 3 {
            let rightAngleIdx = findRightAngleVertex(vertices)
            let leg1Idx = (rightAngleIdx + 1) % 3
            let legLength = hypot(vertices[leg1Idx][0] - vertices[rightAngleIdx][0],
                                 vertices[leg1Idx][1] - vertices[rightAngleIdx][1])
            squareSideInCV = legLength * 2.0  // Small triangle leg = square/2
            UserDefaults.standard.set(squareSideInCV, forKey: "cv_square_scale")
        }
    }
    
    /// Convert CV data to internal normalized format
    func convertToInternal(_ cvData: [String: Any]) -> InternalPuzzleState {
        // Handle homography if needed
        var transformedObjects = cvData["objects"] as? [[String: Any]] ?? []
        
        // Check if homography needs to be applied
        if let homographyApplied = cvData["homography_applied"] as? Bool, !homographyApplied,
           let homography = cvData["homography"] as? [[Double]] {
            // Apply homography to objects
            transformedObjects = applyHomography(homography, to: transformedObjects)
        }
        // Otherwise, assume coordinates are already plane-aligned (post-homography)
        // Non-identity matrix presence is OK - CV may include it for reference
        
        // Load cached scale if available
        if squareSideInCV == 1.0, let cached = UserDefaults.standard.object(forKey: "cv_square_scale") as? Double {
            squareSideInCV = cached
        }
        
        guard let objects = cvData["objects"] as? [[String: Any]] else {
            return InternalPuzzleState(pieces: [])
        }
        
        let pieces = objects.compactMap { obj -> InternalPiece? in
            guard let name = obj["name"] as? String,
                  let type = mapCVNameToType(name),
                  let pose = obj["pose"] as? [String: Any],
                  let translation = pose["translation"] as? [Double],
                  let rotationDegrees = pose["rotation_degrees"] as? Double,
                  let objectId = obj["object_id"] as? String else { return nil }
            
            // Optional: Gate on confidence if available
            if let confidence = obj["confidence"] as? Double, confidence < 0.7 {
                return nil  // Skip low-confidence detections
            }
            
            // Optional: Require stability (piece stationary for 200ms)
            if let stabilityMs = obj["stability_ms"] as? Double, stabilityMs < 200 {
                return nil  // Skip pieces still in motion
            }
            
            // Canonicalize vertices for all pieces before any rotation/flip logic
            if let vertices = obj["vertices"] as? [[Double]] {
                obj["vertices"] = canonicalizeVertices(vertices, for: type)
            }
            
            // Single coordinate conversion point - no Y negation elsewhere!
            var x = translation[0] / squareSideInCV  // Normalize to square=1.0
            var y = translation[1] / squareSideInCV
            var rotation = rotationDegrees * .pi / 180.0  // To radians
            
            // Handle camera inversion if configured
            if isCameraInverted {
                rotation += .pi
                x = -x
                y = -y
            }
            
            // Detect flip for parallelogram using vertex winding
            let isFlipped = (type == .parallelogram) ? detectFlipFromVertices(obj) : false
            
            return InternalPiece(
                id: objectId,
                type: type,
                position: CGPoint(x: x, y: y),  // Y-up, normalized
                rotation: rotation,              // Radians
                isFlipped: isFlipped
            )
        }
        
        return InternalPuzzleState(pieces: pieces)
    }
    
    /// Canonicalize vertices to ensure consistent ordering
    private func canonicalizeVertices(_ vertices: [[Double]], for type: TangramPieceType) -> [[Double]] {
        guard vertices.count >= 3 else { return vertices }
        
        switch type {
        case .square, .parallelogram:
            // Find vertex with min(y), then min(x) in Y-up space
            let canonical = vertices.enumerated().min { a, b in
                if abs(a.element[1] - b.element[1]) > 0.001 {
                    return a.element[1] < b.element[1]  // Lower Y first
                }
                return a.element[0] < b.element[0]  // Then lower X
            }?.offset ?? 0
            
            // Reorder clockwise from canonical corner
            return Array(vertices[canonical...] + vertices[..<canonical])
            
        case .smallTriangle1, .smallTriangle2, .mediumTriangle, .largeTriangle1, .largeTriangle2:
            // Find right-angle vertex by checking edge lengths
            let rightAngleIndex = findRightAngleVertex(vertices)
            
            // Order clockwise starting from right-angle vertex
            return Array(vertices[rightAngleIndex...] + vertices[..<rightAngleIndex])
            
        default:
            return vertices
        }
    }
    
    /// Find the right-angle vertex in a triangle
    private func findRightAngleVertex(_ vertices: [[Double]]) -> Int {
        guard vertices.count == 3 else { return 0 }
        
        // Calculate edge lengths
        let edges = [
            hypot(vertices[1][0] - vertices[0][0], vertices[1][1] - vertices[0][1]),  // 0->1
            hypot(vertices[2][0] - vertices[1][0], vertices[2][1] - vertices[1][1]),  // 1->2
            hypot(vertices[0][0] - vertices[2][0], vertices[0][1] - vertices[2][1])   // 2->0
        ]
        
        // Hypotenuse is the longest edge; vertex opposite to it is the right angle
        let maxEdgeIndex = edges.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
        
        // Vertex opposite to hypotenuse
        return (maxEdgeIndex + 2) % 3
    }
    
    /// Detect flip from vertex winding order
    private func detectFlipFromVertices(_ obj: [String: Any]) -> Bool {
        guard let vertices = obj["vertices"] as? [[Double]],
              let name = obj["name"] as? String,
              let type = mapCVNameToType(name) else { return false }
        
        // Canonicalize vertices first
        let canonical = canonicalizeVertices(vertices, for: type)
        
        // Calculate signed area using shoelace formula
        var signedArea = 0.0
        for i in 0..<canonical.count {
            let j = (i + 1) % canonical.count
            signedArea += canonical[i][0] * canonical[j][1] - canonical[j][0] * canonical[i][1]
        }
        
        // Negative area = clockwise winding = normal
        // Positive area = counter-clockwise = flipped
        return signedArea > 0
    }
}

// MARK: - Angle/Rotation Helpers

extension CVToInternalConverter {
    /// Normalize angle to (-π, π] range
    func normalizeAngle(_ angle: Double) -> Double {
        var result = angle
        while result > .pi { result -= 2 * .pi }
        while result <= -.pi { result += 2 * .pi }
        return result
    }
}

// MARK: - Vector Rotation Extension
extension CGVector {
    /// Rotate vector by angle (radians, CCW)
    func rotated(by angle: Double) -> CGVector {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)
        return CGVector(
            dx: dx * cosAngle - dy * sinAngle,
            dy: dx * sinAngle + dy * cosAngle
        )
    }
}

#### 2.2 Touch-to-CV Output Bridge

```swift
// Location: Bemo/Features/Game/Games/Tangram/Services/CVOutputBridge.swift

class CVOutputBridge {
    
    private var lastEmissionTime: TimeInterval = 0
    private let emissionInterval: TimeInterval = 0.05  // 20Hz max
    
    /// Generate CV format from touch input (throttled)
    func generateCVOutput(
        assembledPieces: [PuzzlePieceNode],
        anchorPiece: PuzzlePieceNode?
    ) -> [String: Any]? {
        
        // Throttle emissions
        let now = CACurrentMediaTime()
        guard now - lastEmissionTime >= emissionInterval else { return nil }
        lastEmissionTime = now
        
        guard !assembledPieces.isEmpty else {
            return ["schema_version": 1, "objects": []]
        }
        
        let referencePoint = anchorPiece?.position ?? assembledPieces.first?.position ?? .zero
        
        let cvObjects = assembledPieces.map { piece in
            // Convert from SpriteKit Y-down to CV Y-up
            let relX = (piece.position.x - referencePoint.x)
            let relY = -(piece.position.y - referencePoint.y)  // Flip Y for CV
            
            return [
                "name": mapTypeToCV(piece.pieceType),
                "class_id": cvClassId(for: piece.pieceType),
                "object_id": piece.id ?? UUID().uuidString,
                "pose": [
                    // SpriteKit zRotation is radians CCW in Y-down space
                    // Convert to degrees CCW for CV (also Y-down in render, but we output Y-up coords)
                    "rotation_degrees": piece.zRotation * 180.0 / .pi,
                    "translation": [relX, relY]  // Y-up for CV
                ],
                "vertices": getVerticesClockwise(piece, relativeTo: referencePoint),
                "is_anchor": piece.isAnchor,
                "confidence": 1.0,  // Touch input has perfect confidence
                "stability_ms": getPieceStabilityTime(piece)  // Time since last movement
            ]
        }
        
        return [
            "schema_version": 1,
            "homography": identityHomography(),
            "homography_applied": true,  // Touch coords are already plane-aligned
            "scale": 50.0,  // Default scale for touch input (will be calibrated on CV side)
            "objects": cvObjects,
            "anchor_id": anchorPiece?.id ?? "none"
        ]
    }
    
    private func mapTypeToCV(_ type: TangramPieceType?) -> String {
        switch type {
        case .square: return "tangram_square"
        case .smallTriangle1: return "tangram_triangle_sml"
        case .smallTriangle2: return "tangram_triangle_sml2"
        case .mediumTriangle: return "tangram_triangle_med"
        case .largeTriangle1: return "tangram_triangle_lrg"
        case .largeTriangle2: return "tangram_triangle_lrg2"
        case .parallelogram: return "tangram_parallelogram"
        default: return "unknown"
        }
    }
}
```

#### 1.2 Piece Type Mapping

```swift
extension CVOutputBridge {
    private func cvClassId(for type: TangramPieceType?) -> Int {
        switch type {
        case .parallelogram: return 0
        case .square: return 1
        case .largeTriangle1: return 2
        case .largeTriangle2: return 3
        case .mediumTriangle: return 4
        case .smallTriangle1: return 5
        case .smallTriangle2: return 6
        default: return -1
        }
    }
    
    private func cvName(for type: TangramPieceType?) -> String {
        switch type {
        case .parallelogram: return "tangram_parallelogram"
        case .square: return "tangram_square"
        case .largeTriangle1: return "tangram_triangle_lrg"
        case .largeTriangle2: return "tangram_triangle_lrg2"
        case .mediumTriangle: return "tangram_triangle_med"
        case .smallTriangle1: return "tangram_triangle_sml"
        case .smallTriangle2: return "tangram_triangle_sml2"
        default: return "unknown"
        }
    }
}
```

### Phase 3: Relative Position Map Validation (Priority: CRITICAL)

#### 3.1 Create Relative Position Map Validator (Anchor-Agnostic)

```swift
// Location: Bemo/Features/Game/Games/Tangram/Services/TangramRelativeValidator.swift

class TangramRelativeValidator {
    
    struct RelativePositionMap {
        let anchorType: TangramPieceType?  // Optional - may not have anchor
        let relationships: [PieceRelationship]
    }
    
    struct PieceRelationship {
        let pieceType: TangramPieceType
        let relativePosition: CGVector  // From anchor
        let relativeRotation: Double    // From anchor
        let isFlipped: Bool
    }
    
    struct ValidationResult {
        let pieceType: TangramPieceType
        let isCorrect: Bool
        let positionError: CGFloat  // Distance from expected
        let rotationError: Double    // Degrees from expected
    }
    
    /// Build relative position map from user's assembly
    func buildUserMap(assembledPieces: [PuzzlePieceNode], anchor: PuzzlePieceNode?) -> RelativePositionMap {
        // Use the actual anchor if available, not just first piece
        guard let reference = anchor else {
            // No anchor established yet
            return RelativePositionMap(anchorType: nil, relationships: [])
        }
        
        let relationships = assembledPieces
            .filter { $0 != reference }
            .map { piece in
                PieceRelationship(
                    pieceType: piece.pieceType ?? .smallTriangle1,
                    relativePosition: CGVector(
                        dx: piece.position.x - reference.position.x,
                        dy: piece.position.y - reference.position.y
                    ),
                    relativeRotation: normalizeAngle(piece.zRotation - reference.zRotation),
                    isFlipped: piece.isFlipped
                )
            }
        
        return RelativePositionMap(
            anchorType: reference.pieceType,
            relationships: relationships
        )
    }
    
    /// Build relative position map from target puzzle using matching anchor type
    func buildTargetMap(
        targetPieces: [GamePuzzleData.TargetPiece],
        anchorType: TangramPieceType?
    ) -> RelativePositionMap? {
        
        // Find the piece matching the user's anchor type
        let targetAnchor: GamePuzzleData.TargetPiece?
        if let anchorType = anchorType {
            targetAnchor = targetPieces.first { $0.pieceType == anchorType }
        } else {
            // No anchor specified, use first piece
            targetAnchor = targetPieces.first
        }
        
        guard let anchor = targetAnchor else { return nil }
        
        let anchorRotation = TangramGeometryUtilities.extractRotation(from: anchor.transform)
        
        let relationships = targetPieces
            .filter { $0.pieceType != anchor.pieceType }
            .map { piece in
                let rotation = TangramGeometryUtilities.extractRotation(from: piece.transform)
                return PieceRelationship(
                    pieceType: piece.pieceType,
                    relativePosition: CGVector(
                        dx: piece.transform.tx - anchor.transform.tx,
                        dy: piece.transform.ty - anchor.transform.ty
                    ),
                    relativeRotation: normalizeAngle(rotation - anchorRotation),
                    isFlipped: TangramGeometryUtilities.isTransformFlipped(piece.transform)
                )
            }
        
        return RelativePositionMap(
            anchorType: anchor.pieceType,
            relationships: relationships
        )
    }
    
    /// Compare two relative position maps with similarity alignment
    func validateMaps(
        userMap: RelativePositionMap,
        targetMap: RelativePositionMap,
        tolerance: ValidationTolerance
    ) -> [ValidationResult] {
        
        var results: [ValidationResult] = []
        
        // Step 1: Estimate global scale and rotation using similarity alignment
        let (globalScale, globalRotation) = estimateSimilarityTransform(
            userMap: userMap,
            targetMap: targetMap
        )
        
        // Step 2: The anchor is always correct (defines origin)
        if let anchorType = userMap.anchorType {
            results.append(ValidationResult(
                pieceType: anchorType,
                isCorrect: true,
                positionError: 0,
                rotationError: 0
            ))
        }
        
        // Step 3: Validate each piece with similarity adjustment
        for userRelation in userMap.relationships {
            if let targetRelation = targetMap.relationships.first(where: { $0.pieceType == userRelation.pieceType }) {
                
                // Apply similarity transform to target
                let alignedTarget = PieceRelationship(
                    pieceType: targetRelation.pieceType,
                    relativePosition: CGVector(
                        dx: targetRelation.relativePosition.dx * globalScale,
                        dy: targetRelation.relativePosition.dy * globalScale
                    ).rotated(by: globalRotation),
                    relativeRotation: targetRelation.relativeRotation + globalRotation,
                    isFlipped: targetRelation.isFlipped
                )
                
                // Calculate position error in normalized units
                let positionError = hypot(
                    userRelation.relativePosition.dx - alignedTarget.relativePosition.dx,
                    userRelation.relativePosition.dy - alignedTarget.relativePosition.dy
                )
                
                // Calculate rotation error with symmetry reduction
                let symmetry = getRotationalSymmetry(for: userRelation.pieceType)
                let rawRotationError = userRelation.relativeRotation - alignedTarget.relativeRotation
                let rotationError = reduceAngleBySymmetry(rawRotationError, symmetry: symmetry)
                
                // Check if within tolerance
                let isCorrect = positionError <= tolerance.position && 
                               abs(rotationError) <= tolerance.rotation * .pi / 180.0 &&
                               (userRelation.pieceType != .parallelogram || 
                                userRelation.isFlipped == alignedTarget.isFlipped)
                
                results.append(ValidationResult(
                    pieceType: userRelation.pieceType,
                    isCorrect: isCorrect,
                    positionError: positionError,
                    rotationError: abs(rotationError) * 180.0 / .pi
                ))
            }
        }
        
        return results
    }
    
    /// Estimate global scale and rotation between two maps
    private func estimateSimilarityTransform(
        userMap: RelativePositionMap,
        targetMap: RelativePositionMap
    ) -> (scale: Double, rotation: Double) {
        
        var scaleRatios: [Double] = []
        var rotationDeltas: [Double] = []
        
        // Compare each matching piece pair
        for userRel in userMap.relationships {
            if let targetRel = targetMap.relationships.first(where: { $0.pieceType == userRel.pieceType }) {
                // Scale: ratio of distances from anchor
                let userDist = hypot(userRel.relativePosition.dx, userRel.relativePosition.dy)
                let targetDist = hypot(targetRel.relativePosition.dx, targetRel.relativePosition.dy)
                if targetDist > 0.01 {  // Avoid division by zero
                    scaleRatios.append(userDist / targetDist)
                }
                
                // Rotation: difference in angles from anchor
                let userAngle = atan2(userRel.relativePosition.dy, userRel.relativePosition.dx)
                let targetAngle = atan2(targetRel.relativePosition.dy, targetRel.relativePosition.dx)
                rotationDeltas.append(normalizeAngle(userAngle - targetAngle))
            }
        }
        
        // Use median for robustness
        let scale = scaleRatios.isEmpty ? 1.0 : median(scaleRatios)
        let rotation = rotationDeltas.isEmpty ? 0.0 : median(rotationDeltas)
        
        return (scale, rotation)
    }
    
    /// Reduce angle by rotational symmetry
    private func reduceAngleBySymmetry(_ angle: Double, symmetry: Double) -> Double {
        let symmetryRad = symmetry * .pi / 180.0
        var reduced = angle
        while reduced > symmetryRad / 2 {
            reduced -= symmetryRad
        }
        while reduced < -symmetryRad / 2 {
            reduced += symmetryRad
        }
        return reduced
    }
    
    private func findAnchorInTarget(_ anchorType: TangramPieceType, _ targetMap: RelativePositionMap) -> PieceRelationship? {
        // If the anchor types match directly
        if targetMap.anchorType == anchorType {
            return PieceRelationship(
                pieceType: anchorType,
                relativePosition: .zero,
                relativeRotation: 0,
                isFlipped: false
            )
        }
        
        // Otherwise find the piece in relationships
        return targetMap.relationships.first { $0.pieceType == anchorType }
    }
}
```

#### 2.2 Relative Position Calculations

```swift
extension TangramRelativeValidator {
    
    struct RelativeState {
        let offset: CGVector       // Position relative to anchor
        let rotation: Double        // Rotation relative to anchor
        let isFlipped: Bool
    }
    
    private func calculateRelative(_ piece: PlacedPiece, anchor: PlacedPiece) -> RelativeState {
        RelativeState(
            offset: CGVector(
                dx: piece.position.x - anchor.position.x,
                dy: piece.position.y - anchor.position.y
            ),
            rotation: normalizeAngle(piece.rotation - anchor.rotation),
            isFlipped: piece.isFlipped
        )
    }
    
    private func calculateRelative(_ target: GamePuzzleData.TargetPiece, anchor: GamePuzzleData.TargetPiece) -> RelativeState {
        let targetRotation = TangramGeometryUtilities.extractRotation(from: target.transform)
        let anchorRotation = TangramGeometryUtilities.extractRotation(from: anchor.transform)
        
        return RelativeState(
            offset: CGVector(
                dx: target.transform.tx - anchor.transform.tx,
                dy: target.transform.ty - anchor.transform.ty
            ),
            rotation: normalizeAngle(targetRotation - anchorRotation),
            isFlipped: TangramGeometryUtilities.isTransformFlipped(target.transform)
        )
    }
}
```

### Phase 4: Remove Snap-to-Target Behavior (Priority: HIGH)

#### 4.1 Update Touch Handling (No Snapping)

```swift
// Modify TangramThreeZoneScene.swift

class TangramThreeZoneScene: SKScene {
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Simple drag - NO SNAPPING
        if let selected = selectedPiece {
            let previousLocation = touch.previousLocation(in: self)
            let deltaX = location.x - previousLocation.x
            let deltaY = location.y - previousLocation.y
            selected.position.x += deltaX
            selected.position.y += deltaY
            
            // Generate CV output on every movement
            generateCVOutputStream()
            
            // Visual feedback for zone boundaries only
            updateZoneFeedback(for: selected)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let selected = selectedPiece else { return }
        
        // NO SNAPPING - piece stays exactly where dropped
        let finalPosition = selected.position
        
        // Check which zone the piece is in
        if isInAssemblyZone(finalPosition) {
            handlePiecePlacement(selected, at: finalPosition)
            
            // Validate relative positions (but don't move piece)
            validateAssembly()
        } else if isInStorageZone(finalPosition) {
            // Piece returned to storage
            selected.zPosition = 0
        }
        
        // Generate final CV output
        generateCVOutputStream()
        
        selectedPiece = nil
    }
    
    private func updateZoneFeedback(for piece: PuzzlePieceNode) {
        // Only show zone indicators, no snap previews
        if isInAssemblyZone(piece.position) {
            piece.alpha = 1.0
        } else {
            piece.alpha = 0.8  // Slight transparency outside assembly
        }
    }
}
```

### Phase 5: CV Output Stream for Every Action (Priority: CRITICAL)

#### 5.1 Continuous CV Stream Generation

```swift
// Add to TangramThreeZoneScene.swift

extension TangramThreeZoneScene {
    
    /// Generate CV output on EVERY interaction
    private func generateCVOutputStream() {
        // generateCVOutput is throttled and may return nil
        guard let cvData = cvBridge.generateCVOutput(
            assembledPieces: assembledPieces,
            anchorPiece: anchorPiece
        ) else { return }  // Throttled, skip this emission
        
        // Stream to viewModel
        onCVDataGenerated?(cvData)
        
        // Update debug display
        updateCVDebugDisplay(cvData)
        
        #if DEBUG
        if let objects = cvData["objects"] as? [[String: Any]], !objects.isEmpty {
            print("📸 CV Stream Update:")
            for obj in objects {
                if let name = obj["name"] as? String,
                   let pose = obj["pose"] as? [String: Any],
                   let translation = pose["translation"] as? [Double],
                   let rotation = pose["rotation_degrees"] as? Double {
                    print("  \(name): pos(\(translation[0]), \(translation[1])) rot(\(rotation)°)")
                }
            }
        }
        #endif
    }
    
    /// Called on drag, rotate, flip - ANY action
    private func onPieceTransformed(_ piece: PuzzlePieceNode) {
        generateCVOutputStream()
        
        // If in assembly zone, revalidate
        if isInAssemblyZone(piece.position) {
            validateAssembly()
        }
    }
}
```

#### 5.2 Update ViewModel for Real-time Processing

```swift
// Modify TangramGameViewModel.swift

class TangramGameViewModel {
    // Stream processing
    private let relativeValidator = TangramRelativeValidator()
    private var lastCVData: [String: Any] = [:]
    private var lastValidationTime: TimeInterval = 0
    private let validationInterval: TimeInterval = 0.1  // Validate at 10Hz max
    private var pieceStabilityTimers: [String: TimeInterval] = [:]  // Track piece settlement
    
    // Persisted difficulty level
    var difficultyLevel: DifficultyLevel {
        get { 
            let rawValue = UserDefaults.standard.string(forKey: "tangram_difficulty") ?? "standard"
            return DifficultyLevel(rawValue: rawValue) ?? .standard
        }
        set { 
            UserDefaults.standard.set(newValue.rawValue, forKey: "tangram_difficulty")
        }
    }
    
    /// Process CV stream in real-time (emissions at 20Hz, validation at 10Hz)
    func processCVStream(_ cvData: [String: Any]) {
        lastCVData = cvData
        
        // Throttle validation to 10Hz even though CV streams at 20Hz
        let now = CACurrentMediaTime()
        guard now - lastValidationTime >= validationInterval else { return }
        lastValidationTime = now
        
        // Only validate if we have pieces in assembly
        guard let objects = cvData["objects"] as? [[String: Any]], 
              !objects.isEmpty else { return }
        
        // Check piece stability (require 200ms of no movement)
        if !arePiecesStable(objects) { return }
        
        // Build user's relative map
        let userMap = buildMapFromCVData(cvData)
        
        // Build target relative map with current anchor type
        guard let targetMap = relativeValidator.buildTargetMap(
            targetPieces: selectedPuzzle?.targetPieces ?? [],
            anchorType: userMap.anchorType  // Pass the current anchor's type
        ) else { return }
        
        // Validate in real-time
        let results = relativeValidator.validateMaps(
            userMap: userMap,
            targetMap: targetMap,
            tolerance: currentTolerance()
        )
        
        // Update UI with validation results
        updateValidationDisplay(results)
        
        // Partial assembly semantics:
        // Only evaluate pieces that are present - don't fail if pieces are missing
        // Completion requires ALL 7 pieces present AND all passing validation
        let placedPieceCount = objects.count
        let allPlacedCorrect = results.allSatisfy({ $0.isCorrect })
        
        if placedPieceCount == 7 && allPlacedCorrect {
            handlePuzzleCompletion()
        } else if allPlacedCorrect {
            // Show partial success feedback
            showPartialSuccessFeedback(placedCount: placedPieceCount)
        }
    }
    
    private func currentTolerance() -> ValidationTolerance {
        // Use normalized tolerances based on difficulty
        switch difficultyLevel {
        case .easy:
            return ValidationTolerance.easy      // 0.40 square units, 15°
        case .standard:
            return ValidationTolerance.standard  // 0.25 square units, 10°
        case .precise:
            return ValidationTolerance.precise   // 0.15 square units, 5°
        case .expert:
            return ValidationTolerance.expert    // 0.08 square units, 3°
        default:
            return ValidationTolerance.standard
        }
    }
    
    /// Check if pieces have been stable for required duration
    private func arePiecesStable(_ objects: [[String: Any]]) -> Bool {
        let now = CACurrentMediaTime()
        let requiredStabilityTime: TimeInterval = 0.2  // 200ms
        let positionEpsilon = 0.01  // Normalized units
        let rotationEpsilon = 0.5 * .pi / 180.0  // 0.5 degrees in radians
        
        for obj in objects {
            guard let objectId = obj["object_id"] as? String,
                  let pose = obj["pose"] as? [String: Any],
                  let translation = pose["translation"] as? [Double],
                  let rotation = pose["rotation_degrees"] as? Double else { continue }
            
            // Check if we have previous state for this piece
            if let lastState = pieceStates[objectId] {
                // Check if position/rotation changed significantly
                let positionDelta = hypot(translation[0] - lastState.position.x,
                                         translation[1] - lastState.position.y)
                let rotationDelta = abs(normalizeAngle((rotation - lastState.rotation) * .pi / 180.0))
                
                if positionDelta > positionEpsilon || rotationDelta > rotationEpsilon {
                    // Piece moved - reset stability timer
                    pieceStabilityTimers[objectId] = now
                    pieceStates[objectId] = PieceState(
                        position: CGPoint(x: translation[0], y: translation[1]),
                        rotation: rotation
                    )
                }
            } else {
                // First time seeing this piece
                pieceStabilityTimers[objectId] = now
                pieceStates[objectId] = PieceState(
                    position: CGPoint(x: translation[0], y: translation[1]),
                    rotation: rotation
                )
            }
            
            // Check if this piece has been stable long enough
            if let stabilityStart = pieceStabilityTimers[objectId] {
                if now - stabilityStart < requiredStabilityTime {
                    return false  // At least one piece not stable yet
                }
            }
        }
        
        return true  // All pieces stable
    }
    
    // Helper struct for tracking piece state
    struct PieceState {
        let position: CGPoint
        let rotation: Double  // Degrees
    }
    private var pieceStates: [String: PieceState] = [:]
}

### Phase 4: Camera Inversion Handling (Priority: HIGH) - REMOVED AUTO-DETECT

**Decision: Manual toggle only, no auto-detection**

Camera inversion is handled in `CVToInternalConverter` via a manual toggle that persists per device. The inversion logic is already implemented correctly - we just need a UI toggle to control it. No separate CVCameraOrientationService is needed.

### Phase 5: Validation Tolerance Configuration (Priority: MEDIUM)

#### 5.1 Dynamic Tolerance System

```swift
// Location: Bemo/Features/Game/Games/Tangram/Models/ValidationTolerance.swift

// NOTE: All tolerances use normalized units (square side = 1.0)
struct ValidationTolerance {
    let position: Double        // In square-side units (normalized)
    let rotation: Double        // Degrees
    let confidence: Double      // CV confidence threshold (optional)
    
    // Predefined difficulty levels (normalized units)
    static let easy = ValidationTolerance(position: 0.40, rotation: 15.0, confidence: 0.7)
    static let standard = ValidationTolerance(position: 0.25, rotation: 10.0, confidence: 0.8)
    static let precise = ValidationTolerance(position: 0.15, rotation: 5.0, confidence: 0.9)
    static let expert = ValidationTolerance(position: 0.08, rotation: 3.0, confidence: 0.95)
    
    // Special tolerances for piece types
    func adjusted(for pieceType: TangramPieceType) -> ValidationTolerance {
        switch pieceType {
        case .square:
            // Square has 90° rotational symmetry
            return ValidationTolerance(
                position: position,
                rotation: 90.0,  // Accept any 90° multiple
                confidence: confidence
            )
        case .largeTriangle1, .largeTriangle2:
            // Larger pieces need slightly more tolerance
            return ValidationTolerance(
                position: position * 1.2,
                rotation: rotation,
                confidence: confidence
            )
        default:
            return self
        }
    }
}
```

### Phase 6: Debug & Testing Tools (Priority: MEDIUM)

#### 6.1 CV Debug Overlay

```swift
// Location: Bemo/Features/Game/Games/Tangram/Views/CVDebugOverlay.swift

struct CVDebugOverlay: View {
    @ObservedObject var viewModel: TangramGameViewModel
    let cvData: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CV Output Stream")
                .font(.headline)
            
            ForEach(parsedObjects, id: \.id) { object in
                HStack {
                    Text(object.name)
                        .font(.caption.monospaced())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pos: (\(object.x, format: .number.precision(.fractionLength(1))), \(object.y, format: .number.precision(.fractionLength(1))))")
                        Text("Rot: \(object.rotation, format: .number.precision(.fractionLength(1)))°")
                        Text("State: \(object.validationState)")
                    }
                    .font(.caption2.monospaced())
                }
                .padding(4)
                .background(validationColor(object.validationState).opacity(0.2))
                .cornerRadius(4)
            }
            
            Toggle("Show Relative Positions", isOn: $showRelativeMode)
            Toggle("Camera Inverted", isOn: $cameraInverted)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .foregroundColor(.white)
        .cornerRadius(10)
    }
}
```

## Migration Strategy

### Step 1: Layout Transformation (Week 1)
1. Create three-zone layout system
2. Remove ALL snap-to-target behavior
3. Implement first-placed anchor system
4. Test zone transitions and piece placement

### Step 2: CV Output Integration (Week 1-2)
1. Add CVOutputBridge for real-time streaming
2. Generate CV data on EVERY user action
3. Output relative positions from anchor
4. Log and debug CV format

### Step 3: Relative Validation (Week 2)
1. Implement RelativePositionMap builder
2. Compare user map to target map
3. Validate with configurable tolerances
4. Visual feedback without moving pieces

### Step 4: Testing & Refinement (Week 3)
1. Test with existing puzzles
2. Tune tolerances for difficulty
3. Verify CV format accuracy
4. Performance optimization

### Step 5: CV Integration Ready
1. Accept real CV input OR touch-generated CV format
2. Single validation pipeline for both
3. Seamless transition when CV hardware ready
4. First-placed anchor works for both physical and digital

## Key Technical Decisions

### 1. Why Three-Zone Layout?
- **Physical simulation**: Middle zone represents physical table
- **Clear separation**: Reference, assembly, and storage areas
- **User understanding**: Mirrors real-world puzzle solving
- **CV accuracy**: Simulates exactly what CV camera sees

### 2. Why Dynamic Anchor System?
- **Physical world match**: First piece defines initial origin
- **Resilience**: System continues if anchor is removed
- **User flexibility**: Can remove/replace any piece
- **CV alignment**: Matches how CV would handle piece removal
- **Anchor promotion**: Next oldest/largest piece becomes anchor

### 3. Why No Snapping?
- **Real-world simulation**: Physical pieces don't snap
- **CV preparation**: CV won't have snap behavior
- **True validation**: Tests actual relative positioning
- **User skill**: Requires precise placement like physical puzzles

### 4. Why Continuous CV Stream?
- **Real-time feedback**: Immediate validation updates
- **CV simulation**: Matches continuous CV camera feed
- **Debug capability**: See exact CV output for every action
- **Performance testing**: Ensures system handles stream rate

## Success Metrics

### Technical Validation ✅
- [ ] CV format generated for every user action
- [ ] Relative validation matches absolute for known puzzles
- [ ] 180° rotation handled correctly
- [ ] Performance maintains 60 FPS

### Integration Readiness ✅
- [ ] Can accept CV JSON input
- [ ] Can accept touch input
- [ ] Same validation pipeline for both
- [ ] Tolerance configuration works

### User Experience ✅
- [ ] Game remains playable during transition
- [ ] No regression in current functionality
- [ ] Debug tools available for testing
- [ ] Smooth animation and feedback maintained

## File Changes Summary

### New Files to Create
1. `TangramThreeZoneScene.swift` - New three-zone layout scene
2. `CVOutputBridge.swift` - Converts game state to CV format
3. `TangramRelativeValidator.swift` - Relative position map validation
4. `ValidationTolerance.swift` - Configurable tolerance system
5. `CVDebugOverlay.swift` - Debug visualization for CV stream

### Files to Modify Significantly
1. `TangramPuzzleScene.swift` - REPLACE with three-zone version
2. `TangramGameViewModel.swift` - Add CV stream processing
3. `TangramGameView.swift` - Update for three-zone layout
4. `PlacedPiece.swift` - Add anchor tracking field

### Files to Remove/Deprecate
1. Snap-to-target logic in `TangramPuzzleScene.swift`
2. Absolute validation in `TangramPieceValidator.swift`
3. Target overlay interactions

### Files to Reference (No Changes)
1. `TangramHintEngine.swift` - Update for assembly zone
2. `TangramGameConstants.swift` - Tolerance values to use
3. `TangramGeometryUtilities.swift` - Transform utilities ready
4. `PuzzlePieceNode.swift` - Add isAnchor property

## Implementation Timeline

### Week 1: Foundation
- Day 1-2: Implement CVOutputBridge
- Day 3-4: Test CV format generation
- Day 5: Add debug logging

### Week 2: Validation
- Day 1-2: Implement RelativeValidator
- Day 3-4: Parallel validation testing
- Day 5: Tolerance tuning

### Week 3: Integration
- Day 1-2: 180° rotation handling
- Day 3-4: Debug overlay and tools
- Day 5: Final testing and documentation

## Visual Mockup

```
┌─────────────────────────────────────┐
│          TOP ZONE (Reference)       │
│     ┌──┐                            │
│    ╱    ╲  ┌──┐  ╱╲                │  ← Target puzzle (read-only)
│   ╱      ╲ │  │ ╱  ╲               │     Shows correct arrangement
│  └────────┘└──┘└────┘              │
├─────────────────────────────────────┤
│      MIDDLE ZONE (Assembly)         │
│  ╭ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ╮       │
│                                     │  ← "Physical table" area
│  │    ┌──┐     ╱╲         │        │     User builds here
│      │🟢│    ╱  ╲                  │     🟢 = anchor piece
│  │    └──┘   └────┘       │        │
│  ╰ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ╯       │
├─────────────────────────────────────┤
│      BOTTOM ZONE (Storage)          │
│                                     │  ← Scattered pieces
│   ╱╲     ┌──┐        ╱────╲        │     Starting state
│  ╱  ╲    │  │       ╱      ╲       │
│ └────┘   └──┘      └────────┘      │
└─────────────────────────────────────┘

CV Output Stream (real-time):
{
  "anchor_id": "square",
  "objects": [
    {"name": "tangram_square", "translation": [0, 0], "is_anchor": true},
    {"name": "tangram_triangle_sml", "translation": [50, -30], "rotation_degrees": 45}
  ]
}
```

## Implementation Summary: All Decisions Locked

### Coordinate Pipeline (Fixed)
1. **CV Input**: Post-homography, Y-up, degrees, table plane coordinates
2. **Internal Math**: Y-up, radians, normalized (square = 1.0)
3. **SpriteKit Render**: Y-down ONLY at draw time
4. **Single Conversion**: All transforms in `CVToInternalConverter`

### Piece Identity (Fixed)
- `tangram_triangle_sml` → `smallTriangle1` (Red)
- `tangram_triangle_sml2` → `smallTriangle2` (Blue)
- `tangram_triangle_lrg` → `largeTriangle1` (Green)
- `tangram_triangle_lrg2` → `largeTriangle2` (Yellow)
- Pieces have unique IDs - no assignment problem

### Validation Rules (Fixed)
- **Similarity Alignment**: Estimate global (scale, rotation) via median
- **Symmetry**: Square 90°, Triangles 180°, Parallelogram none
- **Flip Detection**: Negative determinant = flipped
- **Tolerances**: In normalized units (Easy: 0.40/15°, Standard: 0.25/10°, etc.)

### CV Stream (Fixed)
- **Rate**: Max 20Hz (50ms between emissions)
- **Settle**: 200ms after drop before validation
- **Schema**: Version 1, includes `object_id` for stability
- **Throttled**: No spam on drag

### Anchor Policy (Fixed)
- **Touch**: First placed = anchor
- **CV**: Largest piece with hysteresis
- **Removal**: Next oldest/largest promotes
- **Validation**: Works with ANY piece as anchor

### What This Solves
✅ Unique piece IDs eliminate matching complexity
✅ Single conversion boundary prevents coordinate confusion
✅ Normalized units make tolerances device-independent
✅ Similarity alignment handles scale/rotation variance
✅ Proper symmetry rules prevent false negatives
✅ Throttling ensures performance
✅ Dynamic anchor handles piece removal

## Conclusion

This plan provides a **definitive, executable blueprint** for transforming the Tangram game into a CV-ready system. All design decisions have been made based on the feedback:

1. **Fixed CV↔Game mapping** with unique IDs
2. **Single coordinate conversion** boundary
3. **Scale-invariant validation** with similarity alignment
4. **Proper symmetry handling** (triangles 180°, not 90°)
5. **Normalized tolerances** independent of device/camera
6. **Throttled CV stream** at 20Hz max
7. **Dynamic anchor** with promotion on removal

The implementation is now ready for execution with no remaining ambiguity. The system will seamlessly handle both touch input and future CV integration without any validation logic changes.