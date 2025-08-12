I’m going to scan the Tangram game code to understand current validation, hints, nudges, snapping/grouping, and CV event handling, and also read your explainer docs to align with intended behavior. Then I’ll outline how it works today and propose a robust validation/hint/nudge architecture that matches real-world play and is CV-ready.
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

Scanning the Tangram game’s validation, hint, nudge, grouping, geometry, and event flow code and explainer docs to map current behavior and design a robust CV-ready system.
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
Ran tool
Ran tool

Ran tool

### What I inspected
- Code: `TangramPuzzleScene.swift`, `TangramPuzzleScene+Zones.swift`, `PuzzlePieceNode.swift`, `ConstructionGroupManager.swift`, `TangramPieceValidator.swift`, `TangramRotationValidator.swift`, `TangramHintEngine.swift`, `TangramPoseMapper.swift`, `TangramGeometryUtilities.swift`, `TangramGameViewModel.swift`, `CVEvent.swift`, `CVEventBus.swift`, `GamePuzzleData.swift`, `TangramGame.swift`
- Docs: `.mitch-docs/explainers/cv-game.md`, `.mitch-docs/explainers/tangram-game-math-validation.md`, `.mitch-docs/cv-game-fix.md`

### How it works today (short)
- Geometry/angles
  - Uses feature-angle validation: triangles use canonical piece 135° and canonical target 45°, with SpriteKit’s zRotation sign-flip handling.
  - Centralized angle/space conversions in `TangramPoseMapper`.
- Target rendering
  - Target silhouette paths are “baked vertices” at zRotation=0, with real rotation baked into vertices for visual accuracy.
- Validation (SpriteKit scene)
  - Pieces spawn bottom; piece state flows to placed → validating → validated/invalid.
  - Construction groups form by proximity; anchor-based rigid mapping is created and refined with ≥2 validated pairs.
  - Validation uses feature angles and instance binding per piece (assigned target id) with hysteresis to prevent flicker.
- Hints/nudges
  - Hints show in the top target panel; rotation hints now compute desiredZ using feature-angle math (fixes triangle 90° issue).
  - Nudges escalate via `SmartNudgeManager` and are displayed top-only (piece indicators at bottom are suppressed).
- CV mock
  - Bottom emits CV-like events which feed a mini CV display and validation feedback.
- ViewModel (non-SpriteKit CV path)
  - A parallel “CV mock” validator path uses `GamePuzzleData.TargetPiece.matches(PlacedPiece)`.

### Key places in code
```1045:1315:/Users/mitchellwhite/Code/bemo-app/Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift
// validatePlacedPiece(...) — per-group anchor mapping, feature-angle validation, instance-binding filter, hysteresis, nudges
```

```2146:2238:/Users/mitchellwhite/Code/bemo-app/Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift
// showHint(for:) — desiredZ = pose.zRotationSK + canonicalTarget - canonicalPiece (triangles 45° vs 135°)
```

```25:81:/Users/mitchellwhite/Code/bemo-app/Bemo/Features/Game/Games/Tangram/Services/TangramPieceValidator.swift
// validateForSpriteKitWithFeatures(...) — feature-angle validation with symmetry and flip
```

```101:143:/Users/mitchellwhite/Code/bemo-app/Bemo/Features/Game/Games/Tangram/Services/TangramPieceValidator.swift
// validate(placed:target:) — legacy-like path: raw zRotation vs expectedZRotationSK (no feature-angle)
```

```506:529:/Users/mitchellwhite/Code/bemo-app/Bemo/Features/Game/Games/Tangram/ViewModels/TangramGameViewModel.swift
// validatePieces() — uses target.matches(placed) → legacy orientation path
```

### What’s wrong/misaligned
- Validation path divergence:
  - SpriteKit scene uses the correct feature-angle math; the ViewModel CV path uses `TargetPiece.matches()` → `TangramPieceValidator.validate(placed:target:)` which compares raw zRotation to expectedZRotationSK without canonical feature offset. This causes triangle rotations to “validate wrong” on the CV path.
- Snap rotation still uses raw expected zRotation:
  - `checkAndSnap` uses `expectedZRotationSK` ± mapping delta; it should use the same desiredZ feature-based formula used by hints to visually align with baked silhouettes.
