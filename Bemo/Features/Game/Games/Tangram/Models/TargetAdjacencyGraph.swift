//
//  TargetAdjacencyGraph.swift
//  Bemo
//
//  Touch/adjacency relations between targets for expansion ordering
//

// WHAT: Builds an undirected graph of targets that are adjacent (edges near-contact) in SK space
// ARCHITECTURE: Model-only; computed once per puzzle, cached by the engine to guide expansion
// USAGE: Query neighbors of validated targets to pick next candidates

import Foundation
import CoreGraphics

struct TargetAdjacencyGraph {
    struct Edge: Hashable {
        let a: String
        let b: String
        let gap: CGFloat   // minimum polygon edge-to-edge gap in SK space
    }

    /// adjacency list: target id -> neighbors
    let neighbors: [String: Set<String>]
    /// detailed edges with gap metrics
    let edges: Set<Edge>

    func neighbors(of targetId: String) -> Set<String> {
        neighbors[targetId] ?? []
    }

    static func build(for puzzle: GamePuzzleData, gapTolerance: CGFloat = TangramGameConstants.Validation.tolerances(for: .normal).edgeContact) -> TargetAdjacencyGraph {
        let targets = puzzle.targetPieces
        var neighbors: [String: Set<String>] = [:]
        var edges: Set<Edge> = []

        guard targets.count >= 2 else {
            return TargetAdjacencyGraph(neighbors: [:], edges: [])
        }

        // Precompute SK polygons
        var polys: [String: [CGPoint]] = [:]
        for t in targets {
            polys[t.id] = TangramBounds.computeSKTransformedVertices(for: t)
        }

        for i in 0..<(targets.count - 1) {
            let a = targets[i]
            guard let pa = polys[a.id] else { continue }
            for j in (i + 1)..<targets.count {
                let b = targets[j]
                guard let pb = polys[b.id] else { continue }
                let gap = TangramGeometryUtilities.minimumDistanceBetweenPolygons(pa, pb)
                if gap <= gapTolerance {
                    neighbors[a.id, default: []].insert(b.id)
                    neighbors[b.id, default: []].insert(a.id)
                    edges.insert(Edge(a: min(a.id, b.id), b: max(a.id, b.id), gap: gap))
                }
            }
        }

        return TargetAdjacencyGraph(neighbors: neighbors, edges: edges)
    }
}


