### Goal
Make rotation/position handling 100% consistent across:
- Tangram drag-and-drop game (SpriteKit renderer)
- Future Tangram CV game (CV detections)

Use a single convention for logic/data: raw CGAffineTransform angles and translations, and a single conversion layer when rendering/reading SpriteKit node state.

### Core principles
- Store and reason in raw DB/CV space: rotation = extractRotation(from: transform) without sign hacks; translation = (tx, ty) with Y-down screen convention.
- Convert once at the renderer boundary (SpriteKit) using centralized helpers. Do not sprinkle negations across call sites.
- For validation, compare like-with-like angles and positions in the same space.

### What we will build (shared utility)
Create a single conversion utility to centralize mapping between raw puzzle (DB/CV) space and SpriteKit space.

- New file: `Bemo/Features/Game/Games/Tangram/Utilities/TangramPoseMapper.swift`
- Public, static helpers:
  - `rawAngle(from: CGAffineTransform) -> CGFloat`  // atan2(b, a), normalized to [-π, π]
  - `rawPosition(from: CGAffineTransform) -> CGPoint` // (tx, ty)
  - `spriteKitAngle(fromRawAngle:) -> CGFloat`        // maps raw angle → SK zRotation
  - `spriteKitPosition(fromRawPosition:) -> CGPoint`  // maps (tx, ty) → SK position
  - `rawAngle(fromSpriteKitAngle:) -> CGFloat`        // inverse mapping
  - `rawPosition(fromSpriteKitPosition:) -> CGPoint`  // inverse mapping
- Initial policy (simple, robust):
  - Keep scene’s coordinate system as-is (SpriteKit Y-up).
  - Do NOT flip/mirror target vertices manually.
  - Convert raw to SK with:
    - angle: `skAngle = -rawAngle`        // invert sign once, everywhere
    - position: `skPos = CGPoint(x: raw.tx, y: -raw.ty)`   // invert Y once, everywhere
  - Rationale: One function pair controls all conversions, making future CV/game alignment easy. If we later choose to flip the scene/layers instead, we change these helpers only.

Note: This is the same as “remove scene-space hacks”; we explicitly own the conversion at one choke point.

---

## Tangram drag-and-drop game changes

### 1) Targets: render using PoseMapper, remove ad-hoc inversions
- File: `Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift`
- Function: `createTargetPiece(_:)`
- Edits:
  - Stop building the target path with per-vertex Y inversions. Build the path centered on the centroid exactly like `PuzzlePieceNode.createShape` does (no flips).
  - Set target node pose via PoseMapper:
    - `shape.zRotation = TangramPoseMapper.spriteKitAngle(fromRawAngle: rawAngle)`
    - `shape.position = TangramPoseMapper.spriteKitPosition(fromRawPosition: rawPos)`
  - Remove manual “Calculated center / Y negation” math used to simulate transforms; let SpriteKit do the rotation/translation via the node’s `zRotation` and `position`.

What to delete/replace in spirit:
- Remove Y sign flips in path y coordinates and in `shape.position.y = -centerY`.
- Do not derive visual angle by reading `a,b` then negating locally; always call PoseMapper.

### 2) Movable pieces: ensure their pose is always in SK space
- File: `Bemo/Features/Game/Games/Tangram/Views/Components/PuzzlePieceNode.swift`
- Already centered around centroid. Keep geometry as-is.
- No additional changes needed beyond being consistent about `zRotation` and `position` assignments from the scene.

### 3) Validation: compare in SK space (no negation here)
- File: `Bemo/Features/Game/Games/Tangram/Services/TangramPieceValidator.swift`
- Function: `validateForSpriteKit(...)`
- Replace target rotation/position derivation to SK space via PoseMapper, not raw or negated raw:
  - targetRotationSK = `TangramPoseMapper.spriteKitAngle(fromRawAngle: rawAngle)`
  - targetPositionSK = `TangramPoseMapper.spriteKitPosition(fromRawPosition: CGPoint(x: tx, y: ty))`
