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
    let onRotation: ((Double) -> Void)?
    let onSlide: ((Double) -> Void)?
    let onManipulationEnd: (() -> Void)?
    let onLockToggle: (() -> Void)?
    
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
                    manipulationMode: manipulationMode,
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
            
            // Manipulation mode indicators
            if let mode = manipulationMode, !isGhost {
                manipulationIndicatorOverlay(for: mode)
            }
            
            // Lock indicator overlay (always visible when locked)
            if piece.isLocked && !isGhost {
                lockIndicatorOverlay()
            }
        }
    }
    
    @ViewBuilder
    private func lockIndicatorOverlay() -> some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: "lock.fill")
                    .foregroundColor(.white)
                    .font(.caption)
                    .padding(4)
                    .background(Circle().fill(Color.red.opacity(0.8)))
                    .onTapGesture {
                        onLockToggle?()
                    }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(piece.isLocked)
    }
    
    
    @ViewBuilder
    private func manipulationIndicatorOverlay(for mode: ManipulationMode) -> some View {
        switch mode {
        case .locked:
            // Lock icon at piece center
            Image(systemName: "lock.fill")
                .foregroundColor(.gray.opacity(0.6))
                .font(.title2)
                .position(getPieceCenter())
            
        case .rotatable(let pivot, let snapAngles):
            // Rotation arc and snap indicators
            ZStack {
                // Pivot point
                Circle()
                    .fill(Color.blue.opacity(0.8))
                    .frame(width: 12, height: 12)
                    .position(pivot)
                
                // Rotation arc
                if isManipulating {
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                        .frame(width: 100, height: 100)
                        .position(pivot)
                    
                    // Snap angle indicators
                    ForEach(snapAngles, id: \.self) { angle in
                        Circle()
                            .fill(isNearAngle(angle) ? Color.green : Color.gray.opacity(0.5))
                            .frame(width: 6, height: 6)
                            .position(snapAnglePosition(angle: angle, pivot: pivot))
                    }
                }
            }
            
        case .slidable(let edge, let range, let snapPositions):
            // Slide track and snap points
            ZStack {
                // Slide track
                Path { path in
                    path.move(to: edge.start)
                    path.addLine(to: edge.end)
                }
                .stroke(Color.orange.opacity(0.5), style: StrokeStyle(lineWidth: 3, dash: [5, 5]))
                
                // Snap points
                ForEach(snapPositions, id: \.self) { position in
                    Circle()
                        .fill(isNearPosition(position, range: range) ? Color.green : Color.gray.opacity(0.5))
                        .frame(width: 10, height: 10)
                        .position(snapPointPosition(position: position, edge: edge, range: range))
                }
            }
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
        } else if piece.isLocked {
            return piece.type.color.opacity(0.5)  // Dimmer when locked
        } else {
            return piece.type.color.opacity(0.7)
        }
    }
    
    private var borderColor: Color {
        if isGhost {
            return Color.gray
        } else if piece.isLocked {
            return Color.red.opacity(0.6)  // Red border when locked
        } else if isSelected {
            return Color.blue
        } else {
            return Color.black
        }
    }
    
    private var borderWidth: Double {
        if piece.isLocked {
            return 2
        } else if isSelected {
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
            case .rotatable:
                content
                    .rotationEffect(Angle(radians: currentRotation))
                    .gesture(
                        RotationGesture()
                            .onChanged { angle in
                                currentRotation = angle.radians
                                isManipulating = true
                                onRotation?(angle.radians)
                            }
                            .onEnded { _ in
                                isManipulating = false
                                onManipulationEnd?()
                                currentRotation = 0
                            }
                    )
                
            case .slidable(let edge, _, _):
                content
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // Project drag onto edge vector
                                let dragVector = CGVector(dx: value.translation.width, dy: value.translation.height)
                                let dotProduct = dragVector.dx * edge.vector.dx + dragVector.dy * edge.vector.dy
                                currentSlideDistance = dotProduct
                                isManipulating = true
                                onSlide?(dotProduct)
                            }
                            .onEnded { _ in
                                isManipulating = false
                                onManipulationEnd?()
                                currentSlideDistance = 0
                            }
                    )
                
            case .locked:
                content
            }
        } else {
            content
        }
    }
}