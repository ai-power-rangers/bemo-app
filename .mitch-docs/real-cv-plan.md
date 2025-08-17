# Tangram Real CV Integration Plan (Stability + Correct Sizes)

This document lays out a concrete, step‑by‑step plan from “unstable prototype” to a production‑ready Tangram CV integration. It prioritizes correct piece sizes, stable rendering when the physical pieces aren’t moving, and a clean, debt‑free code path that generalizes well.

---

## Current Symptoms and Likely Root Causes

1. Incorrect piece sizes
   - Ghosts are sized by a visual scale that doesn’t match the silhouettes’ display scale or the final puzzle geometry.
   - Container scaling (uniform scale on `topMirrorContent`) can double‑scale or mis‑scale geometry.

2. Jitter/instability when pieces are stationary
   - We’re applying raw per‑frame positions/rotations directly with no smoothing, dwell gating, or noise thresholds.
   - Identity switching between duplicate pieces (e.g., two small triangles) may cause sudden jumps.
   - Mapping from CV coordinates to SpriteKit coordinates relies on simple reference scaling instead of a robust mapping.

3. Lifecycle
   - Camera/CV used beyond the playing view; now partly gated but we will harden this.

---

## Guiding Principles

1. Canonical geometry and sizing: piece shape/size/color are determined by `TangramPieceType` (not CV vertices). CV only informs position and orientation.
2. Consistent coordinate spaces: do not rely on container scaling. Map CV coords → target container coords explicitly.
3. Stability first: rate‑limit, smooth, and dwell‑gate updates; maintain sticky identity per duplicate piece type.
4. Incremental delivery: get stable and correctly sized ghosts first, then add homography‑accurate mapping.

---

## Progress Update (current)

What’s implemented now:

1) Coordinate space normalization
   - Adapter emits positions in normalized model space (0..1) and prefers refined polygon centroids when available.
   - Scene maps normalized → SpriteKit target space explicitly with Y inversion, no container scaling.

2) Optional global 180° adjustment
   - Config flag `rotate180` rotates both position (around target center) and orientation by 180° to address consistent camera mounting/model orientation.

3) Optional mirror control
   - Config flag `mirrorX` for front‑camera parity when needed.

4) Identity stabilization
   - Per‑class nearest‑neighbor identity assignment to keep duplicate triangles stable across frames.

5) Stability gate + smoothing
   - Exponential smoothing + small movement/rotation thresholds + a brief multi‑frame gate to avoid flicker.

6) Noise reduction and lifecycle
   - Noisy per‑frame logs removed; camera/CV start/stop gated to the playing view.

Observed state:

- Piece ordering/placement: now consistent in the correct relative order/space.
- Rotations: still not reliably updating in the view; need a single, authoritative transform pipeline to compute orientation and apply canonical offsets consistently.

---

## Phase A — Stabilize MVP (Sizes Correct + Visual Stability)

Goal: Canonical‑sized, correctly colored ghosts that are stable when pieces are still.

1) Lock canonical sizes
   - Use `TangramGameGeometry.normalizedVertices(for:)` scaled by `TangramGameConstants.visualScale * targetDisplayScale` so ghost sizes match the silhouettes exactly.
   - Remove any container uniform scale that affects geometry. Positions transform should not scale geometry.

2) Explicit coordinate mapping (no container scale)
   - Stop scaling `topMirrorContent`.
   - Compute per‑point mapping from CV pixel space (reference `1080x1920`) to target section (SpriteKit) coordinates:
     - `x_sk = (x_cv / refW - 0.5) * targetWidth`
     - `y_sk = (y_cv / refH - 0.5) * targetHeight`
   - Apply mapping to translation only (not to path/shape). Keep ghosts as canonical size in SK units.

3) Stability: smoothing + dwell gating
   - Maintain per‑piece state `lastPose` and `smoothedPose`.
   - Exponential smoothing (translation and rotation): `pose = α*new + (1-α)*old` with α≈0.2–0.3.
   - Threshold gating: ignore updates if `Δpos < 2–3 px` and `Δrot < 2–3°`.
   - Dwell logic: mark piece as “settled” if no significant change for 300–500ms; when settled, do not redraw unless change exceeds threshold.

4) Sticky identity for duplicates
   - Maintain a per‑class track dictionary: for each new frame, associate current detections to prior tracks by nearest neighbor in (x,y,θ) with small spatial/rotational costs.
   - Preserve mapping across frames to avoid ID switches for the two large or small triangles.

5) Adapter correctness
   - Use `TPTangramResult.poses[classId]` for `theta, tx, ty` and `refinedPolygons[classId]` only as optional debug/QA.
   - Keep reference size constant; never use refined polygon size to scale ghosts.

6) Lifecycle hardening
   - Ensure CV starts on playing view `.onAppear` and stops on `.onDisappear` and game exit. Verify with logs.

Deliverable of Phase A: clean target silhouettes + stable, correctly sized ghosts positioned/rotated by CV, without jitter when still.

---

## Phase B — Accurate Mapping with Homography

Goal: Place ghosts with accurate perspective mapping that aligns the physical plane to the target panel consistently.

