Immediate Next Steps:

### What’s already covered vs `.mitch-docs/next-steps.md`
- **Anchor mapping (pair-based)**: Implemented. `process()` selects an oriented pair and computes mapping via centroid + relative rotation (`computePairDocMapping`), commits with strict/relaxed gates, logs residuals.
- **Orientation-first feedback**: Implemented. Orientation-only “Good job” nudges and flip/rotate demos; silhouette orientation fill is wired in the CV mirror, but the main silhouette fill in `CVValidationBridge.applyValidationResults` is commented out.
- **Relative validation after anchor**: Implemented. Remaining pieces validated in mapped SK space.
- **Global optimizer**: Implemented in `TangramRelativeMappingService.establishOrUpdateMappingOptimized`, but not yet used in the main flow.

Gaps vs the doc and `next-steps`:
- **Pair scoring using target pair library**: Not implemented (current selection is oriented-then-closest; no rotation/translation-invariant pair scoring).
- **Adjacency-driven expansion**: Not implemented (engine validates all non-anchor pieces; no TargetAdjacencyGraph-driven order).
- **Activity-driven priority (recency/settle)**: Not implemented for pair selection.
- **Re-anchoring policy**: Not implemented beyond reselecting a pair when anchor missing.
- **Nudge escalation using attempts/group confidence**: Skeleton exists (`generateNudge`) but not integrated; attempts not tracked.
- **Orientation-only silhouette fill**: Commented out in `CVValidationBridge`.

### Recommended next steps to reach the full vision
1. **Precompute target relations once per puzzle**
   - Add `TargetPairLibrary` and `TargetAdjacencyGraph` (e.g., `Bemo/Features/Game/Games/Tangram/Models/`).
   - Build on puzzle load or first `process()` for a `puzzle.id`, and cache in `TangramValidationEngine`.
   - Contents:
     - Target pair entries: typeA/typeB, relative vector rAB in SK, feature angles, optional edge relation.
     - Adjacency graph: target-id nodes, edges with relation metadata.

2. **Observed pair scoring (replace current heuristic)**
   - In `TangramValidationEngine.process()`: build observed pairs rPQ for settled/oriented pieces; include recency bonus for the last moved piece(s) and dwell status (use `PieceObservation.velocity` or pass `focusPieceId` via options).
   - Score vs `TargetPairLibrary` with:
     - angleResidual, lengthResidual, per-piece orientation residuals, adjacency hint match, recency bonus.
   - Pick the top-scoring eligible pair.

3. **Map to a specific target pair (not first-of-type)**
   - Change `computePairDocMapping` to accept the chosen target pair ids (from step 2) and compute Θ/T against those two specific targets.
   - During anchor commit, validate the two pieces only against those two targets; on success, lock those target ids and mark consumed via `TangramRelativeMappingService.markTargetConsumed`.

4. **Activity-driven gating**
   - Extend `ValidationOptions` to include `focusPieceId` and a settle threshold, or infer settle via velocity + pose deltas.
   - Restrict candidate pairs to those involving recent/settled pieces per `next-steps`.

5. **Adjacency-driven group expansion**
   - After anchor commit, expand using `TargetAdjacencyGraph` neighbors of validated targets.
   - For each neighbor target, consider matching-type observed pieces (prefer last moved + settled), validate in mapped space, add to group on success.
   - Stop validating “all at once”; process 1–2 neighbors per run to keep UX focused.

6. **Re-anchoring policy**
   - If anchor not yet committed, or a new local cluster (≥3 oriented pieces) scores significantly better than current mapping, recompute mapping with that pair/cluster and switch anchors (with minimal visual notice).
   - When group has ≥3 validated pieces, prefer re-establishing mapping via `establishOrUpdateMappingOptimized` for robustness.

7. **Integrate optimizer/refinement**
   - Use `TangramRelativeMappingService.refineMapping` as more pairs are validated.
   - When group size ≥3, optionally upgrade to `establishOrUpdateMappingOptimized` to minimize global residuals.

