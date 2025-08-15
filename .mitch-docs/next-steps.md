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