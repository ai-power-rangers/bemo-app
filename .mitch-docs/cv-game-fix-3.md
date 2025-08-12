- What the logs say
  - largeTriangle1: “[MAP] rot=false, effDist=142… valid=false” → rotation doesn’t match target’s feature angle, and even after edge-contact override, position tolerance still reads too high.
  - largeTriangle2 at 90°: “[MAP] rot=false… valid=false” → target expects ~135° (feature-angle baseline for triangles), so 90° is off. When you put it at 135° and close, you normally see “valid=true.”
  - Repeated “polyDist ≈ 600–800” with “effDist ≈ 100–150” → polygons were not considered “touching,” and position remained outside our current acceptance window.

- Why this feels brittle
  - We mix several gates: centroid proximity, feature-angle rotation, flip, and sometimes polygon-edge distance. These checks have been applied in slightly different spaces/tolerances (scene vs container, static vs dynamic distances). Small changes reweight the outcome and cause regressions.
  - Mapping is computed off one anchor’s feature baseline, then applied to other piece types with different canonical baselines; if the transform or angle baselines aren’t consistently normalized, rotation can show false negatives for other types.
  - Nudges and hints are driven by similar, but not identical, logic. If validator says “rotation is the blocker,” but distance is still above the position gate, “move” nudges win even though rotation is also wrong, which feels contradictory.

- A robust, simple, and unified system (fix once and for all)
  1) Single source of truth for validation
     - Normalize all checks to a single world space (scene coordinates). Never mix container space polygons with scene-space piece poses.
     - For each piece vs target:
       - Flip check: parallelogram only, using determinant; flipValid = (isFlipped != targetIsFlipped).
       - Rotation check: compute feature-angle for both using the canonical baselines, then compute minimal angular difference; rotationValid if within tolerance.
       - Position check: compute BOTH:
         - centroidDistance (scene-space)
         - polygonEdgeDistance (scene-space Hausdorff-lite via min edge-to-edge)
         - positionValid if centroidDistance < centroidTolerance OR polygonEdgeDistance < edgeTolerance
       - OverallValid = flipValid AND rotationValid AND positionValid.
     - Tolerances are difficulty-based:
       - centroidTolerance: easier levels allow larger distances
       - edgeTolerance: 8–14 px depending on difficulty
       - rotationTolerance: stricter at higher difficulty (we set 18°, could be 22° at easy, 18° at medium, 12° at hard)
  2) Stable rigid mapping across types
     - Compute the group rigid transform via a least-squares/Kabsch fit using all established pairs (at least two). Don’t rely on a single anchor’s feature delta for everyone.
     - Steps:
       - pick a seed correspondence (first validated pair) to initialize
       - as more pairs validate, recompute the rigid transform (R, t, optional flip parity) by minimizing Σ‖R*pi + t − ti‖^2 in scene space
       - apply that mapping to predict each piece’s world pose before validation checks
     - This eliminates anchor-type bias and reduces rotation drift across piece types.
  3) Hysteresis and non-regression
     - Once a piece validates, keep it valid unless it moves or rotates past a larger “drop-out” threshold (e.g., 1.5× the entry tolerances). Don’t invalidate validated pieces on small mapping updates.
     - Don’t re-anchor once two pairs exist; only refine mapping by least-squares. No re-anchoring churn.
  4) Unified nudge controller
     - Build nudges directly from the single validator result:
       - If positionValid=false and rotationValid=false: show “move closer” first; when within centroidTolerance×1.2, switch to rotation nudge.
       - If positionValid=true but rotationValid=false: rotation nudge.
       - If flip invalid: flip nudge immediately.
     - One nudge at a time. Clear on validation or when failure reason changes.
  5) Instance binding post-validation
     - Bind on first successful validation; before that, consider all same-type targets minus consumed ones. This prevents “no candidates” dead-end and avoids random cross-binding.
  6) Logging sanity for debugging
     - Always log (per check, in degrees/px): rotation error, centroidDistance, polygonEdgeDistance, chosen tolerances, and which gate failed. That makes any mismatch obvious.

- Why your triangles “placed correctly” still didn’t validate
  - In your latest logs, large triangles were still rotationally off at the moment of checks (90° vs expected ~135°) and outside position gates (centroid ~300 px or edge distances ~100+ px). With the unified validator and difficulty-based tolerances, “close enough” will validate when rotation is correct and either centroid or polygon-edge distance falls inside the tolerance for the current difficulty.

- What will change perceptually
  - If you place the parallelogram near the correct side but mirrored, you get flip nudge immediately; once flipped, if you’re within easy/medium tolerance, it will validate without forcing exact vertex-to-vertex.
  - If a triangle is near but rotated wrong, rotation nudge will take over once you’re within the position gate; as soon as rotation snaps inside tolerance, it validates consistently.
  - Hints will only pick connected, frontier pieces; no more top-left outliers.

This design removes the brittle branches, uses one consistent math path, and stabilizes behavior across small code changes while aligning nudges tightly to what the validator actually requires.

Ran tool
Ran tool
Ran tool
Ran tool

Ran tool

Ran tool

Ran tool
Ran tool

Ran tool
Plan looks good. I’ll implement difficulty as a first-class setting flowing from parent profile → game host → game (via delegate/config), then wire Tangram to read those tolerances and visuals:

- Add difficulty to preferences
  - Use existing `UserPreferences.DifficultySetting` (easy, normal, hard). Interpret “normal” as medium.
  - Expose current child’s difficulty from `ProfileService` to `GameHostViewModel`.

- Extend GameDelegate or config
  - Add a read method or pass a `GameDifficulty` to the game at view creation time (e.g., via `gameUIConfig` or a small `GameplayConfig` struct).
  - Provide per-difficulty tolerances (centroidTolerance, edgeTolerance, rotationTolerance, connectionDistance) and visual flags (colored outlines on silhouettes).
  - Tangram reads these and:
    - Uses them universally in the single validator path (both direct and mapped).
    - Switches silhouettes: easy = colored outlines; medium = current; hard = black.

- Implement unified validator and mapping
  - Use the single validator path everywhere (flip/rotation/position with polygon or centroid and difficulty thresholds).
  - Use least-squares mapping refinement (already close; continue to refine by pairs; no re-anchoring).
  - Hysteresis: once validated, don’t invalidate unless the piece actually moves beyond relaxed drop-out bounds.

- Nudges/hints alignment
  - Nudges only from the unified validator result; one at a time.
  - Hints only propose connected frontier pieces if any validated exist; otherwise no hint or starter.

This will make difficulty parent-controlled, visuals appropriate, and validation/nudges consistent and robust.