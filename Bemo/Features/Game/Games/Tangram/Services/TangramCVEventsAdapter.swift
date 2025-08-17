//
//  TangramCVEventsAdapter.swift
//  Bemo
//
//  Game-specific adapter that converts CVService detections into CVEventBus frames
//

// WHAT: Subscribes to CVService detection results and emits CVFrameEvent via CVEventBus.
// ARCHITECTURE: Game-scoped service (MVVM-S) – keeps CVService generic for reuse across games.
// USAGE: Start when Tangram game starts, stop when it ends.

import Foundation
import Combine
import CoreGraphics

final class TangramCVEventsAdapter {
    private let cvService: CVService
    private var cancellables = Set<AnyCancellable>()

    // Must match the viewSize used by CVService pipeline for consistent coordinates
    private let referenceViewSize = CGSize(width: 1080, height: 1920)

    // Identity tracking per classId
    private struct Track { var id: String; var last: CGPoint }
    private var tracksByClassId: [Int: [Track]] = [:]
    private var nextIndexByClassId: [Int: Int] = [:]
    struct AdapterConfig { var assignmentThresholdPx: CGFloat }
    private var config: AdapterConfig = {
        AdapterConfig(assignmentThresholdPx: CGFloat(TangramCVTuning.shared.assignmentThresholdPx))
    }()

    init(cvService: CVService) {
        self.cvService = cvService
    }