8. **Nudge escalation and attempts**
   - Track `pieceAttempts` per piece in `process()` (increment when failing near a target with same-best match).
   - Use `generateNudge` to produce a single primary nudge (`ValidationResult.nudgeContent`) in addition to per-piece nudges; respect cooldowns.
   - Tie nudge reason to primary residual (flip > rotation > position) from `determineFailureReason`.

9. **Orientation-only silhouette fill**
   - Re-enable `orientedTargets` fill in `CVValidationBridge.applyValidationResults` with guards to avoid overriding validated targets.

10. **Logging throttle and clarity**
    - Add concise logs for pair scoring (top 3 with scores), anchor commit mode (strict/relaxed), adjacency expansions, and re-anchors.
    - Throttle repeats per piece/pair signature.

11. **Small correctness fixes**
    - Ensure pair commit locks piece→target ids used for mapping, instead of letting `validateMappedPiece` reassign to a different same-type target.
    - Clear/restore `validatedTargets` and group state on movement to keep state consistent.

Where to implement
- `TangramValidationEngine.process()`: steps 2–8, 10–11.
- `TangramValidationEngine.computePairDocMapping(...)`: step 3 (accept target pair ids).
- New `TargetRelationLibrary` (models/service) and caching in engine: step 1.
- `CVValidationBridge.applyValidationResults(...)`: step 9.

Acceptance criteria (per `next-steps.md`)
- Two-piece commit happens from the pair the student is actually aligning (recency + scoring), not hardcoded order.
- After anchor commit, neighbors are validated under the same mapping in adjacency order.
- Re-anchoring triggers when a better local cluster emerges.
- Nudges are specific, sparse, and tied to the actual blocking residual.

- Implemented coverage: anchor mapping, relative validation, orientation feedback, optimizer available but unused.
- Next work: precompute target relations, pair scoring with recency/settle, explicit target-pair mapping, adjacency expansion, re-anchoring, integrate optimizer + refined nudges, re-enable orientation fills, and improve logging.



----------

### TL;DR
- Don’t hardcode “large triangles first.” Select whatever the student is actually building by scoring observed pairs against target pairs using rotation/translation-invariant geometry.
- Compute a single rigid transform (Θ, T) from the best observed pair using the plan-doc method (relative-vector rotation + centroid translation), validate that pair together, commit as anchor, then expand the group to adjacent pieces.
- Use target “connectivity” (adjacency) to pick the next pieces to validate after the first two, but do not compare to absolute top-panel coordinates before mapping.

### Plan aligned with the doc and your constraints

1) Precompute target relations once on puzzle load
- TargetPairLibrary:
  - For every pair of target pieces (A, B), store:
    - Relative vector rAB (direction + length in SK space).
    - Types (typeA, typeB).
    - Optional edge relation (hypotenuse-to-hypotenuse, vertex adjacency, etc.) if the editor provides it.
- TargetAdjacencyGraph:
  - Nodes: target piece ids.
  - Edges: who touches whom (and how). This guides expansion after anchor.

2) Build observed relations at runtime
- ObservedPairSet (lightweight, per frame or on settle events):
  - For each observed pair (P, Q), compute rPQ (direction + length).
  - Track per-piece orientation readiness (feature-angle closeness) and settled status (dwell).
  - Keep a “recently moved” timestamp to prioritize student activity.

3) Select the pair to attempt (student-driven, not prescriptive)
- Candidate pair scoring (doc-aligned, rotation/translation invariant):
  - angleResidual = smallest angle diff between rPQ and rAB (consider symmetry for square; flip does not affect triangle symmetry).
  - lengthResidual = |‖rPQ‖ − ‖rAB‖| (scale is fixed; this should be small).
  - orientationResidual = per-piece feature-angle deltas vs. mapped target feature (pre-check).
  - adjacencyBonus: if editor knows edge relation and the observed pair’s edges suggest the same.
  - recencyBonus: favor pairs containing the last moved piece(s).
- Pick the top scoring pair that passes readiness thresholds:
  - Both pieces settled (or slowed) and orientation within tolerance.
  - Residuals below soft gates.
- This naturally picks whatever the student is currently aligning (e.g., square + small triangle) instead of forcing large triangles.

