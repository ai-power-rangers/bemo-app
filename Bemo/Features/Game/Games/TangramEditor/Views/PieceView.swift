//
//  PieceView.swift
//  Bemo
//
//  View for displaying a tangram piece in the editor
//

import SwiftUI
import Foundation

struct PieceView: View {
    let piece: TangramPiece
    let isSelected: Bool
    let isGhost: Bool
    let showConnectionPoints: Bool
    let availableConnectionPoints: [TangramEditorViewModel.ConnectionPoint]
    let selectedConnectionPoints: [TangramEditorViewModel.ConnectionPoint]
    let manipulationMode: ManipulationMode?
    let manipulationConstraints: TangramEditorViewModel.ManipulationConstraints?
    let onRotation: ((Double) -> Void)?
    let onSlide: ((Double) -> Void)?
    let onManipulationEnd: (() -> Void)?
    
    @State private var currentRotation: Double = 0
    @State private var currentSlideDistance: Double = 0
    @State private var isManipulating: Bool = false
    
    var body: some View {
        ZStack {
            // Main piece shape
            PieceShape(type: piece.type)
                .fill(fillColor)
                .overlay(
                    PieceShape(type: piece.type)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
                .transformEffect(isGhost ? piece.transform : piece.transform)
                .onAppear {
                    // Debug logging for piece transforms
                    if !TangramCoordinateSystem.isValidTransform(piece.transform) {
                        print("DEBUG PieceView: WARNING - Piece \(piece.id) has invalid transform: \(piece.transform)")
                    }
                }
                .modifier(ManipulationGestureModifier(
                    manipulationMode: isSelected ? manipulationMode : nil,  // Only enable gestures when selected
                    currentRotation: $currentRotation,
                    currentSlideDistance: $currentSlideDistance,
                    isManipulating: $isManipulating,
                    onRotation: onRotation,
                    onSlide: onSlide,
                    onManipulationEnd: onManipulationEnd
                ))
            
            // Connection points overlay
            if showConnectionPoints && !availableConnectionPoints.isEmpty {
                ForEach(availableConnectionPoints, id: \.id) { point in
                    ConnectionPointView(
                        point: point,
                        isSelected: selectedConnectionPoints.contains { $0.id == point.id },
                        onTap: nil  // Tap handling done at parent level
                    )
                }
            }
            
            // Manipulation mode indicators - only show when selected
            if let mode = manipulationMode, !isGhost, isSelected {
                manipulationIndicatorOverlay(for: mode)
            }
            
            // Removed lock indicator overlay
        }
    }
    
    
    
    @ViewBuilder
    private func manipulationIndicatorOverlay(for mode: ManipulationMode) -> some View {
        switch mode {
        case .fixed:
            // No visual indicator for fixed pieces
            EmptyView()
            
        case .rotatable(let pivot, let snapAngles):
            // Rotation arc and snap indicators - only show when selected and manipulating
            ZStack {
                // Pivot point - always show when selected
                Circle()
                    .fill(Color.blue.opacity(0.8))
                    .frame(width: 12, height: 12)
                    .position(pivot)
                
                // Rotation arc with limits - only show during manipulation
                if isSelected && isManipulating {
                    if let limits = manipulationConstraints?.rotationLimits {
                        // Show constrained arc
                        Path { path in
                            path.addArc(
                                center: pivot,
                                radius: 50,
                                startAngle: Angle(degrees: limits.min),
                                endAngle: Angle(degrees: limits.max),
                                clockwise: false
                            )
                        }
                        .stroke(Color.blue.opacity(0.5), lineWidth: 3)
                        
                        // Limit indicators
                        Circle()
                            .fill(Color.red.opacity(0.6))
                            .frame(width: 8, height: 8)
                            .position(snapAnglePosition(angle: limits.min, pivot: pivot))
                        
                        Circle()
                            .fill(Color.red.opacity(0.6))
                            .frame(width: 8, height: 8)
                            .position(snapAnglePosition(angle: limits.max, pivot: pivot))
                    } else {
                        // Show full circle if no limits
                        Circle()
                            .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                            .frame(width: 100, height: 100)
                            .position(pivot)
                    }
                    
                    // Snap angle indicators (only show valid ones)
                    let validSnapAngles = manipulationConstraints?.rotationLimits != nil ?
                        snapAngles.filter { angle in
                            let limits = manipulationConstraints!.rotationLimits!
                            return angle >= limits.min && angle <= limits.max
                        } : snapAngles
                    
                    ForEach(validSnapAngles, id: \.self) { angle in
                        Circle()
                            .fill(isNearAngle(angle) ? Color.green : Color.gray.opacity(0.5))
                            .frame(width: 6, height: 6)
                            .position(snapAnglePosition(angle: angle, pivot: pivot))
                    }
                }
            }
            
        case .slidable(let edge, let baseRange, let snapPositions):
            // Slide track and snap points - only show when selected
            ZStack {
                let range = manipulationConstraints?.slideLimits ?? baseRange
                
                // Only show sliding indicators when selected
                if isSelected {
                    // Full theoretical track (semi-transparent)
                    Path { path in
                        path.move(to: edge.start)
                        path.addLine(to: edge.end)
                    }
                    .stroke(Color.orange.opacity(0.2), style: StrokeStyle(lineWidth: 3, dash: [5, 5]))
                    
                    // Valid slide range (solid)
                    if let limits = manipulationConstraints?.slideLimits {
                    Path { path in
                        let startPoint = CGPoint(
                            x: edge.start.x + edge.vector.dx * CGFloat(limits.lowerBound),
                            y: edge.start.y + edge.vector.dy * CGFloat(limits.lowerBound)
                        )
                        let endPoint = CGPoint(
                            x: edge.start.x + edge.vector.dx * CGFloat(limits.upperBound),
                            y: edge.start.y + edge.vector.dy * CGFloat(limits.upperBound)
                        )
                        path.move(to: startPoint)
                        path.addLine(to: endPoint)
                    }
                    .stroke(Color.orange.opacity(0.8), lineWidth: 4)
                    
                    // Range limit indicators
                    Circle()
                        .fill(Color.red.opacity(0.6))
                        .frame(width: 10, height: 10)
                        .position(CGPoint(
                            x: edge.start.x + edge.vector.dx * CGFloat(limits.lowerBound),
                            y: edge.start.y + edge.vector.dy * CGFloat(limits.lowerBound)
                        ))
                    
                    Circle()
                        .fill(Color.red.opacity(0.6))
                        .frame(width: 10, height: 10)
                        .position(CGPoint(
                            x: edge.start.x + edge.vector.dx * CGFloat(limits.upperBound),
                            y: edge.start.y + edge.vector.dy * CGFloat(limits.upperBound)
                        ))
                }
                
                    // Snap points within valid range
                    ForEach(snapPositions, id: \.self) { position in
                        let isWithinLimits = manipulationConstraints?.slideLimits != nil ?
                            range.contains(position) : true
                        
                        if isWithinLimits {
                            Circle()
                                .fill(isNearPosition(position, range: range) ? Color.green : Color.gray.opacity(0.5))
                                .frame(width: 10, height: 10)
                                .position(snapPointPosition(position: position, edge: edge, range: range))
                        }
                    }
                } // End of isSelected check
            }
            
        case .free:
            // Free movement indicator - no visual needed
            EmptyView()
        }
    }
    
    private func getPieceCenter() -> CGPoint {
        let vertices = TangramCoordinateSystem.getWorldVertices(for: piece)
        let sumX = vertices.reduce(0) { $0 + $1.x }
        let sumY = vertices.reduce(0) { $0 + $1.y }
        return CGPoint(x: sumX / CGFloat(vertices.count), y: sumY / CGFloat(vertices.count))
    }
    
    private func isNearAngle(_ targetAngle: Double) -> Bool {
        let angleDegrees = currentRotation * 180 / .pi
        return abs(angleDegrees - targetAngle) < 5
    }
    
    private func snapAnglePosition(angle: Double, pivot: CGPoint) -> CGPoint {
        let radius: CGFloat = 50
        let radians = angle * .pi / 180
        return CGPoint(
            x: pivot.x + Foundation.cos(radians) * radius,
            y: pivot.y + Foundation.sin(radians) * radius
        )
    }
    
    private func isNearPosition(_ position: Double, range: ClosedRange<Double>) -> Bool {
        let normalizedCurrent = currentSlideDistance / (range.upperBound - range.lowerBound)
        return abs(normalizedCurrent - position) < 0.1
    }
    
    private func snapPointPosition(position: Double, edge: ManipulationMode.Edge, range: ClosedRange<Double>) -> CGPoint {
        let distance = range.lowerBound + position * (range.upperBound - range.lowerBound)
        return CGPoint(
            x: edge.start.x + edge.vector.dx * CGFloat(distance),
            y: edge.start.y + edge.vector.dy * CGFloat(distance)
        )
    }
    
    private var fillColor: Color {
        if isGhost {
            return piece.type.color.opacity(0.3)
        } else {
            return piece.type.color.opacity(0.7)
        }
    }
    
    private var borderColor: Color {
        if isGhost {
            return Color.gray
        } else if isSelected {
            return Color.blue
        } else {
            return Color.black
        }
    }
    
    private var borderWidth: Double {
        if isSelected {
            return 3
        } else {
            return 1
        }
    }
}

struct PieceShape: Shape {
    let type: PieceType
    