- Compare:
  - `pieceRotation` (zRotation) vs `targetRotationSK` → call `TangramRotationValidator.isRotationValid(currentRotation: pieceRotation, targetRotation: targetRotationSK, ...)`.
  - `piecePosition` vs `targetPositionSK` using distance tolerance.
- Remove the current negation in validator. All SK comparisons now happen in SK space.

Why: both piece and target are in the same coordinate space (SpriteKit) at comparison time; no sign hacks.

### 4) Snapping: set piece angle/position using SK space
- File: `Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift`
- Function: `touchesEnded(...)`, in success branch:
  - Compute SK target pose via PoseMapper.
  - Snap with `piece.position = targetPositionSK`
  - Set final rotation with `piece.zRotation = targetRotationSK`
- Do not set using raw angle or raw position; do not negate manually.

### 5) Hints: draw and compute using SK space
- File: `Bemo/Features/Game/Games/Tangram/Services/TangramHintEngine.swift`
- Wherever the code extracts target rotation (grep for `extractRotation(from:`), change:
  - `let rotSK = TangramPoseMapper.spriteKitAngle(fromRawAngle: TangramPoseMapper.rawAngle(from: targetTransform))`
  - Pass `rotSK` to renderer.
- File: `Bemo/Features/Game/Games/Tangram/Views/Components/TangramHintRenderer.swift`
  - This file just renders; ensure it receives SK angles and SK positions from the engine. No conversion here.

### 6) Logging consistency
- In all game logs that print “target rotation” for validation:
  - Print both “raw” and “SK” angles explicitly once when debugging, but ensure comparisons are always SK vs SK.
  - Avoid mixed-space comparisons in logs.

### 7) Parallelogram flip button reliability
- File: `Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift`
- Ensure the flip button acts on the same piece that the dial targets:
  - Keep `selectedPiece` valid while dial is open, or have the dial expose its `targetPiece` and use that reference.
- You already improved dial tap handling; just confirm flip code path does not clear selection before acting.

### 8) TangramRotationValidator remains unchanged
- File: `Bemo/Features/Game/Games/Tangram/Models/TangramRotationValidator.swift`
- It’s space-agnostic: it compares angles and accounts for symmetry. It will work as long as both angles passed are in the same space (SK).

---

## Tangram CV game changes

The CV plan in `.mitch-docs/explainers/cv-output-explainer.md` aligns well with “raw transform everywhere” in logic and a single renderer conversion at the boundary.

### 1) CV → raw transform conversion (single choke point)
- File: `Bemo/Features/Game/Games/TangramCV/Services/CVToInternalConverter.swift` (to be created / completed)
- Responsibilities:
  - Input: CV object with `rotation_degrees`, `translation [x,y]`, homography.
  - Apply homography → get planar coordinates.
  - Apply camera inversion if needed (add 180° and reflect center) exactly once here.
  - Scale to game visual scale (consistent with `TangramGameConstants.visualScale`).
  - Output: CGAffineTransform (raw DB/game space) with a,b,c,d,tx,ty populated.

This yields raw transforms identical in convention to the DB puzzles.

### 2) Renderer boundary conversion (SK) via PoseMapper
- File: `Bemo/Features/Game/Games/TangramCV/Views/TangramThreeZoneScene.swift`
- When instantiating/displaying detected pieces or reference silhouettes:
  - Convert raw angle/position to SK using `TangramPoseMapper`.
  - Set `node.zRotation` and `node.position` accordingly.
- No ad-hoc flips; no separate negations.

### 3) Relative validation (future)
- File: `Bemo/Features/Game/Games/TangramCV/Services/TangramRelativeValidator.swift`
- Decide a single space (raw or SK) for relative comparisons and stick to it. Recommendation:
  - Operate in raw space so you can compare directly with puzzle target transforms (also raw).
  - If you only have SK node states, convert back with PoseMapper’s inverse functions.

### 4) Hints/overlays in CV game
- If you show target guidance in the CV game, compute target SK angle via PoseMapper and render in SK space, consistent with the Tangram game’s approach.

---

## Migration checklist (both games)