- Zones
  - Zones have been de-emphasized in validation but are still used by nudges. The design direction is to fully remove zone-gating in favor of cluster/stability-based intent.
- Instance binding exceptions
  - Non-anchor pieces strictly enforce `assignedTargetId`, but anchor selection picks nearest target of the same type (may override the piece’s initial “assignment”). That’s probably okay if you also update the piece’s assigned id on anchor bind to make duplicates robust.
- “Validate single isolated piece” vs “validate connected relation”
  - Current scene does allow the anchor to validate alone (reward). If you want “validate only when 2+ pieces form a relation,” anchor validation should either:
    - be a non-counting “anchor accepted” reward, or
    - count only after the second mapped piece validates.

### Proposed robust design (CV-ready)
- Single math path everywhere
  - Always compute desired piece zRotation via feature angles:
    - desiredZ = targetFeatureAngle − pieceLocalFeatureAngle
    - targetFeatureAngle = expectedZRotationSK + canonicalTarget (45° triangles, 0° others)
    - pieceLocalFeatureAngle = canonicalPiece (135° triangles, 0° others), sign-negated if flipped
  - Use this for hints, snap previews/snaps, validation, and angle deltas. No mixed raw-angle paths.
- Intent-first validation
  - Clustering + stability gate validation; zones removed.
  - Anchor-based relative mapping:
    - Select anchor (prefer validated > largest stable > most central).
    - Bind anchor to an instance target (update `assignedTargetId`), reward with “anchor accepted” but optionally don’t count as progress until ≥2 pieces validate within the mapping.
    - Validate subsequent pieces only via relative mapping + their specific assigned target.
    - Refine rigid mapping when ≥2 pairs validated; maintain hysteresis.
- Instance-based target binding
  - Every piece is bound to a specific target id (handle duplicates). Allow one rebind per piece if clearly closer and not consumed; lock again.
- Hints vs nudges
  - Bottom area shows only piece visuals; all teaching lives in the top panel.
  - Single-piece feedback uses subtle nudges (rotate/flip/“good job”).
  - Multi-piece relations trigger silhouette validation and directed nudges toward connections.
  - Progressive escalation and auto-clear timers, with cooldown history.
- CV integration
  - Same math and validation logic runs on CV data by converting raw CV transforms into the same “SpriteKit-space” quantities via `TangramPoseMapper`.
  - The ViewModel path must use the same feature-angle validator and instance-binding logic, not the legacy `validate(placed:target:)`.

### Concrete changes to make
- Unify math and snap behavior
  - In `TangramPuzzleScene.checkAndSnap`: compute snap rotation with desiredZ using feature angles (same as `showHint`), not raw `expectedZRotationSK`.
- Remove remaining zone-gating and logs
  - Keep `determineZone` only if you want display-only analytics; don’t gate validation or nudge timing by zone.
- Strict instance-binding everywhere
  - On anchor mapping, update the anchor piece’s `assignedTargetId` to the selected target. Keep per-group consumed sets.
  - For all pieces, filter candidate targets by assigned id; allow controlled rebind if closer by margin and not consumed.
- ViewModel CV path: migrate to feature-angle validator
  - Replace `GamePuzzleData.TargetPiece.matches(PlacedPiece)`/`TangramPieceValidator.validate(placed:target:)` with the feature-angle method:
    - Compute `pieceFeatureAngle` from `PlacedPiece.rotation` + canonical piece baseline (and flip).
    - Compute `targetFeatureAngle` from `CGAffineTransform` rotation + canonical target baseline.
    - Use `validateForSpriteKitWithFeatures(...)` and report state accordingly.
  - This gives parity between SpriteKit and CV paths.
- Validation gating for “2+ pieces”
  - Option A (recommended): Reward anchor visually, but don’t count toward completion until at least one more piece validates within the mapping (i.e., first relation established).
  - Option B: Validate anchor only when a second piece is in proximity and mapping confidence exceeds threshold; until then, only show “anchor accepted” feedback.
- Hints/nudges consistency
  - Ensure all hint rotations use desiredZ (already implemented in `showHint`).
  - Keep hints/nudges top-only; ensure bottom-hourglass or similar indicators stay off.
  - Maintain cooldown and escalation logic in `SmartNudgeManager`.
