One consistent, elegant CV-first system: design
Unify validation, mapping, hints, nudges into a single service: TangramValidationEngine
Responsibilities:
Ingest current CV snapshot (from bottom world’s ground truth or real CV) and the puzzle.
Manage construction groups and intent gating (via ConstructionGroupManager).
Establish/maintain per-group anchor mapping and refine it with the global optimization method from .mitch-docs/optimization-validation.md.
Validate all pieces exclusively through mapped poses (feature-angle validator), with clean hysteresis; remove direct path.
Perform instance-binding (pieceId → targetId) with bookkeeping for consumed targets.
Produce unified failure reasons per piece (wrongPosition/wrongRotation/needsFlip/wrongPiece).
Decide nudge display using SmartNudgeManager and the same failure reasons (single source of truth).
Generate structured hints on request via TangramHintEngine, parameterized by validated ids and difficulty.
Outputs:
Validated targets set, piece validation states, bindings, refined mapping, optional NudgeContent to display, and an optional HintData when requested.
Integrate optimization-based mapping
Implement optimizeGlobalTransform in TangramRelativeMappingService to compute the best rotation Θ by 1D search (grid or Brent), then T by centroid alignment, exactly as in the doc.
Use this in two places:
Initial group mapping: instead of pairing a single anchor to nearest target and deriving a feature-angle delta, solve for Θ and T minimizing the weighted sum of squared positional and angular distances between the group’s current piece poses and the target’s local configuration (only for pieces the group attempts/assigns; start with anchor + any validated/strongly attempted piece types).
Refinement: replace/refactor current refineMapping with the optimization-based solver when you have at least two pairs; choose wt, wr from difficulty or dynamic heuristics.
Keep flip parity handling explicit; feed isFlipped into the angular term; try both flip parities for the parallelogram when optimizing or use parity from anchor-target pairing.
Single tolerance source
Route all tolerances through TangramGameConstants.Validation.tolerances(for:).
Update TangramHintEngine to read tolerances via this API (remove its hard-coded rotation/position tolerances).
Ensure SmartNudgeManager messages use unified tolerances for computing “close” vs “far” and “specific”.
Single failure reason source
Always derive failure reasons via validateMappedDetailed in mapping service (feature-angle compare + polygon contact).
SmartNudgeManager uses these reasons to pick level/content.
TangramHintEngine uses these reasons when building “rotation/flip/position” hint types for last-moved incorrectly.
Guidance policy
Nudges: automatic when stuck/nearby based on group confidence, attempts, cooldown, and failure reason; always rendered in top target panel; only one visible at a time.
Hints: explicit user action or ViewModel-initiated based on “stuck too long”; rendered in top target panel; do not conflict with nudges (silence nudges while a hint is playing).
Implementation plan (edits by area)
New service
Add Bemo/Features/Game/Games/Tangram/Services/TangramValidationEngine.swift
API:
process(frame: [PieceObservation], puzzle: GamePuzzleData, difficulty: UserPreferences.DifficultySetting, options: ValidationOptions) -> ValidationResult
requestHint(context: HintContext) -> TangramHintEngine.HintData?
Internals: wrap ConstructionGroupManager, TangramRelativeMappingService, TangramPieceValidator, SmartNudgeManager, TangramHintEngine.
Mapping optimization
Update TangramRelativeMappingService:
Add optimizeGlobalTransform implementing the doc’s 1D Θ search (start with coarse grid 2° then refine 0.25° or Brent), compute T*(Θ) via centroid alignment; support piece-wise angular costs with canonical feature offsets; options for weights wt, wr.
Use it for:
New establishOrUpdateMappingOptimized(groupId: ..., pieces: [PiecePose], candidateTargets: [TargetPose], difficulty: ...).
Replace refineMapping(...) with an optimized variant using available pairs/pieces; keep the existing method signature for compatibility but delegate to the new solver.
Keep flip parity logic and evaluate both parities for the parallelogram when appropriate; choose minimal cost.
Consolidation and removal
TangramSceneValidator:
Remove tryDirectValidation and completeDirectValidation. Route validation through TangramValidationEngine.
Keep completeValidation as a thin renderer/update layer, but its call sites now consume results from the engine rather than re-computing validation.
Keep hysteresis based on the engine’s last valid pose info.
TangramPieceValidator:
Keep only validateForSpriteKitWithFeatures; mark legacy methods as removed (or fatalError in debug).
TangramHintEngine:
Replace local tolerance constants with calls to TangramGameConstants.Validation.tolerances(for:).
Accept validated ids from the engine (no local caching needed).
Ensure canonical features use TangramGameConstants.CanonicalFeatures.
SmartNudgeManager:
No behavior change; ensure inputs come from engine’s failure reasons and group state; leave thresholds and cooldowns centralized.
TangramGameViewModel:
Replace validatePieces() with a call to TangramValidationEngine.process(...).
Replace local instance-binding logic with engine results.
Keep requestStructuredHint() but delegate to engine’s hint method; pass along validatedTargetIds received from scene via syncValidatedTargetIds.
TangramPuzzleScene:
On touch/move/place: continue to emit CV events; but validation calls are delegated to the engine using a “scene snapshot” adapter to PieceObservation.
Keep showSmartNudgeInTarget and showHint(for:) as pure renderers, driven exclusively by engine outputs.
Ensure the top target panel is the only place for visual nudges/hints; remove any bottom nudge remnants (already no-op).
CV event bus and top-panel consumption
No structural change to CVEventBus.
Ensure the scene constructs a PieceObservation array from current bottom pieces or from CVFrameEvent (mock path), then calls the engine on a cadence:
On placement confirmation, on significant movement end, and periodically when idle with dwell (to catch “stuck”).
Keep cvMiniDisplay purely for debugging/visibility; main guidance lives over the target silhouettes.
Difficulty handling
Propagate difficulty from TangramGameViewModel to the engine; the engine uses TangramGameConstants.Validation.tolerances(for:) everywhere.
Edge cases
Parallelogram flip: handled uniformly via validateMappedDetailed and nudge promotion to “specific” when flip is the blocker.
Duplicate piece types: preserve instance-binding exclusively through engine; disallow target switching once assigned unless invalidation unbinds.
Testing and migration
Remove/disable legacy direct validation; ensure all tests and flows pass via engine mapping-only.
Verify hysteresis behavior is preserved (invalid streak threshold, relaxed tolerances).
Validate that onValidatedTargetsChanged from scene uses engine’s validated set (no local re-derivation).
Ensure TangramHintEngine animations align with pose scale/rotation exactly (uses resolvePoseLocal which uses canonical feature math).
Deliverables and file changes
Add: Services/TangramValidationEngine.swift (new)
Update:
Services/TangramRelativeMappingService.swift: add optimization solver and delegate refine/establish to it.
Views/Components/TangramSceneValidator.swift: delete direct path; delegate to engine; keep completion visuals.
Services/TangramPieceValidator.swift: remove deprecated methods.
Services/TangramHintEngine.swift: use unified tolerances and canonical features; no custom constants.
Services/SmartNudgeManager.swift: no API change; ensure usage from engine.
ViewModels/TangramGameViewModel.swift: switch to engine for validation and hints; remove local binder.
Optional cleanup:
Remove any now-unused helpers duplicating polygon-distance or angle mapping if only used by deleted paths.
Success criteria
One validation path: mapping-based with global optimization T, Θ per-group; no direct ad-hoc validation.
One tolerance source: TangramGameConstants.Validation.
One failure-reason source feeding both nudges and hints.
Bottom emits CV events; top consumes them; top target panel is where all guidance appears; CV mini stays for visibility.
Parallelogram + duplicates handled with stable instance-binding and flip-aware validation/nudges.
No leftover legacy methods; no duplicated logic between Scene and ViewModel.
Status update:
Mapped current validation, mapping, hint/nudge, and CV flows across TangramPuzzleScene, TangramSceneValidator, TangramRelativeMappingService, TangramPieceValidator, SmartNudgeManager, TangramHintEngine, and TangramGameViewModel. Drafted a unified engine-centric plan that integrates your optimization doc’s (T, Θ) solver into mapping, removes direct validation, unifies tolerances and failure reasons, and standardizes guidance rendering in the top panel.
Summary
Consolidate validation/hints/nudges into a new TangramValidationEngine that wraps grouping, mapping (with the doc’s optimization), validation, binding, and guidance.
Remove direct validation; use mapping-only with feature-angle validator and polygon-contact fallback.
Unify tolerances via TangramGameConstants.Validation; unify canonical features; share failure reasons across nudges and hints.
Keep bottom→CV events; top panel consumes and renders guidance; scene and VM both delegate to the engine.