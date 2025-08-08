# CV-First Checkpoint: Tangram Game Transformation Plan

## Executive Summary

This plan transforms the Tangram game to simulate the physical world experience where users build puzzles on a "table" (middle zone), exactly as they would with physical pieces under a CV camera. Every action generates CV-formatted output, and validation uses relative positioning with the first-placed piece as the permanent anchor.

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
    
    /// Promote a new anchor from existing pieces
    private func promoteNewAnchor() {
        // Priority: oldest piece (first in array), or largest piece
        let newAnchor = assembledPieces.first ?? assembledPieces.max { p1, p2 in
            getPieceArea(p1.pieceType) < getPieceArea(p2.pieceType)
        }
        
        if let newAnchor = newAnchor {
            setAsAnchor(newAnchor)
            print("🔄 Anchor promoted to: \(newAnchor.pieceType?.rawValue ?? "unknown")")
        }
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

#### 2.1 Real-time CV Format Generation

```swift
// Location: Bemo/Features/Game/Games/Tangram/Services/CVOutputBridge.swift

class CVOutputBridge {
    // Constants matching CV system
    private let cvScale: Double = 2.819
    private let simulateInvertedCamera = true // 180° rotation flag
    
    /// Generates CV output for pieces in assembly zone
    func generateCVOutput(
        assembledPieces: [PuzzlePieceNode],
        anchorPiece: PuzzlePieceNode?
    ) -> [String: Any] {
        
        guard !assembledPieces.isEmpty else {
            return ["objects": []]
        }
        
        // All positions relative to anchor (or first piece if no anchor yet)
        let referencePoint = anchorPiece?.position ?? assembledPieces.first?.position ?? .zero
        
        let cvObjects = assembledPieces.map { piece in
            convertToCVFormat(piece, relativeTo: referencePoint)
        }
        
        return [
            "homography": identityHomography(),
            "scale": cvScale,
            "objects": cvObjects,
            "anchor_id": anchorPiece?.pieceType?.rawValue ?? "none"
        ]
    }
    
    /// Converts a single piece to CV format with relative positioning
    private func convertToCVFormat(_ piece: PuzzlePieceNode, relativeTo anchor: CGPoint) -> [String: Any] {
        // Calculate relative position from anchor
        var relativeX = piece.position.x - anchor.x
        var relativeY = piece.position.y - anchor.y
        
        // Convert to CV coordinate system (Y negative)
        relativeY = -relativeY
        
        var rotation = radiansToDegrees(piece.zRotation)
        
        // Handle 180° camera inversion if needed
        if simulateInvertedCamera {
            rotation = normalizeAngle(rotation + 180.0)
            relativeX = -relativeX
            relativeY = -relativeY
        }
        
        return [
            "name": cvName(for: piece.pieceType),
            "class_id": cvClassId(for: piece.pieceType),
            "pose": [
                "rotation_degrees": rotation,
                "translation": [relativeX, relativeY]
            ],
            "vertices": calculateVertices(piece, relativeTo: anchor),
            "is_anchor": piece.isAnchor
        ]
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
        // If no anchor yet, use first piece as temporary reference
        let referencePoint = anchor ?? assembledPieces.first
        guard let reference = referencePoint else {
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
    
    /// Compare two relative position maps
    func validateMaps(
        userMap: RelativePositionMap,
        targetMap: RelativePositionMap,
        tolerance: ValidationTolerance
    ) -> [ValidationResult] {
        
        var results: [ValidationResult] = []
        
        // The anchor is always correct (it defines the origin)
        results.append(ValidationResult(
            pieceType: userMap.anchorType,
            isCorrect: true,
            positionError: 0,
            rotationError: 0
        ))
        
        // Find the matching anchor piece in target map
        guard let targetAnchorRelation = findAnchorInTarget(userMap.anchorType, targetMap) else {
            // If we can't find the anchor type in target, validation fails
            return results
        }
        
        // Validate each relationship
        for userRelation in userMap.relationships {
            // Find corresponding piece in target map
            if let targetRelation = targetMap.relationships.first(where: { $0.pieceType == userRelation.pieceType }) {
                
                // Adjust target relation based on anchor alignment
                let adjustedTargetRelation = adjustForAnchorAlignment(
                    targetRelation,
                    anchorOffset: targetAnchorRelation
                )
                
                // Calculate errors
                let positionError = hypot(
                    userRelation.relativePosition.dx - adjustedTargetRelation.relativePosition.dx,
                    userRelation.relativePosition.dy - adjustedTargetRelation.relativePosition.dy
                )
                
                let rotationError = abs(normalizeAngle(
                    userRelation.relativeRotation - adjustedTargetRelation.relativeRotation
                ))
                
                // Check if within tolerance
                let isCorrect = positionError <= tolerance.position && 
                               rotationError <= tolerance.rotation &&
                               (userRelation.pieceType != .parallelogram || 
                                userRelation.isFlipped == adjustedTargetRelation.isFlipped)
                
                results.append(ValidationResult(
                    pieceType: userRelation.pieceType,
                    isCorrect: isCorrect,
                    positionError: positionError,
                    rotationError: radiansToDegrees(rotationError)
                ))
            }
        }
        
        return results
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
        let cvData = cvBridge.generateCVOutput(
            assembledPieces: assembledPieces,
            anchorPiece: anchorPiece
        )
        
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
    
    /// Process CV stream in real-time
    func processCVStream(_ cvData: [String: Any]) {
        lastCVData = cvData
        
        // Only validate if we have pieces in assembly
        guard let objects = cvData["objects"] as? [[String: Any]], 
              !objects.isEmpty else { return }
        
        // Build user's relative map
        let userMap = buildMapFromCVData(cvData)
        
        // Build target relative map
        guard let targetMap = relativeValidator.buildTargetMap(
            targetPieces: selectedPuzzle?.targetPieces ?? []
        ) else { return }
        
        // Validate in real-time
        let results = relativeValidator.validateMaps(
            userMap: userMap,
            targetMap: targetMap,
            tolerance: currentTolerance()
        )
        
        // Update UI with validation results
        updateValidationDisplay(results)
        
        // Check for puzzle completion
        if results.allSatisfy({ $0.isCorrect }) && results.count == 7 {
            handlePuzzleCompletion()
        }
    }
    
    private func currentTolerance() -> ValidationTolerance {
        // Start generous, can be adjusted
        return ValidationTolerance(
            position: 25.0,  // pixels
            rotation: 15.0,  // degrees
            confidence: 0.8
        )
    }
}

### Phase 4: 180° Camera Rotation Handling (Priority: HIGH)

#### 4.1 Create Camera Orientation Service

```swift
// Location: Bemo/Features/Game/Games/Tangram/Services/CVCameraOrientationService.swift

class CVCameraOrientationService {
    private var isInverted: Bool = true // Default to inverted based on analysis
    
    /// Auto-detect camera orientation from first few frames
    func detectOrientation(cvData: [String: Any], expectedPuzzle: GamePuzzleData) -> Bool {
        // Compare CV data with expected puzzle orientation
        // If all rotations are ~180° off, camera is inverted
        guard let objects = cvData["objects"] as? [[String: Any]] else { return isInverted }
        
        var rotationDeltas: [Double] = []
        
        for object in objects {
            guard let pose = object["pose"] as? [String: Any],
                  let rotation = pose["rotation_degrees"] as? Double,
                  let className = object["name"] as? String,
                  let targetPiece = findTargetPiece(className, in: expectedPuzzle) else {
                continue
            }
            
            let targetRotation = extractRotation(targetPiece.transform)
            let delta = normalizeAngle(rotation - targetRotation)
            rotationDeltas.append(delta)
        }
        
        // If average delta is close to 180°, camera is inverted
        let avgDelta = rotationDeltas.reduce(0, +) / Double(rotationDeltas.count)
        isInverted = abs(avgDelta - 180) < 30 || abs(avgDelta + 180) < 30
        
        return isInverted
    }
    
    /// Apply 180° correction if camera is inverted
    func correctForInversion(_ cvData: [String: Any]) -> [String: Any] {
        guard isInverted else { return cvData }
        
        var corrected = cvData
        guard var objects = cvData["objects"] as? [[String: Any]] else { return cvData }
        
        for i in 0..<objects.count {
            if var pose = objects[i]["pose"] as? [String: Any],
               var rotation = pose["rotation_degrees"] as? Double,
               var translation = pose["translation"] as? [Double] {
                
                // Add 180° to rotation
                rotation = normalizeAngle(rotation + 180.0)
                
                // Reflect position around puzzle center
                let centerX = 400.0
                let centerY = 300.0
                translation[0] = 2 * centerX - translation[0]
                translation[1] = 2 * centerY - abs(translation[1])
                
                pose["rotation_degrees"] = rotation
                pose["translation"] = translation
                objects[i]["pose"] = pose
            }
        }
        
        corrected["objects"] = objects
        return corrected
    }
}
```

### Phase 5: Validation Tolerance Configuration (Priority: MEDIUM)

#### 5.1 Dynamic Tolerance System

```swift
// Location: Bemo/Features/Game/Games/Tangram/Models/ValidationTolerance.swift

struct ValidationTolerance {
    let position: CGFloat      // Pixels
    let rotation: Double        // Degrees
    let confidence: Double      // CV confidence threshold
    
    // Predefined difficulty levels
    static let generous = ValidationTolerance(position: 30, rotation: 20, confidence: 0.7)
    static let standard = ValidationTolerance(position: 20, rotation: 15, confidence: 0.8)
    static let precise = ValidationTolerance(position: 10, rotation: 7, confidence: 0.9)
    static let expert = ValidationTolerance(position: 5, rotation: 3, confidence: 0.95)
    
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

## Conclusion

This transformation fundamentally shifts the Tangram game from a snap-to-target puzzle to a **physical world simulation** where:

1. Users build puzzles freely in an assembly area (middle zone)
2. The first piece placed becomes the initial anchor point
3. **If anchor is removed, the next piece automatically promotes to anchor**
4. Every action generates CV-formatted output with relative positions from current anchor
5. Validation compares relative position maps, not absolute coordinates
6. No snapping behavior - pieces stay exactly where placed

This **dynamic anchor system** ensures the game continues to function even as pieces are added and removed, exactly matching how a CV system would handle physical pieces where any piece could be picked up at any time. The validation logic works with ANY piece as the anchor, making it robust to real-world interactions.

The plan prioritizes clear zone separation, dynamic anchor management, and continuous CV output streaming, ensuring the system is ready for both touch-based testing and future CV integration without any code changes to the validation logic.