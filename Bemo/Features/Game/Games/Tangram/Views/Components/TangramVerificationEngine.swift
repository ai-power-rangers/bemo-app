//
//  TangramVerificationEngine.swift
//  Bemo
//
//  WHAT: Verifies detected CV polygons against target puzzle outlines in unified panel space.
//  ARCHITECTURE: Scene-level utility. Consumes panel-space polygons provided by the scene.
//  USAGE: Call verifyMatches(...) each frame with panel-space data; then computeGlobalSnap(...) to get
//  a small translation+rotation that snaps the outline toward the detected arrangement.
//

import Foundation
import CoreGraphics

struct TangramVerificationConfig {
    let maxRotationDegrees: CGFloat
    let iouThreshold: CGFloat
    let centroidErrorMaxPoints: CGFloat  // fixed distance in panel points for centroid alignment
    let rotationStepDegrees: CGFloat
    let useGreedyAssignment: Bool
    
    static let `default` = TangramVerificationConfig(
        maxRotationDegrees: 15,
        iouThreshold: 0.60,
        centroidErrorMaxPoints: 30,
        rotationStepDegrees: 2,
        useGreedyAssignment: true
    )
}

struct TangramPieceMatchMetrics {
    let iou: CGFloat
    let centroidError: CGFloat
    let rotationDeltaDegrees: CGFloat // signed; positive is CCW rotation of target to align with candidate
}

struct TangramPieceMatchResult {
    let targetId: String
    let pieceType: TangramPieceType
    let matchedCVIndex: Int?  // index within cvPolygonsByType[pieceType]
    let metrics: TangramPieceMatchMetrics?
}

struct TangramVerificationResult {
    let perTarget: [String: TangramPieceMatchResult]
    var matchedTargets: [String] {
        perTarget.values.filter { $0.matchedCVIndex != nil }.map { $0.targetId }
    }
}

struct TangramGlobalSnapTransform {
    let translation: CGVector
    let rotationRadians: CGFloat
}

enum TangramVerificationEngine {
    // MARK: - Public API
    
    static func verifyMatches(
        targetPolygonsById: [String: [CGPoint]],
        targetTypesById: [String: TangramPieceType],
        cvPolygonsByType: [TangramPieceType: [[CGPoint]]],
        panelMinDimension: CGFloat,
        config: TangramVerificationConfig = .default
    ) -> TangramVerificationResult {
        var results: [String: TangramPieceMatchResult] = [:]
        
        // Prebuild candidate metrics by targetId → candidates with best alignment
        var perTypeAssigned: [TangramPieceType: Set<Int>] = [:]
        
        let rotationSweep = buildRotationSweep(maxDeg: config.maxRotationDegrees, stepDeg: config.rotationStepDegrees)
        
        // For duplicates, we optionally do greedy assignment by best IoU
        // Collect candidates for each target
        struct CandidateScore { let cvIndex: Int; let metrics: TangramPieceMatchMetrics }
        var candidateScoresByTarget: [String: [CandidateScore]] = [:]
        
        for (targetId, targetPoly) in targetPolygonsById {
            guard let pieceType = targetTypesById[targetId] else { continue }
            guard let candidates = cvPolygonsByType[pieceType], !candidates.isEmpty else {
                results[targetId] = TangramPieceMatchResult(targetId: targetId, pieceType: pieceType, matchedCVIndex: nil, metrics: nil)
                continue
            }
            var scores: [CandidateScore] = []
            for (idx, cvPoly) in candidates.enumerated() {
                if let metrics = bestAlignmentMetrics(target: targetPoly, candidate: cvPoly, panelMinDim: panelMinDimension, rotationSweep: rotationSweep) {
                    scores.append(CandidateScore(cvIndex: idx, metrics: metrics))
                }
            }
            // Sort best-first by IoU (desc), then small |rotation delta|, then small centroid error
            scores.sort { lhs, rhs in
                if lhs.metrics.iou != rhs.metrics.iou { return lhs.metrics.iou > rhs.metrics.iou }
                let la = abs(lhs.metrics.rotationDeltaDegrees)
                let ra = abs(rhs.metrics.rotationDeltaDegrees)
                if la != ra { return la < ra }
                return lhs.metrics.centroidError < rhs.metrics.centroidError
            }
            candidateScoresByTarget[targetId] = scores
        }
        
        // Greedy assignment across targets of same type to avoid using the same CV poly twice
        // Note: replace with Hungarian if needed later
        let targetsInPriority = candidateScoresByTarget.keys.sorted { (a, b) in
            let ia = candidateScoresByTarget[a]?.first?.metrics.iou ?? 0
            let ib = candidateScoresByTarget[b]?.first?.metrics.iou ?? 0
            return ia > ib
        }
        
        for targetId in targetsInPriority {
            guard let pieceType = targetTypesById[targetId] else { continue }
            var used = perTypeAssigned[pieceType] ?? []
            var chosen: CandidateScore? = nil
            if let scores = candidateScoresByTarget[targetId] {
                for s in scores {
                    if !used.contains(s.cvIndex) {
                        chosen = s
                        break
                    }
                }
            }
            if let s = chosen, passesThresholds(s.metrics, panelMinDim: panelMinDimension, config: config) {
                used.insert(s.cvIndex)
                perTypeAssigned[pieceType] = used
                results[targetId] = TangramPieceMatchResult(targetId: targetId, pieceType: pieceType, matchedCVIndex: s.cvIndex, metrics: s.metrics)
            } else {
                results[targetId] = TangramPieceMatchResult(targetId: targetId, pieceType: pieceType, matchedCVIndex: nil, metrics: nil)
            }
        }
        
        return TangramVerificationResult(perTarget: results)
    }
    
