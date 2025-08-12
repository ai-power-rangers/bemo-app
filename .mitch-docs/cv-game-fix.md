Read file: /Users/mitchellwhite/Code/bemo-app/.mitch-docs/explainers/tangram-game-math-validation.md

- What’s wrong (based on your logs and the math doc)
  - Hints still rotated wrong
    - Targets are rendered with “baked vertices” (path has rotation; node zRotation=0). For a triangle ghost to visually overlap that path, you must rotate the ghost by desiredZ = targetFeatureAngle − pieceLocalFeatureAngle, not by the raw target zRotation alone.
    - From the doc: triangles have canonical 135° for piece, 45° for target. So desiredZ = expectedZRotationSK + 45° − 135° = expectedZRotationSK − 90°. Your current hint rotation uses expectedZRotationSK, making triangle hints off by 90°.
  - “Wrong triangle validated”
    - We removed strict instance binding and lean on dynamic “nearest target of same type.” With duplicate types (two large triangles), the system may consume the other triangle target, validating the wrong instance. The doc makes this a must: instance-based target tracking per piece to handle duplicates.
  - Zones still present
    - Your logs still show “[VALIDATION] ... zone: working/construction” – zone logic still influences gating; this conflicts with real CV behavior where kids can build anywhere and clustering/stability should define intent.
  - Hourglasses in bottom area
    - That’s the “validating” state indicator (⏳) from `PuzzlePieceNode.updateStateIndicator()`. Nudges and hints must live in the top panel only; bottom should not show transient teaching cues. The hourglass needs to be suppressed or limited to the top display only, and always auto-clear.

- How to fix precisely (no code now; exact edits called out)

1) Unify hint and validation rotation using feature angles
- File: `TangramPuzzleScene.swift`
  - In `showHint(for:)`:
    - Compute targetFeatureAngle = expectedZRotationSK + canonicalTarget (45° for triangles, 0° others).
    - Compute pieceLocalFeatureAngle = canonicalPiece (135° triangles; 0° square/parallelogram).
    - Set `hintPiece.zRotation = normalize(targetFeatureAngle − pieceLocalFeatureAngle)`.
    - Apply flip first for parallelogram using transform determinant; canonical feature changes sign when flipped.
  - In snap/rotate preview paths and snap rotation (where you compute targetRotation today), use the same desiredZ formula so the piece visually aligns with the baked silhouette path exactly the same way as hints and validation.

2) Restore instance-based target binding to handle duplicates
- File: `TangramPuzzleScene.swift`
  - On piece creation (you already set `piece.userData["assignedTargetId"] = target.id`), ensure validation:
    - Only consider that single assigned target for the piece, not “any target of same type.”
    - On first successful validation of that piece, mark the target consumed (as you do) and keep the binding.
  - If you want more flexibility (e.g., user swapped pieces mid-game), support “rebinding”:
    - Allow one rebind only when (a) current assigned target is not validated yet AND (b) the piece is closer to a different target by a margin AND (c) no group consumption conflict. After rebinding, lock it again.

3) Remove zone gating and replace with CV-like intent detection
- File: `TangramPuzzleScene+Zones.swift` and any prints in `TangramPuzzleScene.swift`
  - Remove validation dependence on zones. Delete logs and checks (`shouldValidateInZone` calls).
- Files: `ConstructionGroupManager.swift`, `TangramPuzzleScene.swift`
  - Cluster by proximity/time (you already form groups; keep that).
  - “Placed” = stationary for a stability window (use your placement delay or frame-based when you swap in CV).
  - Validation gating becomes:
    - First placed piece in a cluster: establish anchor mapping and validate that exact assigned target (immediate reward).
    - Second+ placed pieces: validate via mapping + assigned target lock.
  - Hysteresis:
    - Only drop validated state after M consecutive out-of-tolerance checks; avoid flicker.
  - Re-anchoring:
    - If the anchor is moved/removed out of tolerance, re-elect anchor (prefer validated > largest stable > most central), recompute mapping, re-check validations.

4) Make all nudges/hints top-only; remove bottom clutter
- File: `PuzzlePieceNode.updateStateIndicator()` and `TangramPuzzleScene.showSmartNudge(for:...)`
  - Suppress ⏳ hourglass and all nudge visuals on the bottom pieces. The bottom should only show physical piece visuals (shape + basic selection).
  - All hints/nudges must display in the top panel near the target silhouette (`showSmartNudgeInTarget` only).
  - Ensure nudges auto-clear on a timer (3–4s) and when the piece moves; never persist.

5) Fix target selection logic to avoid spontaneous “other triangle” validations
- Files: `TangramPuzzleScene.swift`
  - Use the assigned target id for a piece. Do not choose among duplicates at validate time.
  - Only if the assigned target is already consumed by another piece and the current piece is closer to its own unconsumed target beyond a threshold, allow a controlled rebind (optional).
  - Keep per-cluster consumption sets to avoid cross-cluster leaks.

6) Guarantee fully on-screen initial layout
- File: `TangramPuzzleScene.createPhysicalPieces(...)`
  - Instead of a rough radius, compute each piece’s actual display-space bounding box (scaled vertices around centroid) and clamp center so that box stays within `physicalWorldSection` bounds with padding.
  - Reduce initial random rotations; prefer 0°/small angles so visual cues (especially canonical feature) are easy for kids to “read.”

7) Confirm adherence to the math doc everywhere
- Apply the doc’s must-haves:
  - Use canonical split (target 45° vs piece 135°) only for feature-angle math, not for raw zRotation.
  - Always use `TangramPoseMapper` for conversions.
  - Keep a single feature-based validation path; don’t mix raw/baked vertex heuristics.
  - Maintain instance-based tracking for duplicates.

- Why this will fix your logs’ issues
  - Hints: moving to desiredZ (targetFeature − pieceLocalFeature) removes the 90° triangle offset and visual mismatch with baked silhouettes.
  - Wrong triangle validating: strict binding to the piece’s assigned target prevents consumption of the other identical triangle.
  - Zones/log spam: removing zones aligns with real CV; clusters and stability define intent anywhere on the table.
  - Hourglasses: removing bottom indicators avoids confusion; nudges belong top-only and must auto-clear.

- Final check-list for me to implement (in order)
  - Unify hint/snap rotation with desiredZ formula (triangles offset).
  - Enforce assigned target id in validation; remove “best-of duplicates.”
  - Remove all zone gating and residual zone logs.
  - Top-only hints/nudges; suppress bottom state icons.
  - Proper on-screen clamping of initial pieces (bounding box based).
  - Keep hysteresis and re-anchoring as described.

Confirm and I’ll apply these edits cleanly.