- Initial layout sanity
  - Keep clamping to ensure all pieces start fully on-screen. Prefer small initial rotations to help kids read the shape.

### File-level edits (high-level)
- `TangramPuzzleScene.swift`
  - checkAndSnap: compute rotation with desiredZ (feature-based).
  - validatePlacedPiece: after anchor bind, set the piece’s `assignedTargetId` to the chosen target; optionally treat anchor as “accepted” but not counted until second piece validates.
  - Keep/no-op any zone checks and remove residual zone logs.
- `TangramPuzzleScene+Zones.swift`
  - Retain helper only if used for analytics; decouple from validation/nudges.
- `SmartNudgeManager.swift`
  - Remove zone-based gating and thresholds; use group confidence, attempts, and time-based stability only.
- `TangramPieceValidator.swift`
  - Deprecate `validate(placed:target:)` or re-implement to call `validateForSpriteKitWithFeatures` by computing piece/target feature angles.
- `GamePuzzleData.TargetPiece`
  - Update `matches(_:)` to use the new feature-angle path (or remove and have ViewModel call the validator directly).
- `TangramGameViewModel.swift`
  - In `validatePieces()`: replace `target.matches(piece)` with feature-based call:
    - Compute `pieceFeatureAngle` and `targetFeatureAngle` (use canonical baselines + `TangramPoseMapper`), then call `validateForSpriteKitWithFeatures`.
  - Track per-piece assigned target id in CV path (like scene does) to handle duplicates.
- `TangramHintEngine.swift`
  - Already computes feature angles; keep consistent with `TangramPuzzleScene.showHint`.

### Why this will fix the observed issues
- Triangles 90° hint/rotation mismatch goes away by using the same desiredZ feature-angle formula for hints, snap, and validation.
- Wrong triangle validates: strict per-piece instance binding (with optional, controlled rebind) prevents consuming the “other” duplicate.
- Zone artifacts/logs: removing zone gating aligns with real CV behavior and reduces surprising gating.
- “Validate only when pieces relate”: gating counting until the second mapped piece validates ensures progress is tied to construction, not isolated rotations.
- CV readiness: the ViewModel path will use the same math/logic, so when hardware CV is plugged in, everything behaves identically.

### Minimal implementation sequence
1) Unify snap rotation with feature-angle desiredZ (scene).
2) Enforce instance binding consistently; update assigned id on anchor bind (scene).
3) Remove zone gating from nudges/validation; keep only cluster/stability (scene + SmartNudgeManager).
4) Switch ViewModel validation to `validateForSpriteKitWithFeatures` by computing feature angles (CV path).
5) Optional: adjust “anchor accepted” vs “validated” counting to require 2+ pieces before counting progress.
6) Quick QA: triangle orientations, parallelogram flip, duplicate triangles, hint rotations, snap behavior, CV mock parity.

- If you want, I can apply these edits now in the listed files.

- A reminder: you asked me to deep dive `.mitch-docs/explainers/cv-game.md` and `tangram-game-math-validation.md`. The proposed changes follow those docs exactly: single feature-angle path, instance-based tracking, cluster/stability intent detection, and top-only teaching UI.

- Let me know if you prefer anchor to be “accepted but not counted” until the second piece, and I’ll wire that version.

- I can proceed with the implementation next. 

- Edits will touch: `TangramPuzzleScene.swift`, `TangramPuzzleScene+Zones.swift`, `SmartNudgeManager.swift`, `TangramPieceValidator.swift`, `GamePuzzleData.swift`, `TangramGameViewModel.swift`.

- I’ll run a build and quick manual test of triangles + parallelogram orientation and duplicate triangles after the edits.

-------

### Goal
Unify CV and SpriteKit paths around cluster/anchor-relative validation with strict instance-binding, no zones, single math path (feature angles), and DRY shared services. Zero deprecated paths left.

### New files to add
- Bemo/Features/Game/Games/Tangram/Protocols/TangramGrouping.swift
  - Define a tiny protocol to make grouping generic across SK and CV:
  - `protocol GroupablePiece { var id: String {get}; var position: CGPoint {get}; var rotation: CGFloat {get}; var isFlipped: Bool {get} }`