    static func computeGlobalSnap(
        result: TangramVerificationResult,
        targetCentroidsById: [String: CGPoint],
        cvCentroidsById: [String: CGPoint],
        maxRotationDegrees: CGFloat = 15
    ) -> TangramGlobalSnapTransform? {
        // Use only matched targets
        let matched = result.perTarget.values.compactMap { r -> (CGPoint, CGPoint, TangramPieceMatchMetrics)? in
            guard let idx = r.matchedCVIndex, let metrics = r.metrics else { return nil }
            guard let tC = targetCentroidsById[r.targetId], let cC = cvCentroidsById[r.targetId] else { return nil }
            return (tC, cC, metrics)
        }
        guard !matched.isEmpty else { return nil }
        
        // Estimate rotation as the average signed angle using vector averaging (robust to wrap-around)
        var sumSin: CGFloat = 0
        var sumCos: CGFloat = 0
        for (_, _, m) in matched {
            let rad = m.rotationDeltaDegrees * .pi / 180
            sumSin += sin(rad)
            sumCos += cos(rad)
        }
        let avgRad = atan2(sumSin, sumCos)
        let clampedRad = max(-maxRotationDegrees * .pi / 180, min(maxRotationDegrees * .pi / 180, avgRad))
        let theta = clampedRad
        
        // Estimate translation as average of (cvCentroid - rotated targetCentroid)
        let rot = CGAffineTransform(rotationAngle: theta)
        var sumTx: CGFloat = 0
        var sumTy: CGFloat = 0
        for (tC, cC, _) in matched {
            let tRot = tC.applying(rot)
            sumTx += (cC.x - tRot.x)
            sumTy += (cC.y - tRot.y)
        }
        let tx = sumTx / CGFloat(matched.count)
        let ty = sumTy / CGFloat(matched.count)
        
        return TangramGlobalSnapTransform(translation: CGVector(dx: tx, dy: ty), rotationRadians: theta)
    }
    
    // MARK: - Thresholds
    
    private static func passesThresholds(_ m: TangramPieceMatchMetrics, panelMinDim: CGFloat, config: TangramVerificationConfig) -> Bool {
        return m.iou >= config.iouThreshold &&
               abs(m.rotationDeltaDegrees) <= config.maxRotationDegrees &&
               m.centroidError <= config.centroidErrorMaxPoints
    }
    
    // MARK: - Alignment search (small rotation + translation)
    
    private static func bestAlignmentMetrics(
        target: [CGPoint],
        candidate: [CGPoint],
        panelMinDim: CGFloat,
        rotationSweep: [CGFloat]
    ) -> TangramPieceMatchMetrics? {
        guard target.count >= 3, candidate.count >= 3 else { return nil }
        let tCent = centroid(of: target)
        let cCent = centroid(of: candidate)
        var best: TangramPieceMatchMetrics? = nil
        
        for deg in rotationSweep {
            let rad = deg * .pi / 180
            let rot = CGAffineTransform(translationX: -tCent.x, y: -tCent.y)
                .rotated(by: rad)
                .translatedBy(x: tCent.x, y: tCent.y)
            // Rotate target, then translate to match centroids
            let tRot = target.map { $0.applying(rot) }
            let tRotCent = centroid(of: tRot)
            let dx = cCent.x - tRotCent.x
            let dy = cCent.y - tRotCent.y
            let tAligned = tRot.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
            
            let i = iou(tAligned, candidate)
            let cErr = hypot(cCent.x - tRotCent.x, cCent.y - tRotCent.y)
            let metrics = TangramPieceMatchMetrics(iou: i, centroidError: cErr, rotationDeltaDegrees: deg)
            if let b = best {
                if metrics.iou > b.iou || (metrics.iou == b.iou && metrics.centroidError < b.centroidError) {
                    best = metrics
                }
            } else {
                best = metrics
            }
        }
        return best
    }
    