    func path(in rect: CGRect) -> Path {
        // Use centralized coordinate system for consistent scaling
        let visualVertices = TangramCoordinateSystem.getVisualVertices(for: type)
        var path = Path()
        
        if let first = visualVertices.first {
            path.move(to: first)
            for vertex in visualVertices.dropFirst() {
                path.addLine(to: vertex)
            }
            path.closeSubpath()
        }
        
        return path
    }
}

struct ConnectionPointView: View {
    let point: TangramEditorViewModel.ConnectionPoint
    let isSelected: Bool
    let onTap: (() -> Void)?
    
    var body: some View {
        Group {
            switch point.type {
            case .vertex:
                Circle()
                    .fill(isSelected ? Color.green.opacity(0.8) : Color.blue.opacity(0.6))
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.green : Color.blue, lineWidth: 2)
                    )
                    .frame(width: 20, height: 20)
            case .edge:
                Rectangle()
                    .fill(isSelected ? Color.green.opacity(0.8) : Color.orange.opacity(0.6))
                    .overlay(
                        Rectangle()
                            .stroke(isSelected ? Color.green : Color.orange, lineWidth: 2)
                    )
                    .frame(width: 20, height: 20)
            }
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .position(point.position)
        .onTapGesture {
            onTap?()
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Gesture Modifier

struct ManipulationGestureModifier: ViewModifier {
    let manipulationMode: ManipulationMode?
    @Binding var currentRotation: Double
    @Binding var currentSlideDistance: Double
    @Binding var isManipulating: Bool
    let onRotation: ((Double) -> Void)?
    let onSlide: ((Double) -> Void)?
    let onManipulationEnd: (() -> Void)?
    
    func body(content: Content) -> some View {
        if let mode = manipulationMode {
            switch mode {
            case .rotatable(let pivot, _):
                content
                    .rotationEffect(Angle(radians: currentRotation))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // Calculate angle from pivot to current drag position
                                let dragLocation = value.location
                                let dx = dragLocation.x - pivot.x
                                let dy = dragLocation.y - pivot.y
                                let angle = atan2(dy, dx)
                                
                                // If this is the start of the drag, store the initial angle
                                if !isManipulating {
                                    isManipulating = true
                                    // Store the initial angle offset
                                    currentRotation = 0
                                }
                                
                                // Calculate rotation relative to start
                                let startLocation = value.startLocation
                                let startDx = startLocation.x - pivot.x
                                let startDy = startLocation.y - pivot.y
                                let startAngle = atan2(startDy, startDx)
                                let rotationDelta = angle - startAngle
                                
                                // CRITICAL: Snap to 45° increments for validation
                                // Convert to degrees for snapping
                                let deltaDegrees = rotationDelta * 180 / .pi
                                let validAngles: [Double] = [-180, -135, -90, -45, 0, 45, 90, 135, 180]
                                
                                // Find nearest valid angle
                                let snappedAngle = validAngles.min(by: { 
                                    abs($0 - deltaDegrees) < abs($1 - deltaDegrees) 
                                }) ?? 0
                                
                                // Convert back to radians
                                let snappedRadians = snappedAngle * .pi / 180
                                
                                currentRotation = snappedRadians
                                onRotation?(snappedRadians)  // Pass snapped value
                            }
                            .onEnded { _ in
                                isManipulating = false
                                onManipulationEnd?()
                                currentRotation = 0
                            }
                    )
                
            case .slidable(let edge, let range, _):
                content
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // Project drag onto edge vector
                                let dragVector = CGVector(dx: value.translation.width, dy: value.translation.height)
                                let dotProduct = dragVector.dx * edge.vector.dx + dragVector.dy * edge.vector.dy
                                
                                // CRITICAL: Snap to discrete positions (0%, 25%, 50%, 75%, 100%)
                                let rangeLength = range.upperBound - range.lowerBound
                                if rangeLength > 0 {
                                    // dotProduct is already the distance along the edge
                                    // Clamp it to the valid range first
                                    let clampedDistance = max(range.lowerBound, min(range.upperBound, dotProduct))
                                    let normalizedDistance = (clampedDistance - range.lowerBound) / rangeLength
                                    
                                    // Snap to nearest percentage
                                    let snapPercentages: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]
                                    let snappedPercentage = snapPercentages.min(by: {
                                        abs($0 - normalizedDistance) < abs($1 - normalizedDistance)
                                    }) ?? 0
                                    
                                    // Calculate actual distance at snap position
                                    let snappedDistance = range.lowerBound + (snappedPercentage * rangeLength)
                                    
                                    currentSlideDistance = snappedDistance
                                    isManipulating = true
                                    onSlide?(snappedDistance)  // Pass snapped value
                                } else {
                                    // No range, stay at start
                                    currentSlideDistance = 0
                                    isManipulating = true
                                    onSlide?(0)
                                }
                            }
                            .onEnded { _ in
                                isManipulating = false
                                onManipulationEnd?()
                                currentSlideDistance = 0
                            }
                    )
                
            case .fixed:
                content
                
            case .free:
                // Free movement - could add drag gesture here if needed
                content
            }
        } else {
            content
        }
    }
}