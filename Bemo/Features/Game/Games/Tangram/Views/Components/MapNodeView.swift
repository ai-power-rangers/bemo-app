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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    // MARK: - Initialization
    
    init(puzzle: GamePuzzleData, nodeState: MapNodeState, onTap: @escaping () -> Void) {
        self.puzzle = puzzle
        self.nodeState = nodeState
        self.onTap = onTap
    }
    
    // MARK: - Node Styling
    
    private var borderColor: Color {
        switch nodeState {
        case .locked:
            return TangramTheme.UI.disabled
        case .current:
            return TangramTheme.UI.primaryButton
        case .completed:
            return TangramTheme.UI.success
        }
    }
    
    private var overlayIcon: String? {
        switch nodeState {
        case .locked:
            return "lock.fill"
        case .current:
            return nil  // No overlay for current - just the pulse animation
        case .completed:
            return "checkmark.circle.fill"
        }
    }
    
    private var overlayIconColor: Color {
        switch nodeState {
        case .locked:
            return TangramTheme.Text.tertiary.opacity(0.8)
        case .current, .completed:
            return .white
        }
    }
    
    private var shouldPulse: Bool {
        nodeState == .current
    }
    
    /// Dynamic thumbnail size based on device size class
    private var thumbnailSize: CGFloat {
        // Base size for compact screens (phones)
        let baseSize: CGFloat = 80
        
        // Triple size for regular screens (iPads and large iPhones in landscape)
        if horizontalSizeClass == .regular && verticalSizeClass == .regular {
            return baseSize * 3  // 240 for iPads
        } else if horizontalSizeClass == .regular || verticalSizeClass == .regular {
            return baseSize * 2  // 160 for larger phones in landscape
        } else {
            return baseSize      // 80 for compact phones
        }
    }
    
    /// Dynamic overlay icon size
    private var overlayIconSize: CGFloat {
        if horizontalSizeClass == .regular && verticalSizeClass == .regular {
            return 48  // Larger on iPad
        } else if horizontalSizeClass == .regular || verticalSizeClass == .regular {
            return 36  // Medium on larger phones
        } else {
            return 30  // Standard on phones
        }
    }
    
    /// Dynamic font sizes
    private var titleFont: Font {
        if horizontalSizeClass == .regular && verticalSizeClass == .regular {
            return .title3  // Larger on iPad
        } else if horizontalSizeClass == .regular || verticalSizeClass == .regular {
            return .headline  // Medium on larger phones
        } else {
            return .caption  // Standard on phones
        }
    }
    
    private var starSize: CGFloat {
        if horizontalSizeClass == .regular && verticalSizeClass == .regular {
            return 20  // Larger on iPad
        } else if horizontalSizeClass == .regular || verticalSizeClass == .regular {
            return 12  // Medium on larger phones
        } else {
            return 8   // Standard on phones
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: BemoTheme.Spacing.small) {
            
            // Main Node - Thumbnail with overlay
            ZStack {
                // Thumbnail background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .shadow(
                        color: borderColor.opacity(0.3),
                        radius: shouldPulse ? 8 : 4,
                        x: 0,
                        y: 2
                    )
                
                // Puzzle thumbnail
                PuzzleThumbnailService.shared.tangramThumbnailView(
                    for: puzzle,
                    colorful: nodeState != .locked  // Grayscale for locked puzzles
                )
                .frame(width: thumbnailSize - 8, height: thumbnailSize - 8)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .opacity(nodeState == .locked ? 0.6 : 1.0)
                
                // Border
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(borderColor, lineWidth: 3)
                    .frame(width: thumbnailSize, height: thumbnailSize)
                
                // Overlay icon (lock or checkmark)
                if let icon = overlayIcon {
                    ZStack {
                        // Background for better visibility
                        Circle()
                            .fill(nodeState == .completed ? borderColor : Color.black.opacity(0.6))
                            .frame(width: overlayIconSize, height: overlayIconSize)
                        
                        Image(systemName: icon)
                            .font(.system(size: overlayIconSize * 0.53, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // Pulse animation for current state
                if shouldPulse {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(borderColor.opacity(0.6), lineWidth: 2)
                        .frame(width: thumbnailSize + 20, height: thumbnailSize + 20)
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
                    .font(titleFont)
                    .fontWeight(.medium)
                    .foregroundColor(TangramTheme.Text.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                // Difficulty stars (smaller for map)
                HStack(spacing: 1) {
                    ForEach(1...puzzle.difficulty, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: starSize))
                            .foregroundColor(.orange)
                    }
                }
            }
            .frame(width: thumbnailSize + 20) // Ensure consistent width for alignment
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    init(isCompleted: Bool) {
        self.isCompleted = isCompleted
    }
    
    /// Dynamic line dimensions based on device size
    private var lineWidth: CGFloat {
        if horizontalSizeClass == .regular && verticalSizeClass == .regular {
            return 4  // Thicker on iPad
        } else if horizontalSizeClass == .regular || verticalSizeClass == .regular {
            return 3  // Medium on larger phones
        } else {
            return 2  // Standard on phones
        }
    }
    
    private var lineHeight: CGFloat {
        if horizontalSizeClass == .regular && verticalSizeClass == .regular {
            return 60  // Longer on iPad to match larger nodes
        } else if horizontalSizeClass == .regular || verticalSizeClass == .regular {
            return 40  // Medium on larger phones
        } else {
            return 30  // Standard on phones
        }
    }
    
    var body: some View {
        Rectangle()
            .fill(
                isCompleted 
                    ? TangramTheme.UI.success.opacity(0.6)
                    : TangramTheme.UI.separator
            )
            .frame(width: lineWidth, height: lineHeight)
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

