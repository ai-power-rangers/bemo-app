//
//  WorkspaceEngine.swift
//  Bemo
//
//  Manages tile workspace logic including snapping, grouping, and calculations
//

// WHAT: Engine handling all workspace logic - tile snapping, group management, calculations
// ARCHITECTURE: Service in MVVM-S pattern, pure business logic
// USAGE: Used by AquaMathGameViewModel to process tile interactions and calculate equations

import Foundation
import CoreGraphics

class WorkspaceEngine {
    
    // MARK: - Constants
    
    private let snapThreshold: CGFloat = 30.0
    private let tileSize: CGSize = CGSize(width: 60, height: 60)
    
    // MARK: - Snap Detection
    
    struct SnapInfo {
        let isSnapped: Bool
        let snapPosition: CGPoint?
        let targetGroup: TileGroup?
        let wasSnapped: Bool  // For haptic feedback
    }
    
    func checkSnapping(for position: CGPoint, against groups: [TileGroup]) -> SnapInfo {
        for group in groups {
            for tile in group.tiles {
                let distance = distanceBetween(position, tile.position)
                
                if distance < snapThreshold {
                    // Calculate snap position (align edges)
                    let snapX = tile.position.x + tileSize.width + 5  // Small gap
                    let snapY = tile.position.y
                    
                    return SnapInfo(
                        isSnapped: true,
                        snapPosition: CGPoint(x: snapX, y: snapY),
                        targetGroup: group,
                        wasSnapped: false  // Track previous state in VM
                    )
                }
            }
        }
        
        return SnapInfo(isSnapped: false, snapPosition: nil, targetGroup: nil, wasSnapped: false)
    }
    
    // MARK: - Tile Management
    
    func addTile(_ tile: Tile, to groups: [TileGroup], mode: GameMode) -> [TileGroup] {
        var updatedGroups = groups
        
        // Check if tile should join existing group
        let snapInfo = checkSnapping(for: tile.position, against: groups)
        
        if let targetGroup = snapInfo.targetGroup,
           let snapPosition = snapInfo.snapPosition {
            // Add to existing group
            if let index = updatedGroups.firstIndex(where: { $0.id == targetGroup.id }) {
                var updatedTile = tile
                updatedTile.position = snapPosition
                updatedGroups[index].tiles.append(updatedTile)
                updatedGroups[index].frame = calculateFrame(for: updatedGroups[index].tiles)
            }
        } else {
            // Create new group
            let newGroup = TileGroup(
                tiles: [tile],
                frame: CGRect(origin: tile.position, size: tileSize)
            )
            updatedGroups.append(newGroup)
        }
        
        // Merge groups if needed (for connect mode)
        if mode == .connect || mode == .multiply {
            updatedGroups = mergeAdjacentGroups(updatedGroups)
        }
        
        return updatedGroups
    }
    
    func removeTile(_ tileId: UUID, from groups: [TileGroup]) -> [TileGroup] {
        var updatedGroups = groups
        
        for (index, group) in updatedGroups.enumerated() {
            if let tileIndex = group.tiles.firstIndex(where: { $0.id == tileId }) {
                updatedGroups[index].tiles.remove(at: tileIndex)
                
                // Remove empty groups
                if updatedGroups[index].tiles.isEmpty {
                    updatedGroups.remove(at: index)
                } else {
                    // Update frame
                    updatedGroups[index].frame = calculateFrame(for: updatedGroups[index].tiles)
                }
                break
            }
        }
        
        return updatedGroups
    }
    
    // MARK: - Group Management
    
    private func mergeAdjacentGroups(_ groups: [TileGroup]) -> [TileGroup] {
        var mergedGroups = groups
        var didMerge = true
        
        while didMerge {
            didMerge = false
            
            for i in 0..<mergedGroups.count {
                for j in (i+1)..<mergedGroups.count {
                    if groupsAreAdjacent(mergedGroups[i], mergedGroups[j]) {
                        // Merge j into i
                        mergedGroups[i].tiles.append(contentsOf: mergedGroups[j].tiles)
                        mergedGroups[i].tiles.sort { $0.position.x < $1.position.x }  // Keep left-to-right order
                        mergedGroups[i].frame = calculateFrame(for: mergedGroups[i].tiles)
                        mergedGroups.remove(at: j)
                        didMerge = true
                        break
                    }
                }
                if didMerge { break }
            }
        }
        
        return mergedGroups
    }
    
    private func groupsAreAdjacent(_ group1: TileGroup, _ group2: TileGroup) -> Bool {
        for tile1 in group1.tiles {
            for tile2 in group2.tiles {
                let distance = distanceBetween(tile1.position, tile2.position)
                if distance < snapThreshold * 1.5 {  // Slightly larger threshold for groups
                    return true
                }
            }
        }
        return false
    }
    
    // MARK: - Calculations
    
    func calculateValue(for groups: [TileGroup], mode: GameMode) -> Int {
        switch mode {
        case .count, .add:
            // Sum all tiles
            return groups.reduce(0) { sum, group in
                sum + group.tiles.reduce(0) { $0 + $1.kind.numericValue }
            }
            
        case .connect:
            // Each group forms a multi-digit number, then sum them
            return groups.reduce(0) { sum, group in
                let digits = group.tiles
                    .sorted { $0.position.x < $1.position.x }
                    .map { $0.kind.numericValue }
                let number = digits.reduce(0) { $0 * 10 + $1 }
                return sum + number
            }
            
        case .multiply:
            // Multiply within groups, then add results
            return groups.reduce(0) { sum, group in
                let product = group.tiles.reduce(1) { $0 * $1.kind.numericValue }
                return sum + product
            }
        }
    }
    
    // MARK: - Helpers
    
    private func distanceBetween(_ point1: CGPoint, _ point2: CGPoint) -> CGFloat {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func calculateFrame(for tiles: [Tile]) -> CGRect {
        guard !tiles.isEmpty else { return .zero }
        
        let positions = tiles.map { $0.position }
        let minX = positions.map { $0.x }.min()!
        let maxX = positions.map { $0.x }.max()!
        let minY = positions.map { $0.y }.min()!
        let maxY = positions.map { $0.y }.max()!
        
        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + tileSize.width,
            height: maxY - minY + tileSize.height
        )
    }
}