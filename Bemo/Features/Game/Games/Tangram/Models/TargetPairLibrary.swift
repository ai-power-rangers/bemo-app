//
//  TargetPairLibrary.swift
//  Bemo
//
//  Precomputed target pair relations for fast, invariant scoring
//

// WHAT: Builds rotation/translation-invariant relations between all target pairs in SK space
// ARCHITECTURE: Model-only data structure; built once per puzzle and cached in the engine
// USAGE: Use to score observed piece pairs against target pair geometry (angle/length) quickly

import Foundation
import CoreGraphics

struct TargetPairLibrary {
    struct Entry {
        let idA: String
        let idB: String
        let typeA: TangramPieceType
        let typeB: TangramPieceType
        let vectorSK: CGVector   // from A centroid to B centroid in SK space
        let angleRad: CGFloat    // atan2 of vectorSK
        let length: CGFloat      // |vectorSK|
    }

    /// All unordered pair entries keyed by normalized pair key (idA < idB)
    let entriesByKey: [String: Entry]

    /// Quick index by type pair for faster candidate filtering
    /// Key is "typeA|typeB" with type names sorted (to be order-invariant)
    let entriesByTypePair: [String: [Entry]]

    /// Convenience access to all entries
    var allEntries: [Entry] { Array(entriesByKey.values) }

    static func build(for puzzle: GamePuzzleData) -> TargetPairLibrary {
        // Precompute SK-space centroids for each target id
        var centroids: [String: CGPoint] = [:]
        for t in puzzle.targetPieces {
            let verts = TangramBounds.computeSKTransformedVertices(for: t)
            guard !verts.isEmpty else { continue }
            let cx = verts.map { $0.x }.reduce(0, +) / CGFloat(verts.count)
            let cy = verts.map { $0.y }.reduce(0, +) / CGFloat(verts.count)
            centroids[t.id] = CGPoint(x: cx, y: cy)
        }

        var entriesByKey: [String: Entry] = [:]
        var entriesByTypePair: [String: [Entry]] = [:]

        let targets = puzzle.targetPieces
        guard targets.count >= 2 else {
            return TargetPairLibrary(entriesByKey: [:], entriesByTypePair: [:])
        }

        for i in 0..<(targets.count - 1) {
            let a = targets[i]
            guard let ca = centroids[a.id] else { continue }
            for j in (i + 1)..<targets.count {
                let b = targets[j]
                guard let cb = centroids[b.id] else { continue }
                let v = CGVector(dx: cb.x - ca.x, dy: cb.y - ca.y)
                let len = hypot(v.dx, v.dy)
                if len < 1e-6 { continue }
                let angle = atan2(v.dy, v.dx)

                // Normalize order by id string for a stable key
                let (idA, idB, typeA, typeB, vector) : (String, String, TangramPieceType, TangramPieceType, CGVector)
                if a.id < b.id {
                    (idA, idB, typeA, typeB, vector) = (a.id, b.id, a.pieceType, b.pieceType, v)
                } else {
                    // If swapping, invert the vector
                    (idA, idB, typeA, typeB, vector) = (b.id, a.id, b.pieceType, a.pieceType, CGVector(dx: -v.dx, dy: -v.dy))
                }

                let entry = Entry(
                    idA: idA,
                    idB: idB,
                    typeA: typeA,
                    typeB: typeB,
                    vectorSK: vector,
                    angleRad: angle,
                    length: len
                )
                let key = "\(idA)|\(idB)"
                entriesByKey[key] = entry

                let typeKey: String = {
                    let names = [typeA.rawValue, typeB.rawValue].sorted()
                    return names.joined(separator: "|")
                }()
                entriesByTypePair[typeKey, default: []].append(entry)
            }
        }

        return TargetPairLibrary(entriesByKey: entriesByKey, entriesByTypePair: entriesByTypePair)
    }
}


