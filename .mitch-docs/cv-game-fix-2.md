I'm going to scan the explainer docs you mentioned and then search the Tangram game code for snapping/auto-rotation, validation logic, bottom panel drag-and-drop, CV event flow, and the nudges and hints systems to identify issues and propose a cleanup plan. Running these lookups in parallel for speed.
Ran tool
Ran tool
Ran tool
Ran tool
Ran tool
Ran tool
Ran tool
Ran tool
Ran tool
Ran tool
Ran tool
Ran tool
Ran tool

Scanning the Tangram code for snapping/auto-rotation, validation gating, colors, and the nudges/hints implementations to produce a concrete cleanup plan that matches the docs and your requirements.
Ran tool
Ran tool
Ran tool
Ran tool
Ran tool
Ran tool
Ran tool

I reviewed the explainer docs and scanned the Tangram game implementation for snapping/auto-rotation, validation gating, colors, CV event emission, and nudges/hints. Below is a concise, actionable cleanup plan to match the “mock physical world → emits CV events” goal, while removing unrealistic behaviors in the bottom panel and tightening validation/hinting.

### Key problems found (with code cites)
- Snapping and auto-rotation still active in bottom panel:
```753:787:Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift
// Check for snap preview
checkSnapPreview(for: selected)
// Check for snap
checkAndSnap(piece: selected)
```
```934:989:Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift
private func checkAndSnap(piece: PuzzlePieceNode) {
    // ... animate snap
    // Snap rotation using feature angles (same formula as hints)
}
```
```23:27:Bemo/Features/Game/Games/Tangram/Views/Components/TangramRotationDialNode.swift
// Angle snapping configuration
private let snapAngles: [CGFloat] = [0, 45, 90, 135, 180, 225, 270, 315].map { $0 * .pi / 180 }
private let snapThreshold: CGFloat = 10 * .pi / 180  // Snap within 10 degrees
private var isSnapped: Bool = false
```

- Validation can occur with a single piece (should require two connected or more):
```55:56:Bemo/Features/Game/Games/Tangram/Services/ConstructionGroupManager.swift
// Minimum pieces for validation
static let minPiecesForValidation: Int = 1
```
- Single-piece direct validation fallback is allowed (should be gated by 2+ pieces):
```1232:1268:Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift
// If no anchor mapping yet or validation failed, try direct validation (tight fallback)
let result = validator.validateForSpriteKitWithFeatures(...)
// Direct validation successful...
validatedTargets.insert(target.id)
// Update piece state to validated
updatedState.markAsValidated(connections: [])
```

- Validated visuals use green; should use the piece’s actual color across the UI:
```1984:1987:Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift
silhouette.fillColor = .systemGreen
silhouette.fillColor = .systemGray
```
```1584:1591:Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift
// Green glow for validated pieces
cvPiece.shapeNode?.strokeColor = .systemGreen
```
(There is a correct color path too; make it the only path.)
```1840:1841:Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift
let ui = TangramColors.Sprite.uiColor(for: pieceType)
targetNode.fillColor = ui.withAlphaComponent(0.7)
```

- Bottom-piece nudges still exist (should be top-only):
```1498:1567:Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift
private func showSmartNudge(for piece: PuzzlePieceNode, content: NudgeContent) { ... piece.addChild(nudgeNode) ... }
```

- CV events emission is good; keep it as-is (thresholded deltas + 30fps frame emitter):
```658:809:Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift
eventBus.emit(.pieceLifted(...))
eventBus.emit(.pieceMoved(...))
eventBus.emit(.piecePlaced(...))
emitCVFrameUpdate()
```
```35:55:Bemo/Features/Game/Games/Tangram/Events/CVEventBus.swift
// Start emitting frame events at ~30fps like real CV hardware
func emitFrame(_ frame: CVFrameEvent)
```

### Cleanup plan (focused, minimal scope changes)
- Disable all snapping/auto-rotation in the bottom panel
  - Remove snap preview and snap calls during drag in the physical section:
    - No-op `checkSnapPreview` and `checkAndSnap` or guard them behind a `isPhysicalBottomSection` flag set to false for snapping.
    - Remove/disable 45° snapping in rotation dial:
      - Add a `enableAngleSnapping: Bool` toggle defaulting to false for bottom panel; if disabled, skip snapping logic and green snap indicators.