    private static func buildRotationSweep(maxDeg: CGFloat, stepDeg: CGFloat) -> [CGFloat] {
        let step = max(0.5, stepDeg)
        var values: [CGFloat] = []
        var d: CGFloat = -maxDeg
        while d <= maxDeg + 0.001 { values.append(d); d += step }
        return values
    }
    
    // MARK: - Geometry utilities
    
    private static func centroid(of poly: [CGPoint]) -> CGPoint {
        // Polygon centroid (non-self-intersecting). If degenerate, fallback to average of points
        let areaVal = signedArea(poly)
        if abs(areaVal) < 1e-6 {
            var sx: CGFloat = 0, sy: CGFloat = 0
            for p in poly { sx += p.x; sy += p.y }
            let n = max(1, poly.count)
            return CGPoint(x: sx / CGFloat(n), y: sy / CGFloat(n))
        }
        var cx: CGFloat = 0
        var cy: CGFloat = 0
        for i in 0..<poly.count {
            let p0 = poly[i]
            let p1 = poly[(i + 1) % poly.count]
            let cross = p0.x * p1.y - p1.x * p0.y
            cx += (p0.x + p1.x) * cross
            cy += (p0.y + p1.y) * cross
        }
        let factor = 1.0 / (6.0 * areaVal)
        return CGPoint(x: cx * factor, y: cy * factor)
    }
    
    private static func signedArea(_ poly: [CGPoint]) -> CGFloat {
        var a: CGFloat = 0
        for i in 0..<poly.count {
            let p0 = poly[i]
            let p1 = poly[(i + 1) % poly.count]
            a += (p0.x * p1.y - p1.x * p0.y)
        }
        return a / 2.0
    }
    
    private static func area(_ poly: [CGPoint]) -> CGFloat { abs(signedArea(poly)) }
    
    private static func iou(_ a: [CGPoint], _ b: [CGPoint]) -> CGFloat {
        let inter = polygonIntersection(a, b)
        guard !inter.isEmpty else { return 0 }
        let areaInter = area(inter)
        let ua = area(a)
        let ub = area(b)
        let union = ua + ub - areaInter
        if union <= 1e-8 { return 0 }
        return areaInter / union
    }
    
    // Sutherland–Hodgman polygon clipping for convex clip polygon; works reasonably for our shapes
    private static func polygonIntersection(_ subject: [CGPoint], _ clip: [CGPoint]) -> [CGPoint] {
        if subject.count < 3 || clip.count < 3 { return [] }
        // Determine clip orientation. S-H expects consistent inside test relative to edge direction.
        let clipArea = signedArea(clip)
        if abs(clipArea) < 1e-9 { return [] }
        let insideSign: CGFloat = clipArea > 0 ? 1.0 : -1.0 // CCW => left is inside; CW => right is inside
        
        var output = subject
        for i in 0..<clip.count {
            let a = clip[i]
            let b = clip[(i + 1) % clip.count]
            var input = output
            output.removeAll(keepingCapacity: true)
            if input.isEmpty { break }
            var s = input.last!
            for e in input {
                if isInside(p: e, a: a, b: b, insideSign: insideSign) {
                    if !isInside(p: s, a: a, b: b, insideSign: insideSign) {
                        if let inter = intersection(s, e, a, b) { output.append(inter) }
                    }
                    output.append(e)
                } else if isInside(p: s, a: a, b: b, insideSign: insideSign) {
                    if let inter = intersection(s, e, a, b) { output.append(inter) }
                }
                s = e
            }
        }
        return output
    }

    private static func isInside(p: CGPoint, a: CGPoint, b: CGPoint, insideSign: CGFloat) -> Bool {
        // Generalized inside test: positive when p is to the left of ab for CCW clip (insideSign=+1),
        // and to the right for CW clip (insideSign=-1). Points on the edge are considered inside.
        let cross = (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)
        return (insideSign * cross) >= 0
    }
    
    private static func intersection(_ s: CGPoint, _ e: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGPoint? {
        let A1 = e.y - s.y
        let B1 = s.x - e.x
        let C1 = A1 * s.x + B1 * s.y
        let A2 = b.y - a.y
        let B2 = a.x - b.x
        let C2 = A2 * a.x + B2 * a.y
        let det = A1 * B2 - A2 * B1
        if abs(det) < 1e-8 { return nil }
        let x = (B2 * C1 - B1 * C2) / det
        let y = (A1 * C2 - A2 * C1) / det
        return CGPoint(x: x, y: y)
    }
}