1) Add `TangramPoseMapper.swift` with conversion helpers.
2) Replace all target rotation/position reads to go through PoseMapper:
   - Tangram game:
     - `TangramPuzzleScene.createTargetPiece`
     - `TangramPieceValidator.validateForSpriteKit`
     - `TangramPuzzleScene.touchesEnded` (snapping)
     - `TangramHintEngine` (extracts target rotation)
   - CV game:
     - `TangramThreeZoneScene` (renderer)
     - `CVToInternalConverter` (normalize CV → raw transform)
3) Remove Y-inversion of target paths in `createTargetPiece`.
4) Ensure piece and target comparisons are in the same space (SK).
5) Ensure hints present SK angles and positions (no raw angles in renderer).
6) Keep `TangramRotationValidator` unchanged, but feed it SK angles consistently.
7) Verify parallelogram flip is acting on the correct piece reference when dial is open.

---

## Acceptance tests

- Triangles (no symmetry):
  - largeTriangle1 target raw = 180° → SK angle = −180°.
  - Rotate piece visually to match target silhouette; validation → rotation: true within 25°.
- largeTriangle2 target raw = −135° → SK = +135° or −135° depending on PoseMapper policy; ensure your policy yields the same target SK angle you rendered; rotate piece to match; validation → true.
- Medium/small triangles: same behavior.
- Square (4-fold): rotation passes at 0, 90, 180, 270.
- Parallelogram: rotation aligns; flip validity toggles when flipping; positioning tolerance works.
- CV game:
  - Feed `.mitch-docs/cv-output-cat/000000000009_plane_coords.json` through `CVToInternalConverter`.
  - Render pieces with `TangramThreeZoneScene` using PoseMapper.
  - Relative validator compares raw transforms relative to anchor vs DB target transforms; correct matches.

---

## Notes on future flexibility
- If you later decide to flip the entire SpriteKit layer (e.g., `puzzleLayer.yScale = -1`) to get a Y-down visual space, you only change PoseMapper’s two conversion functions and nothing else in game logic.

---

## Files to change (summary)
- New: `Bemo/Features/Game/Games/Tangram/Utilities/TangramPoseMapper.swift`
- Edit:
  - `Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift`
  - `Bemo/Features/Game/Games/Tangram/Services/TangramPieceValidator.swift`
  - `Bemo/Features/Game/Games/Tangram/Services/TangramHintEngine.swift`
  - `Bemo/Features/Game/Games/Tangram/Views/Components/TangramHintRenderer.swift` (ensure it consumes SK angles only)
  - `Bemo/Features/Game/Games/TangramCV/Services/CVToInternalConverter.swift` (new/complete)
  - `Bemo/Features/Game/Games/TangramCV/Views/TangramThreeZoneScene.swift`
  - Optionally: `Bemo/Features/Game/Games/Tangram/ViewModels/TangramGameViewModel.swift`, `TangramSpriteView.swift` to unify any rotation logs to one convention.

This plan eliminates the rotation sign mismatch entirely, aligns both games with a single transform convention, and confines all screen-space conversions to one utility, making future CV integration straightforward.


----

NOTES:

Concrete changes (Tangram drag-and-drop game)
1) Add a single pose conversion utility
File: Bemo/Features/Game/Games/Tangram/Utilities/TangramPoseMapper.swift
Functions:
rawAngle(from: CGAffineTransform) -> CGFloat
rawPosition(from: CGAffineTransform) -> CGPoint
pieceLocalCentroid(for: TangramPieceType) -> CGPoint // from normalized geometry × visualScale
toSpriteKit(centroidRaw: CGPoint) -> CGPoint // apply any SK Y mapping (e.g., y = -rawY if keeping current SK up)
toSpriteKit(angleRaw: CGFloat) -> CGFloat // consistent angle mapping (e.g., angleSK = -angleRaw if needed)
fromSpriteKit(angleSK: CGFloat) -> CGFloat // inverse if needed later
Purpose: one choke point for raw→SK pose mapping.
2) Fix target silhouette rendering (core issue causing “scattered” target)
File: Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift
Function: createTargetPiece(:)
Replace current behavior with:
Build path centered at the local centroid (like PuzzlePieceNode does).
localVerts = scaled normalized vertices
cLocal = centroid(localVerts)
path uses (v - cLocal)
Compute raw centroid by applying the DB transform to the SAME local centroid:
cWorldRaw = cLocal.applying(target.transform)
Set SpriteKit pose using PoseMapper:
shape.position = toSpriteKit(centroidRaw: cWorldRaw)
shape.zRotation = toSpriteKit(angleRaw: rawAngle(from: target.transform))
Do NOT bake rotation into vertices, and do NOT invert vertex Y manually. Rotation should be applied via node.zRotation; translation via node.position; path centered at centroid. This exactly matches how CV will be consumed later (ID + angle + translation).
3) Keep pieces consistent with targets
File: Bemo/Features/Game/Games/Tangram/Views/Components/PuzzlePieceNode.swift
Already centers its local path at centroid; keep as-is. Ensure no hidden flips/extra transforms are applied to the node aside from zRotation/position.
4) Layer positioning stays orthogonal
File: Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift
After creating target nodes, you can reposition puzzleLayer to center the full puzzle group on screen (based on puzzle bounds) — that’s fine. This must not alter the local transforms of pieces; it’s just a parent translation.
5) Validation (alignment with rendering, to avoid future surprises)
File: Bemo/Features/Game/Games/Tangram/Services/TangramPieceValidator.swift
For sprite checks, compute the target SK pose via PoseMapper (angleSK, positionSK) and compare to the piece’s zRotation/position. No negations inside the validator; both sides must be in SK space.
Keep symmetry/flip rules unchanged.
6) Hints (angle consistency)
File: Bemo/Features/Game/Games/Tangram/Services/TangramHintEngine.swift
When showing rotation/ghost hints, compute target angle in SK space using PoseMapper and pass that to the renderer. No raw angles in rendering.
7) Tag nodes with stable IDs (mirrors CV IDs)
Wherever you instantiate PuzzlePieceNode and target shapes:
Assign a stable name and attach userData with the piece’s DB ID (or a generated stable ID that matches DB).
This mirrors the CV pipeline later where detections come with IDs, and makes it trivial to match visuals to data.
8) Document the conventions (tiny header note)
In TangramPoseMapper.swift, document:
Zero angle axis and direction.
Whether angleSK = -angleRaw or angleSK = angleRaw (choose one and stick to it).
Whether positionSK.y = -rawY (if you keep current SpriteKit Y-up choice).
This makes future CV integration trivial: CVToInternalConverter creates raw transforms identical to DB style, PoseMapper renders them.
Why this is the best prep for real CV
It matches exactly the interface you’ll have: piece ID + raw rotation/translation. The game no longer relies on shape-baked transforms for targets; it renders from raw pose through a stable mapping at the view boundary.
It avoids the current “scattered target” failure by rotating around the correct pivot (centroid) and translating the rotated shape via the transformed centroid — same as applying the full matrix.
Validation, snapping, and hints all share one conversion; no sign flips sprinkled across code.
Sanity checks after edits
Load any DB puzzle (e.g., the cat). The target silhouette should be exactly composed, not scattered.
Toggle visibility of target vs movable pieces; their relative geometry should match 1:1.
Rotate/position a piece to match; rotation/hints should align visually and pass validation.
Files to touch (summary)
Add: Bemo/Features/Game/Games/Tangram/Utilities/TangramPoseMapper.swift
Edit:
Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift (createTargetPiece: centroid-centered path + pose via PoseMapper)
Bemo/Features/Game/Games/Tangram/Services/TangramPieceValidator.swift (ensure SK-vs-SK comparisons)
Bemo/Features/Game/Games/Tangram/Services/TangramHintEngine.swift (supply SK angles/positions)
Optionally tag nodes with IDs where pieces/targets are constructed.
This sets the drag-and-drop Tangram game to the same pose contract we’ll receive from CV, so when we wire in CV (IDs + angle + translation), it’s a straight path: CVToInternalConverter → raw transform → PoseMapper → render/validate.