    func start() {
        // Bridge detection results → CVEventBus frames
        cvService.detectionResultsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                guard let self else { return }
                let frame = self.buildFrame(from: result)
                let stabilized = self.assignIdentity(in: frame)
                CVEventBus.shared.emitFrame(stabilized)
            }
            .store(in: &cancellables)
    }

    func stop() {
        cancellables.removeAll()
    }

    // MARK: - Mapping

    private func buildFrame(from result: CVService.CVDetectionResult) -> CVFrameEvent {
        // Prefer integrated Tangram result when available for correct orientation/vertices
        if let trAny: AnyObject = result.tangramResult, let frame = buildFrameFromTangramResult(trAny) {
            return frame
        }

        // Fallback to YOLO-only mapping
        struct Temp { let classId: Int; let rotation: Double; let translation: [Double]; let vertices: [[Double]] }
        var temps: [Temp] = []
        for det in result.detections {
            let classId = Int(det.classId)
            let centerX = (det.bbox.origin.x + det.bbox.width / 2) * referenceViewSize.width
            let centerY = (det.bbox.origin.y + det.bbox.height / 2) * referenceViewSize.height
            let x0 = det.bbox.origin.x * referenceViewSize.width
            let y0 = det.bbox.origin.y * referenceViewSize.height
            let x1 = (det.bbox.origin.x + det.bbox.width) * referenceViewSize.width
            let y1 = (det.bbox.origin.y + det.bbox.height) * referenceViewSize.height
            let vertices: [[Double]] = [[Double(x0), Double(y0)], [Double(x1), Double(y0)], [Double(x1), Double(y1)], [Double(x0), Double(y1)]]
            temps.append(Temp(classId: classId, rotation: 0, translation: [Double(centerX), Double(centerY)], vertices: vertices))
        }
        var objects: [CVPieceEvent] = []
        let grouped = Dictionary(grouping: temps, by: { $0.classId })
        for (classId, arr) in grouped {
            let sorted = arr.sorted { lhs, rhs in
                if lhs.translation[0] == rhs.translation[0] { return lhs.translation[1] < rhs.translation[1] }
                return lhs.translation[0] < rhs.translation[0]
            }
            for (idx, t) in sorted.enumerated() {
                let name = "\(cvName(for: classId))_\(idx)"
                let pose = CVPieceEvent.Pose(rotationDegrees: t.rotation, translation: t.translation)
                objects.append(CVPieceEvent(name: name, classId: classId, pose: pose, vertices: t.vertices))
            }
        }
        return CVFrameEvent(objects: objects)
    }

    // MARK: - KVC bridge for TPTangramResult → CVFrameEvent
    private func buildFrameFromTangramResult(_ tr: AnyObject) -> CVFrameEvent? {
        // TPTangramResult API: H_3x3 (homography), scale, poses (classId->TPPose {theta,tx,ty}), refinedPolygons (classId->flat array)
        guard let hom = tr.value(forKey: "H_3x3") as? [NSNumber], hom.count == 9 else { return nil }
        let scale: Double = (tr.value(forKey: "scale") as? NSNumber)?.doubleValue ?? 0
        let poses = tr.value(forKey: "poses") as? [NSNumber: AnyObject] ?? [:]
        let polys = tr.value(forKey: "refinedPolygons") as? [NSNumber: [NSNumber]] ?? [:]

        // Build temp entries per present classId
        struct Entry { let classId: Int; let rotationDeg: Double; let translation: [Double]; let vertices: [[Double]] }
        var entries: [Entry] = []
        let classIds = Set(poses.keys.map { $0.intValue } + polys.keys.map { $0.intValue })
        for cid in classIds {
            let classId = cid

            var rotationDeg = 0.0
            var translationNorm: [Double] = [0, 0]
            if let p = poses[NSNumber(value: classId)] {
                let theta = (p.value(forKey: "theta") as? NSNumber)?.doubleValue ?? 0
                let tx = (p.value(forKey: "tx") as? NSNumber)?.doubleValue ?? 0
                let ty = (p.value(forKey: "ty") as? NSNumber)?.doubleValue ?? 0
                rotationDeg = theta * 180.0 / .pi
                // Assume tx,ty may already be normalized; normalize if they look like pixels
                if abs(tx) > 1.5 || abs(ty) > 1.5 {
                    translationNorm = [tx / Double(referenceViewSize.width), ty / Double(referenceViewSize.height)]
                } else {
                    translationNorm = [tx, ty]
                }
            }

            // Prefer refined polygon centroid when available
            var centroidNorm: [Double]? = nil
            if let arr = polys[NSNumber(value: classId)], arr.count >= 2 {
                var sumX = 0.0, sumY = 0.0
                var count = 0
                var i = 0
                while i + 1 < arr.count {
                    sumX += arr[i].doubleValue
                    sumY += arr[i+1].doubleValue
                    count += 1
                    i += 2
                }
                if count > 0 {
                    centroidNorm = [sumX / Double(count), sumY / Double(count)]
                }
            }

            let finalTranslation = centroidNorm ?? translationNorm
            // Vertices stay normalized (0..1) so downstream can map consistently
            var vertices: [[Double]] = []
            if let arr = polys[NSNumber(value: classId)] {
                var tmp: [[Double]] = []
                var i = 0
                while i + 1 < arr.count {
                    let x = arr[i].doubleValue
                    let y = arr[i+1].doubleValue
                    tmp.append([x, y])
                    i += 2
                }
                vertices = tmp
            }

            entries.append(Entry(classId: classId, rotationDeg: rotationDeg, translation: finalTranslation, vertices: vertices))
        }

        // Group by class and index deterministically by X then Y
        var objects: [CVPieceEvent] = []
        let grouped = Dictionary(grouping: entries, by: { $0.classId })
        for (classId, arr) in grouped {
            let sorted = arr.sorted { lhs, rhs in
                if lhs.translation[0] == rhs.translation[0] { return lhs.translation[1] < rhs.translation[1] }
                return lhs.translation[0] < rhs.translation[0]
            }
            for (idx, e) in sorted.enumerated() {
                let name = "\(cvName(for: classId))_\(idx)"
                let pose = CVPieceEvent.Pose(rotationDegrees: e.rotationDeg, translation: e.translation)
                objects.append(CVPieceEvent(name: name, classId: classId, pose: pose, vertices: e.vertices))
            }
        }

        let H = [
            [hom[0].doubleValue, hom[1].doubleValue, hom[2].doubleValue],
            [hom[3].doubleValue, hom[4].doubleValue, hom[5].doubleValue],
            [hom[6].doubleValue, hom[7].doubleValue, hom[8].doubleValue]
        ]

        let frame = CVFrameEvent(homography: H, scale: scale, objects: objects)
        return frame
    }

    // MARK: - Identity Assignment (Nearest Neighbor per Class)
    private func assignIdentity(in frame: CVFrameEvent) -> CVFrameEvent {
        // Group by class_id
        var grouped: [Int: [Int]] = [:] // classId -> indices in frame.objects
        for (idx, obj) in frame.objects.enumerated() {
            grouped[obj.classId, default: []].append(idx)
        }

        var newObjects = frame.objects
        for (classId, indices) in grouped {
            // Build points for this class
            let points: [CGPoint] = indices.map { i in
                let tx = CGFloat(newObjects[i].pose.translation.first ?? 0)
                let ty = CGFloat(newObjects[i].pose.translation.dropFirst().first ?? 0)
                return CGPoint(x: tx, y: ty)
            }

            // Existing tracks
            var tracks = tracksByClassId[classId] ?? []
            var unmatchedDetIndices = Array(indices.indices)
            var unmatchedTrackIndices = Array(tracks.indices)

            // Greedy nearest-neighbor assignment
            while !unmatchedDetIndices.isEmpty && !unmatchedTrackIndices.isEmpty {
                var best: (detLocalIdx: Int, trackIdx: Int, dist: CGFloat)? = nil
                for (dIdxLocal, tIdx) in unmatchedDetIndices.flatMap({ d -> [(Int, Int)] in unmatchedTrackIndices.map { (d, $0) } }) {
                    let detPoint = points[dIdxLocal]
                    let trackPoint = tracks[tIdx].last
                    let dist = hypot(detPoint.x - trackPoint.x, detPoint.y - trackPoint.y)
                    if best == nil || dist < best!.dist { best = (dIdxLocal, tIdx, dist) }
                }
                if let b = best, b.dist <= config.assignmentThresholdPx {
                    // Assign
                    let idxInFrame = indices[b.detLocalIdx]
                    let baseName = cvName(for: classId)
                    let named = CVPieceEvent(
                        name: "cv_\(baseName)_\(tracks[b.trackIdx].id)",
                        classId: newObjects[idxInFrame].classId,
                        pose: newObjects[idxInFrame].pose,
                        vertices: newObjects[idxInFrame].vertices
                    )
                    newObjects[idxInFrame] = named
                    tracks[b.trackIdx].last = points[b.detLocalIdx]
                    // Remove from unmatched
                    unmatchedDetIndices.removeAll { $0 == b.detLocalIdx }
                    unmatchedTrackIndices.removeAll { $0 == b.trackIdx }
                } else {
                    break
                }
            }

            // Create new tracks for remaining detections
            var nextIdx = nextIndexByClassId[classId] ?? 1
            for dLocal in unmatchedDetIndices {
                let idxInFrame = indices[dLocal]
                let baseName = cvName(for: classId)
                let trackId = nextIdx
                nextIdx += 1
                let idStr = String(trackId)
                let named = CVPieceEvent(
                    name: "cv_\(baseName)_\(idStr)",
                    classId: newObjects[idxInFrame].classId,
                    pose: newObjects[idxInFrame].pose,
                    vertices: newObjects[idxInFrame].vertices
                )
                newObjects[idxInFrame] = named
                tracks.append(Track(id: idStr, last: points[dLocal]))
            }
            nextIndexByClassId[classId] = nextIdx
            tracksByClassId[classId] = tracks
        }

        return CVFrameEvent(objects: newObjects)
    }

    private func cvName(for classId: Int) -> String {
        switch classId {
        case 0: return "tangram_parallelogram"
        case 1: return "tangram_square"
        case 2: return "tangram_triangle_lrg"
        case 3: return "tangram_triangle_lrg2"
        case 4: return "tangram_triangle_med"
        case 5: return "tangram_triangle_sml"
        case 6: return "tangram_triangle_sml2"
        default: return "tangram_unknown"
        }
    }
}