- Validation must require 2+ connected pieces (or 2+ in a construction group)
  - Change the minimum from 1 to 2:
```55:56:Bemo/Features/Game/Games/Tangram/Services/ConstructionGroupManager.swift
static let minPiecesForValidation: Int = 2
```
  - Gate the “direct validation” fallback by group size:
    - In `validatePlacedPiece`, only allow direct validation path if the piece’s group has ≥ 2 pieces or a detected valid connection, otherwise do not mark validated, only “accepted anchor” visual (no completion progress).

- Ensure validated visuals use the correct piece color (not green)
  - Replace all silhouette “green fill” updates with `applyValidatedFill(...)` or direct usage of `TangramColors.Sprite.uiColor(for:)`.
  - In CV mini panel, replace green stroke for validated with the piece type color stroke or a glow in that color (leave red/yellow/blue for other transient states if you want, but not green for “correct”).
    - Specifically, remove/change:
```1984:2001:Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift
silhouette.fillColor = .systemGreen
silhouette.fillColor = .systemGreen
```
    - And:
```1584:1591:Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift
cvPiece.shapeNode?.strokeColor = .systemGreen
```

- Keep nudges top-only; remove bottom-piece nudges
  - Remove the piece-level `showSmartNudge(for piece: ...)` usage. All nudges should render in the target (top) section via `showSmartNudgeInTarget(...)`.
  - Ensure SmartNudgeManager keeps cooldown, attempt, and confidence logic; no zone gating.

- Maintain feature-angle math everywhere; remove legacy paths
  - Confirm the ViewModel CV path uses the same validator and mapping as the scene:
    - Prefer `container.mappingService.validateMapped(...)` and avoid legacy `validate(placed:target:)`.
    - If `TargetPiece.matches` still uses a legacy angle path, refactor it to call the feature-angle validator (ensure triangles’ 45°/135° canonical logic).
  - Keep a single formula for “desiredZ” in hints, any future snap previews (even if disabled now), and validation.

### Optional quality improvements (low-risk)
- Add a “bottom panel realism” config to `TangramPuzzleScene`:
  - `enableBottomSnapping = false`
  - `enableAngleSnapping = false`
  - `allowSinglePieceValidation = false`
  - Wire checks in the two snapping functions, rotation dial node, and direct validation fallback.

- UX polish for bottom panel realism
  - Slight randomization of initial rotations and positions to mimic a real dump of pieces.
  - Keep thresholds for emitting `pieceMoved`/`pieceRotated` events to reduce noise; already implemented.

### Acceptance tests (manual)
- No angle snapping when rotating a piece; no position snapping when close to silhouette or another piece.
- A single placed piece never validates or turns its silhouette green; once a second piece is connected (or in the same group with confidence), validation and correct-color fill occur.
- Validated silhouettes fill with the correct piece color (never green).
- CV mini panel shows “correct” state with the piece’s color (not green), and still shows invalid/moving states distinctly.
- Nudges appear only in the top target section; bottom pieces do not show inline nudges.
- Hints remain structured and tracked; hint button continues to operate.

### Risks and mitigations
- Removing snap can make fine placement harder in bottom panel. That’s desired for realism, but we can keep optional “structured hints” and “directed arrows” in the top panel to compensate.
- Tightening validation to 2+ pieces reduces early dopamine hits. Consider a subtle “anchor accepted” flair without counting progress or changing silhouette color until a second piece validates.

- - -

- Set `minPiecesForValidation` to 2 and gate direct validation by group size.
- Disable `checkSnapPreview/checkAndSnap` and angle snapping in `TangramRotationDialNode` for the bottom.
- Replace all green validation fills with piece-type color via `TangramColors.Sprite.uiColor(...)`. 
- Remove bottom-piece nudges; keep top-only nudges.
- Ensure the CV path and scene share the same feature-angle validator and mapping service for parity.