1) Use homography matrix H (3×3 `H_3x3`) and `scale`
   - For each CV point p = (x, y, 1), compute camera‑plane corrected point `p' = H⁻¹ * p` (or apply H depending on provided direction).
   - Normalize by `p'.z` and map into a normalized plane coordinate system.
   - Map normalized plane coordinates into target section coordinates via a single affine mapping (computed from puzzle bounds → target container bounds).
   - If a reliable plane→camera direction is provided, document which way the matrix is intended and verify with test points.

2) One‑time session calibration
   - On first frames, estimate consistent offset/scale aligning a known reference (e.g., puzzle center) from CV plane into target center.
   - Cache transform; update only if tracking quality drops or homography changes beyond tolerance.

3) Fallback
   - If homography not available or quality low, revert to linear reference mapping (Phase A) to maintain stability.

Deliverable of Phase B: accurate, repeatable alignment between physical plane and target panel, robust to camera perspective.

---

## Centralized CV Transform (Proposed Consolidation)

Problem: Transform logic is spread across adapter + scene; orientation/canonical offsets live in multiple places, causing drift and missed updates.

Solution: Create a single transformer used by all consumers (scene, validation, hints):

- File: `Bemo/Features/Game/Games/Tangram/Services/TangramCVTransform.swift`
- Input: `TPTangramResult` (poses, homography, scale) + tuning flags (`useHomography`, `mirrorX`, `rotate180`)
- Output per class instance:
  - normalizedPosition (0..1, 0..1)
  - targetPositionSK (centered SK coords after mapping and optional 180°)
  - rotationRadiansSK (theta adjusted for mirror and optional 180°)
  - classId, tracking id
  - quality metrics (from `trackingQuality`, timing)
- Responsibilities:
  1. Choose authoritative position source: refined polygon centroid if present, else pose (tx, ty).
  2. Normalize to model space; convert to pixel space only for homography path.
  3. Apply mapping (homography or linear 1080×1920 reference) into target SK space (centered, Y inverted).
  4. Apply global adjustments: mirrorX, rotate180.
  5. Apply canonical orientation offsets per piece type (triangles vs square vs parallelogram parity).
  6. Provide smoothed/thresholded poses (α, Δpos, Δrot, dwell) and identity assignment across frames.

Consumers:
 - Scene: renders canonical geometry at `targetPositionSK` with `rotationRadiansSK`.
 - Validation: uses the same adjusted pose so orientation correctness and hints match visuals.

Benefits:
 - One source of truth for mapping/orientation
 - Easier testing (golden frames / unit tests)
 - Fewer parameters bouncing among layers

---

## Phase C — Validation + Hints Integration

1) Orientation correctness indicator
   - Use existing validation engine to detect orientation‑only correct states; increase ghost fill slightly and show checkmark near the ghost.

2) Intelligent hints
   - Nudge only when piece is settled and fails by a meaningful margin; buffer flip vs rotation guidance to avoid flicker.

3) Duplicate target binding
   - Persist binding once a piece maps to a specific target instance; keep this assignment stable until the piece is moved.

Deliverable of Phase C: cohesive feedback loop (orientation, nudges, validation) without noise.

---

## Phase D — Cleanup and Technical Debt Removal

1) Remove legacy drag/rotation code paths from `TangramPuzzleScene` and related components.
2) Remove simulated CV event emission and unused mini‑CV controls.
3) Simplify `CVEventBus` to only what’s needed for frames and validation signals.
4) Consolidate geometry helpers; document coordinate systems (CV pixel, plane coords, SK target coords).

---

## Testing Strategy

1) Golden frame tests: feed recorded `TPTangramResult` snapshots; assert stable mapping to target coordinates and no size drift.
2) Noise tests: inject small random jitter; confirm dwell gating suppresses updates.
3) Duplicate identity tests: two similar pieces crossing paths; ensure consistent track binding.
4) Lifecycle tests: entering/exiting puzzles starts/stops CV; no camera use outside playing view.

---

## Instrumentation & Metrics

1) Log per‑piece jitter (px/s, °/s) and settle time; graph during playtest.
2) Record homography quality/lock state and fallback rates.
3) FPS and frame processing latency from `CVService`.

---

## Definition of Done

1) Ghost sizes and colors always match `TangramPieceType`.
2) Ghosts are stable (no visible jitter) when pieces are not moving.
3) Accurate placement via homography with smooth fallback.
4) Clean code path: no unused bottom‑panel or simulated CV code; minimal event bus surface.
5) CV runs only while playing a puzzle.

---

## Next Concrete Changes (Short List)

1) Centralize transform in `TangramCVTransform` (as above) and route both scene and validation through it.
2) Confirm rotation source = `poses[classId].theta` (radians), then:
   - Apply `mirrorX` (θ = −θ when mirrored)
   - Apply `rotate180` (θ += π)
   - Apply canonical per‑type offset for triangle feature alignment
   - Normalize to shortest‑arc range (−π..π)
3) Keep mapping normalized→SK centered with Y inversion. For homography path, convert normalized→pixels→H mapping→centered SK.
4) Verify with a test grid overlay + logs for (nx, ny, θ) to assert live transform is consistent.
5) Add golden frame tests with recorded `TPTangramResult` ensuring rotations update and relative stacking matches physical layout.


