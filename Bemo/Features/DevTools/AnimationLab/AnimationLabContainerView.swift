//
//  AnimationLabContainerView.swift
//  Bemo
//
//  Container view for Animation Lab with native navigation matching Tangram Editor
//

import SwiftUI
import SpriteKit

struct AnimationLabContainerView: View {
    @Bindable var viewModel: AnimationLabViewModel
    @State private var scene: AnimationLabScene
    @State private var selectedSection: AnimationSection = .generic
    @State private var selectedExitDirection: AnimationLabScene.ExitDirection = .up
    @State private var selectedEntranceDirection: AnimationLabScene.EntranceDirection = .random
    @State private var showFullscreenAnimation = false
    @State private var fullscreenScene: AnimationLabScene? = nil
    
    enum AnimationSection: String, CaseIterable {
        case generic = "Generic"
        case celebration = "Celebrations"
        case entrance = "Entrances"
        case exit = "Exits"
        
        var icon: String {
            switch self {
            case .generic: return "sparkles"
            case .celebration: return "party.popper"
            case .entrance: return "arrow.right.to.line"
            case .exit: return "arrow.left.to.line"
            }
        }
    }
    
    init(viewModel: AnimationLabViewModel) {
        self._viewModel = Bindable(viewModel)
        let screenSize = UIScreen.main.bounds.size
        self._scene = State(initialValue: AnimationLabScene(size: screenSize))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Section selector
                sectionSelector
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                
                Divider()
                
                // Main content area
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // SpriteKit preview area (60% of height)
                        ZStack {
                            SpriteView(scene: scene, options: [.allowsTransparency])
                                .frame(height: geometry.size.height * 0.6)
                                .background(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.separator), lineWidth: 1)
                                )
                                .padding()
                                .onAppear {
                                    scene.scaleMode = .resizeFill
                                }
                        }
                        
                        Divider()
                        
                        // Animation list (40% of height)
                        VStack(spacing: 0) {
                            // Puzzle selector for non-generic sections
                            if selectedSection != .generic {
                                VStack(spacing: 12) {
                                    puzzleSelector
                                    
                                    // Direction selectors for entrance/exit animations
                                    if selectedSection == .exit {
                                        exitDirectionSelector
                                    } else if selectedSection == .entrance {
                                        entranceDirectionSelector
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .background(Color(.tertiarySystemBackground))
                                
                                Divider()
                            }
                            
                            animationList
                        }
                        .frame(maxHeight: geometry.size.height * 0.4)
                    }
                }
            }
            .overlay(
                // Fullscreen animation overlay
                Group {
                    if showFullscreenAnimation, let fullscreenScene = fullscreenScene {
                        ZStack {
                            Color.black.opacity(0.01) // Invisible but interactive background
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        showFullscreenAnimation = false
                                    }
                                    // Clean up after a delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        self.fullscreenScene = nil
                                    }
                                }
                            
                            SpriteView(scene: fullscreenScene, options: [.allowsTransparency])
                                .ignoresSafeArea()
                                .transition(.opacity)
                        }
                        .zIndex(1000)
                    }
                }
            )
            .navigationTitle("Animation Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        viewModel.requestQuit()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16))
                            Text("Back")
                                .font(.system(size: 16))
                        }
                    }
}
            }
        }
    }
    
    private var sectionSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AnimationSection.allCases, id: \.self) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSection = section
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: section.icon)
                                .font(.system(size: 14))
                            Text(section.rawValue)
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(selectedSection == section ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedSection == section ? Color.blue : Color(.tertiarySystemFill))
                        )
                    }
                }
            }
        }
    }
    
    private var puzzleSelector: some View {
        HStack {
            Text("Puzzle:")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
            
            Menu {
                // None option to clear selection
                Button("None") {
                    viewModel.selectedPuzzle = nil
                }
                
                Divider()
                
                ForEach(viewModel.puzzles, id: \.id) { puzzle in
                    Button(puzzle.name) {
                        viewModel.selectedPuzzle = puzzle
                        scene.loadGamePuzzle(puzzle)
                    }
                }
            } label: {
                HStack {
                    Text(viewModel.selectedPuzzle?.name ?? "None")
                        .font(.system(size: 15))
                        .foregroundColor(viewModel.selectedPuzzle == nil ? .secondary : .primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            .disabled(viewModel.puzzles.isEmpty)
            
            Spacer()
        }
    }
    
    private var entranceDirectionSelector: some View {
        HStack {
            Text("Entrance Direction:")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
            
            Menu {
                ForEach(AnimationLabScene.EntranceDirection.allCases, id: \.self) { direction in
                    Button(action: {
                        selectedEntranceDirection = direction
                        scene.setEntranceDirection(direction)
                    }) {
                        HStack {
                            Text(direction.displayName)
                            if selectedEntranceDirection == direction {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: iconForEntranceDirection(selectedEntranceDirection))
                        .font(.system(size: 14))
                    Text(selectedEntranceDirection.displayName)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            
            Spacer()
        }
    }
    
    private func iconForEntranceDirection(_ direction: AnimationLabScene.EntranceDirection) -> String {
        switch direction {
        case .up: return "arrow.down"  // Opposite arrow since pieces come FROM this direction
        case .down: return "arrow.up"
        case .left: return "arrow.right"
        case .right: return "arrow.left"
        case .upLeft: return "arrow.down.right"
        case .upRight: return "arrow.down.left"
        case .downLeft: return "arrow.up.right"
        case .downRight: return "arrow.up.left"
        case .random: return "shuffle"
        }
    }
    
    private var exitDirectionSelector: some View {
        HStack {
            Text("Exit Direction:")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
            
            Menu {
                ForEach(AnimationLabScene.ExitDirection.allCases, id: \.self) { direction in
                    Button(action: {
                        selectedExitDirection = direction
                        scene.setExitDirection(direction)
                    }) {
                        HStack {
                            Text(direction.displayName)
                            if selectedExitDirection == direction {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: iconForExitDirection(selectedExitDirection))
                        .font(.system(size: 14))
                    Text(selectedExitDirection.displayName)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            
            Spacer()
        }
    }
    
    private func iconForExitDirection(_ direction: AnimationLabScene.ExitDirection) -> String {
        switch direction {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        case .upLeft: return "arrow.up.left"
        case .upRight: return "arrow.up.right"
        case .downLeft: return "arrow.down.left"
        case .downRight: return "arrow.down.right"
        }
    }
    
    private var animationList: some View {
        ScrollView {
            if selectedSection != .generic && viewModel.selectedPuzzle == nil {
                // Show prompt to select puzzle
                VStack(spacing: 12) {
                    Image(systemName: "puzzlepiece")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a puzzle above to preview animations")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(filteredAnimations) { animation in
                        AnimationRowView(
                            animation: animation,
                            isSelected: viewModel.selectedAnimation == animation,
                            showPuzzleSelector: false,  // No individual puzzle selectors
                            onSelect: {
                                viewModel.selectedAnimation = animation
                                if animation.requiresPuzzle && viewModel.selectedPuzzle != nil {
                                    triggerAnimation(animation)
                                } else if !animation.requiresPuzzle {
                                    triggerAnimation(animation)
                                }
                            },
                            onPlay: {
                                if animation.requiresPuzzle && viewModel.selectedPuzzle == nil {
                                    // Don't play if puzzle required but not selected
                                    return
                                }
                                triggerAnimation(animation)
                            }
                        )
                        
                        if animation != filteredAnimations.last {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private var filteredAnimations: [AnimationLabViewModel.AnimationItem] {
        viewModel.animations.filter { animation in
            switch selectedSection {
            case .generic:
                return !animation.requiresPuzzle
            case .celebration:
                return animation.category == .celebration
            case .entrance:
                return animation.category == .entrance
            case .exit:
                return animation.category == .exit
            }
        }
    }
    
    private func triggerAnimation(_ animation: AnimationLabViewModel.AnimationItem) {
        // Ensure puzzle is loaded if required
        if animation.requiresPuzzle && viewModel.selectedPuzzle == nil {
            return
        }
        
        switch animation.type {
        case .squareTakeover:
            // Create fullscreen scene for Row Slide
            let screenSize = UIScreen.main.bounds.size
            let fullScene = AnimationLabScene(size: screenSize)
            fullScene.scaleMode = .resizeFill
            fullScene.backgroundColor = SKColor(named: "GameBackground") ?? .black
            self.fullscreenScene = fullScene
            
            withAnimation(.easeIn(duration: 0.3)) {
                showFullscreenAnimation = true
            }
            
            // Start animation immediately
            fullScene.runSquareTakeover()
            // Auto-hide before animation fully ends to avoid white screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {  // End before 6s animation
                self.showFullscreenAnimation = false
                self.fullscreenScene = nil
            }
        case .squareWave:
            // Create fullscreen scene for Column Slide
            let screenSize = UIScreen.main.bounds.size
            let fullScene = AnimationLabScene(size: screenSize)
            fullScene.scaleMode = .resizeFill
            fullScene.backgroundColor = SKColor(named: "GameBackground") ?? .black
            self.fullscreenScene = fullScene
            
            withAnimation(.easeIn(duration: 0.3)) {
                showFullscreenAnimation = true
            }
            
            // Start animation immediately
            fullScene.runSquareWave()
            // Auto-hide before animation fully ends to avoid white screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {  // End before 6s animation
                self.showFullscreenAnimation = false
                self.fullscreenScene = nil
            }
        case .squareSpiral:
            scene.runSquareSpiral()
        case .assemble:
            scene.runEntrance()
        case .celebration:
            scene.runCelebration()
        case .celebrationExit:
            scene.runCelebrationExit()
        case .breathing:
            scene.startBreathingLoop()
        case .pulse:
            scene.runPulseOnce()
        case .wobble:
            scene.startWobbleLoop()
        case .happyJump:
            scene.runHappyJumpOnce()
        case .shimmer:
            scene.startShimmerLoop()
        case .disassemble:
            scene.runDisassembleExit()
        case .fadeIn, .scatter:
            // These would need implementation
            break
        }
    }
}

struct AnimationRowView: View {
    let animation: AnimationLabViewModel.AnimationItem
    let isSelected: Bool
    let showPuzzleSelector: Bool
    let onSelect: () -> Void
    let onPlay: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Animation info
            VStack(alignment: .leading, spacing: 4) {
                Text(animation.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                if animation.category != .generic {
                    HStack(spacing: 4) {
                        Image(systemName: iconForCategory(animation.category))
                            .font(.system(size: 12))
                        Text(animation.group.rawValue.capitalized)
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Play button
            Button(action: onPlay) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isSelected ? Color(.tertiarySystemFill) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
    
    private func iconForCategory(_ category: AnimationLabViewModel.AnimationCategory) -> String {
        switch category {
        case .generic: return "sparkles"
        case .celebration: return "party.popper"
        case .entrance: return "arrow.right.to.line"
        case .exit: return "arrow.left.to.line"
        }
    }
}

#Preview {
    AnimationLabContainerView(viewModel: AnimationLabViewModel(puzzleService: nil))
}