- Bemo/Features/Game/Games/Tangram/Services/TangramRelativeMappingService.swift
  - Single source of truth for per-group rigid mapping and validation orchestration (used by both Scene and ViewModel).
  - Public API (suggested):
    - `func updateGroups<T: GroupablePiece>(pieces: [T]) -> [ConstructionGroup]`
    - `func establishOrUpdateMapping(for group: ConstructionGroup, pieces: [GroupablePiece], targets: [GamePuzzleData.TargetPiece], pieceStates: [String: PieceState?]) -> AnchorMapping?`
    - `func mapPieceToTargetSpace(piece: GroupablePiece, mapping: AnchorMapping, anchorPiece: GroupablePiece) -> (positionSK: CGPoint, rotationSK: CGFloat, isFlipped: Bool)`
    - `func validateMapped(piece: GroupablePiece, target: GamePuzzleData.TargetPiece, mappedPose: (pos: CGPoint, rot: CGFloat, isFlipped: Bool)) -> Bool`
    - `func refineMapping(groupId: UUID, pairs: [(pieceId: String, targetId: String)], piecesProvider: (String)->CGPoint, targetsProvider: (String)->CGPoint) -> AnchorMapping`
    - `func inverseMapTargetToPhysical(mapping: AnchorMapping, anchorScenePos: CGPoint, targetScenePos: CGPoint) -> CGPoint`
  - Internal model:
    - `struct AnchorMapping { translationOffset: CGPoint; rotationDelta: CGFloat; flipParity: Bool; anchorPieceId: String; anchorTargetId: String; version: Int; pairCount: Int }`
    - `var groupIdToMapping: [UUID: AnchorMapping]`
    - `var groupIdToConsumedTargets: [UUID: Set<String>]`
    - `var groupIdToValidatedPairs: [UUID: [(pieceId:String, targetId:String)]]`
  - Moves/centralizes code that currently lives in `TangramPuzzleScene` for mapping and refinement, and exposes inverse-mapping for nudges.

- Bemo/Features/Game/Games/Tangram/Services/TangramSceneAdapter.swift
  - Adapters to treat `PuzzlePieceNode` as `GroupablePiece` and to provide scene-to-service conversions (scene/section conversions, access to silhouette centroid, expected rotation, flip).
  - Keeps `TangramPuzzleScene` slim and testable.

- Bemo/Features/Game/Games/Tangram/Services/TangramCVAdapter.swift
  - Adapters to treat `PlacedPiece` as `GroupablePiece` for the ViewModel CV path.

- BemoTests/TangramRelativeMappingServiceTests.swift
  - Unit tests: rigid transform estimation, re-anchoring, refinement, and inverse mapping; triangle/square/parallelogram rotation correctness.

### Files to edit
- Bemo/Features/Game/Games/Tangram/DependencyInjection/TangramDependencyContainer.swift
  - Add and construct new services:
    - `let mappingService: TangramRelativeMappingService`
    - Reuse existing `ConstructionGroupManager` (or inject through mapping service).
    - Inject `mappingService` into ViewModel and Scene creation paths.

- Bemo/Features/Game/Games/Tangram/Views/TangramPuzzleScene.swift
  - Replace internal mapping structs (`groupAnchorMappings`, `groupValidatedTargets`, `groupValidatedPairs`) with calls to `mappingService`.
  - Establish/update mapping:
    - Use `mappingService.updateGroups` (via SceneAdapter) to get groups.
    - Call `mappingService.establishOrUpdateMapping` for the piece’s group (anchor selection logic moves into service).
  - Validation flow:
    - For non-anchors: compute mapped pose via `mappingService.mapPieceToTargetSpace`, validate against assigned target only (instance-binding).
    - After ≥2 pairs, call `mappingService.refineMapping`.
  - Nudges:
    - Replace inline inverse-mapping code with `mappingService.inverseMapTargetToPhysical`.
  - Hints:
    - Already using desiredZ; keep. Prefer assigned target id when selecting a target (done).
  - Events:
    - Keep fixed: map target id → piece id for CV mini feedback (done).
  - Remove any residual zone references (already removed).