4) Compute mapping using the plan-doc method (for that pair)
- Θ: least-squares rotation from the two pairwise correspondences (relative vectors).
- T: centroid alignment T*(Θ) (doc’s formula).
- This guarantees the transform minimizes residuals for that pair, independent of global orientation.

5) Validate the chosen pair together under (Θ, T)
- For each piece: rotation (feature-angle with symmetry), position (centroid distance) or polygon-contact fallback, and flip parity (parallelogram).
- Commit anchor only if both pass.
- Initial commit gates: slightly relaxed position tolerance (doc spirit: enable anchor when the student is clearly “there”), then tighten for subsequent pieces.

6) Expand the validated group (respond to what they build next)
- From the TargetAdjacencyGraph, find neighbors of already validated targets that match types of observed, settled pieces.
- For each neighbor candidate:
  - Map observed pose via the committed (Θ, T), validate with strict tolerances.
  - On success, add to the group and mark the target consumed.
- Order of expansion:
  - Prioritize pieces the student is currently manipulating (last moved, settled).
  - Otherwise, breadth-first from the validated subgraph.

7) Re-anchoring (adapt to student relocation)
- If anchor isn’t committed yet, or a new local cluster (3+ pieces) scores significantly better than the current candidate, prefer the cluster pair (or best pair within the cluster) and recompute (Θ, T).
- If an anchor is committed but a different cluster grows and out-scores the current mapping by a wide margin and contains ≥3 validated-orientation pieces, promote it (with a quick visual notice).

8) Nudges (aligned with stage)
- Before anchor:
  - Relative nudges: “rotate piece Q to align to P along this direction,” “increase/decrease spacing.”
- After anchor:
  - Target-space nudges: rotate/flip/move toward the mapped target centroid and orientation.
- Always tie a nudge to the residual that’s actually blocking validation (rotation diff, position offset, flip).

9) Logging (high-signal only)
- Keep:
  - Pair selection: “[ANCHOR] Oriented pair selected: …”
  - Commit: “[ANCHOR] Committed … theta=…”
  - Residuals per piece (both on success and failure): “[VALIDATION-DETAIL] piece=… posDist=… rotDiff=…°”
- Drop:
  - ORIENT for unrelated pieces, repeated nudges, duplicate “Placed” lines, system noise.

10) Tolerances and gating
- Initial pair commit:
  - Orientation must be within tolerance; position tolerance slightly relaxed (doc spirit: enable anchor lock when geometry matches).
  - After commit: enforce stricter tolerances for new pieces added to the group.
- Difficulty scaling applies to both.

Why this fits the doc and your goals
- It’s invariant to global rotation/flip by working in relative space until a transform is established.
- It responds to what the student is building (recency + relative-fit scoring), not teacher-prescribed order.
- It starts with a small, self-consistent subset (pair) and grows the validated group using target connectivity.

If you want a minimal first milestone
- Implement pair scoring + doc mapping + pair commit with relaxed gate and residual logs.
- Then add adjacency-driven expansion for one next neighbor piece.
- After those feel solid, add re-anchoring, relative pre-anchor nudges, and the strict/relaxed tolerance ladder.

----

Ran tool

Ran tool
Ran tool
- Minimal milestone is in place conceptually: pair selection by observed activity and relative-fit; doc-based pair mapping (Θ from relative vectors, T from centroids); validate the pair together; commit anchor; residual logging.
- I did not hardcode “large triangles first.” The pair selector already considers oriented pairs first; you’ll next want to add the recency/settle priority so it picks whatever the student is actively aligning.

What will happen now (after these edits):
- When two pieces are oriented and reasonably spaced, the engine computes the pair mapping via centroid alignment and tests both together.
- If both pass strict validation, it commits; if not, it tries a relaxed gate (slightly looser tolerances) once to allow anchor formation when geometry is right but position is just off.
- On commit, it logs theta and whether strict vs relaxed gating was used.
- On failure, it logs per-piece residuals (posDist, rotDiff) so we know what blocked it.

Next iteration (once you confirm anchor commits from real play):
- Add activity-driven pair priority (last moved + settled) so selection responds to the student.
- Implement group expansion via target adjacency for the next piece(s) under the same (Θ, T).
- Throttle retries for failing pairs to reduce log noise.