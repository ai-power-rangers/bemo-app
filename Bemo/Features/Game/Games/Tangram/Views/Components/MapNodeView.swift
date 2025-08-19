//
//  MapNodeView.swift
//  Bemo
//
//  Individual puzzle node component for the tangram map view
//

// WHAT: Visual component representing a single puzzle in the difficulty progression map
// ARCHITECTURE: SwiftUI View component in MVVM-S pattern with observable state support
// USAGE: Used in TangramMapView to display puzzle nodes with different states and interactions

import SwiftUI

struct MapNodeView: View {
    
    // MARK: - Properties
    
    let puzzle: GamePuzzleData
    let nodeState: MapNodeState
    let onTap: () -> Void
    
    @State private var isPressed = false
    @State private var animationOffset: CGFloat = 0
    
    // MARK: - Initialization
    
    init(puzzle: GamePuzzleData, nodeState: MapNodeState, onTap: @escaping () -> Void) {
        self.puzzle = puzzle
        self.nodeState = nodeState
        self.onTap = onTap
    }
    
    // MARK: - Node Styling
    
    private var nodeColor: Color {
        switch nodeState {
        case .locked:
            return TangramTheme.UI.disabled
        case .current:
            return TangramTheme.UI.primaryButton
        case .completed:
            return TangramTheme.UI.success
        }
    }
    
    private var nodeIcon: String {
        switch nodeState {
        case .locked:
            return "lock.fill"
        case .current:
            return "target"
        case .completed:
            return "checkmark.circle.fill"
        }
    }
    
    private var nodeIconColor: Color {
        switch nodeState {
        case .locked:
            return TangramTheme.Text.tertiary
        case .current, .completed:
            return .white
        }
    }
    
    private var shouldPulse: Bool {
        nodeState == .current
    }
    
    private var nodeSize: CGFloat = 60
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: BemoTheme.Spacing.small) {
            
            // Main Node Circle
            ZStack {
                // Background circle
                Circle()
                    .fill(nodeColor)
                    .frame(width: nodeSize, height: nodeSize)
                    .shadow(
                        color: nodeColor.opacity(0.3),
                        radius: shouldPulse ? 8 : 4,
                        x: 0,
                        y: 2
                    )
                
                // Icon
                Image(systemName: nodeIcon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(nodeIconColor)
                
                // Pulse animation for current state
                if shouldPulse {
                    Circle()
                        .stroke(nodeColor.opacity(0.6), lineWidth: 2)
                        .frame(width: nodeSize + 20, height: nodeSize + 20)
                        .scaleEffect(1.0 + animationOffset * 0.3)
                        .opacity(1.0 - animationOffset)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: animationOffset
                        )
                }
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            
            // Puzzle Info
            VStack(spacing: 2) {
                Text(puzzle.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(TangramTheme.Text.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                // Difficulty stars (smaller for map)
                HStack(spacing: 1) {
                    ForEach(1...puzzle.difficulty, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                    }
                }
            }
            .frame(width: nodeSize + 20) // Ensure consistent width for alignment
        }
        .opacity(nodeState == .locked ? 0.6 : 1.0)
        .onTapGesture {
            guard nodeState.isInteractive else { return }
            onTap()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard nodeState.isInteractive else { return }
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    guard nodeState.isInteractive else { return }
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
        .onAppear {
            // Start pulse animation for current state
            if shouldPulse {
                withAnimation {
                    animationOffset = 1.0
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(nodeState.isInteractive ? [.isButton] : [])
    }
    
    // MARK: - Accessibility
    
    private var accessibilityLabel: String {
        switch nodeState {
        case .locked:
            return "Locked puzzle: \(puzzle.name), \(puzzle.difficulty) stars"
        case .current:
            return "Next puzzle: \(puzzle.name), \(puzzle.difficulty) stars"
        case .completed:
            return "Completed puzzle: \(puzzle.name), \(puzzle.difficulty) stars"
        }
    }
    
    private var accessibilityHint: String {
        switch nodeState {
        case .locked:
            return "Complete previous puzzles to unlock"
        case .current:
            return "Next puzzle in progression. Double tap to play"
        case .completed:
            return "Already completed. Double tap to replay"
        }
    }
}

// MARK: - Connection Line Component

struct MapConnectionLine: View {
    let isCompleted: Bool
    
    init(isCompleted: Bool) {
        self.isCompleted = isCompleted
    }
    
    var body: some View {
        Rectangle()
            .fill(
                isCompleted 
                    ? TangramTheme.UI.success.opacity(0.6)
                    : TangramTheme.UI.separator
            )
            .frame(width: 2, height: 30)
            .animation(.easeInOut(duration: 0.3), value: isCompleted)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Preview different states
        HStack(spacing: 30) {
            MapNodeView(
                puzzle: GamePuzzleData.mockPuzzle(id: "1", name: "Cat", difficulty: 2),
                nodeState: .locked,
                onTap: { print("Locked tapped") }
            )
            
            MapNodeView(
                puzzle: GamePuzzleData.mockPuzzle(id: "2", name: "House", difficulty: 3),
                nodeState: .current,
                onTap: { print("Current tapped") }
            )
            
            MapNodeView(
                puzzle: GamePuzzleData.mockPuzzle(id: "3", name: "Bird", difficulty: 4),
                nodeState: .completed,
                onTap: { print("Completed tapped") }
            )
        }
        
        // Show connection lines
        VStack(spacing: 0) {
            MapNodeView(
                puzzle: GamePuzzleData.mockPuzzle(id: "5", name: "Fish", difficulty: 3),
                nodeState: .completed,
                onTap: { print("Fish tapped") }
            )
            
            MapConnectionLine(isCompleted: true)
            
            MapNodeView(
                puzzle: GamePuzzleData.mockPuzzle(id: "6", name: "Tree", difficulty: 4),
                nodeState: .current,
                onTap: { print("Tree tapped") }
            )
            
            MapConnectionLine(isCompleted: false)
            
            MapNodeView(
                puzzle: GamePuzzleData.mockPuzzle(id: "7", name: "Flower", difficulty: 2),
                nodeState: .locked,
                onTap: { print("Flower tapped") }
            )
        }
    }
    .padding()
    .background(TangramTheme.Backgrounds.editor)
}