- Bemo/Features/Game/Games/Tangram/ViewModels/TangramGameViewModel.swift
  - Integrate `mappingService` for CV path:
    - Use `mappingService.updateGroups` (via CVAdapter) to discover clusters.
    - Maintain per-group mapping via `establishOrUpdateMapping`.
    - For each piece, if group has mapping, map into target space, validate against assigned target id (persisted via `pieceAssignments`), refine mapping after ≥2 pairs.
    - Preserve strict instance-binding and persist it (`pieceAssignments`, already added).
  - Preserve existing feature-angle math through `GamePuzzleData.TargetPiece.matches` or move to `mappingService.validateMapped` to be fully centralized.

- Bemo/Features/Game/Games/Tangram/Services/ConstructionGroupManager.swift
  - Keep the existing implementation for SK nodes.
  - Add a generic overload to support grouping of `GroupablePiece`:
    - Either with `pieces: [GroupablePiece]` or by passing closures for `id` and `position`.
  - Remove remaining zone-related names (already renamed thresholds; ensure comments and names reflect “intent-only” not zones).

- Bemo/Features/Game/Games/Tangram/Services/SmartNudgeManager.swift
  - No zone inputs (already done).
  - Optionally add overloads that accept `inverseMapTargetToPhysical` from `mappingService` to DRY mapping usage (scene calls back into service).

- Bemo/Features/Game/Games/Tangram/Services/TangramPieceValidator.swift
  - Already deprecates legacy methods; keep only `validateForSpriteKitWithFeatures`.
  - Ensure no deprecated calls remain in codebase.

- Bemo/Features/Game/Games/Tangram/Models/GamePuzzleData.swift
  - `TargetPiece.matches` already uses feature-angle path. Keep.

- Bemo/Features/Game/Games/Tangram/Views/TangramSpriteView.swift
  - Inject `mappingService` into `TangramPuzzleScene` on creation.

- Bemo/Features/Game/Games/Tangram/TangramGame.swift
  - Ensure ViewModel receives `mappingService` through its container.

### Behavior details to port into TangramRelativeMappingService
- Anchor selection
  - Prefer validated > largest stable > most central; if anchor invalidates (moved/removed), re-elect anchor and recompute mapping.

- Establish mapping
  - Pick anchor target among unconsumed duplicates by nearest silhouette centroid in SK space.
  - Compute `rotationDelta` (targetZ − anchor.zRotation), `translationOffset` (target centroid − anchor pos), and `flipParity`.

- Instance binding
  - On anchor binding, set `assignedTargetId` for the anchor piece; store consumed target in group state.
  - For all non-anchors, only evaluate the piece’s assigned target id (allow one controlled rebind when closer by margin and not consumed).

- Mapped validation
  - Compute piece mapped position/rotation relative to anchor, add `rotationDelta`, apply `flipParity` for parallelogram, and validate with feature angles + tolerances.

- Refinement
  - With ≥2 validated pairs, re-estimate rigid transform (average angle diffs + mean translation) and bump `version`. Keep hysteresis to avoid flicker.

- Inverse mapping for nudges
  - Provide a method to compute the physical position that would appear at a target centroid under the current mapping.

### Cleanup and DRY
- Remove all deprecated/legacy methods from `TangramPieceValidator` after verifying zero references.
- Eliminate any duplicate math snippets for desiredZ; one helper in a small `TangramRotationMath` extension or within `TangramRelativeMappingService` is acceptable.
- Ensure no zone mentions remain in code or comments.
- Keep canonical angles and tolerances centralized in `TangramGameConstants`.

### Tests
- Unit tests in `BemoTests/TangramRelativeMappingServiceTests.swift`:
  - Rigid mapping estimation correctness with synthetic pairs.
  - Inverse mapping round-trip sanity.
  - Re-anchoring and refinement behavior with noisy inputs.
  - Triangle/square/parallelogram rotation validation via feature angles (including flip).
  - Duplicate handling: instance-binding prevents cross-consumption.

### Migration plan
- Step 1: Add protocols and new services (mapping + adapters).
- Step 2: Update container to expose mapping service.
- Step 3: Refactor scene to call mapping service; remove internal mapping structs.
- Step 4: Wire ViewModel to mapping service for CV path; keep `pieceAssignments`.
- Step 5: DRY inverse mapping calls in nudges via service.
- Step 6: Run build, add unit tests, verify manual scenarios (triangles, parallelogram, duplicates, hints/snaps parity, CV mock parity).
- Step 7: Delete any leftover dead code/paths; scan for deprecated use.

- If you approve, I’ll implement this plan now.