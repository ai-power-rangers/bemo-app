//
//  BoardView.swift
//  Bemo
//
//  Core puzzle board view with drag-and-drop mechanics
//

// WHAT: Main gameplay board showing image, letter slots, and draggable letter tiles
// ARCHITECTURE: View layer in MVVM-S with drag gesture handling
// USAGE: Used by all game mode views to display interactive puzzle board

import SwiftUI

struct BoardView: View {
    let viewModel: PlayerBoardViewModel
    let isZenJunior: Bool
    @State private var showingIncorrectFeedback: Bool = false
    @State private var incorrectLetter: Character? = nil
    @Namespace private var letterNamespace
    
    // Dynamic scaling based on screen size
    private func dynamicScaleFactor(for screenHeight: CGFloat) -> CGFloat {
        let baseScale = isZenJunior ? SpellQuestConstants.UI.zenJuniorScaleFactor : 1.0
        let heightFactor = min(screenHeight / 600, 2.0) // Scale up to 2x for larger screens
        return baseScale * max(heightFactor, 1.0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let scaleFactor = dynamicScaleFactor(for: geometry.size.height)
            let isLargeScreen = geometry.size.height > 800
            
            VStack(spacing: 20 * scaleFactor) {
                Spacer(minLength: isLargeScreen ? 40 : 20)
                
                // Puzzle Image - scales with screen
                puzzleImageView(scaleFactor: scaleFactor)
                    .frame(maxWidth: min(geometry.size.width - 40, 600 * scaleFactor))
                    .frame(maxHeight: geometry.size.height * 0.35)
                
                // Letter Slots - centered
                letterSlotsView(scaleFactor: scaleFactor)
                    .padding(.horizontal, 20)
                
                // Error feedback
                if showingIncorrectFeedback, let letter = incorrectLetter {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("\(String(letter)) is not correct")
                            .font(.system(size: 16 * scaleFactor, weight: .medium))
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.red.opacity(0.1))
                    )
                    .padding(.horizontal)
                    .transition(.scale.combined(with: .opacity))
                }
                
                Spacer(minLength: 10)
                
                // Letter Rack - scales with screen
                letterRackView(scaleFactor: scaleFactor)
                    .frame(maxWidth: min(geometry.size.width, 800))
                    .padding(.bottom, isLargeScreen ? 40 : 20)
                
                Spacer(minLength: isLargeScreen ? 40 : 20)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    // MARK: - Puzzle Image
    private func puzzleImageView(scaleFactor: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 10)
            
            if !viewModel.boardState.currentPuzzle.imageName.isEmpty {
                // Check if it's a local asset first
                if let img = UIImage(named: viewModel.boardState.currentPuzzle.imageName) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else if let url = URL(string: viewModel.boardState.currentPuzzle.imageName) {
                    // It's a remote URL, use AsyncImage
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .padding()
                        case .failure(_):
                            placeholderView
                        case .empty:
                            ProgressView()
                                .padding()
                        @unknown default:
                            placeholderView
                        }
                    }
                } else {
                    // Fallback placeholder
                    placeholderView
                }
            }
        }
        .aspectRatio(4/3, contentMode: .fit)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var placeholderView: some View {
        VStack {
            Image(systemName: "photo.fill")
                .font(.system(size: 60))
                .foregroundColor(Color("AppPrimaryTextColor").opacity(0.3))
            Text(viewModel.boardState.currentPuzzle.displayTitle ?? "")
                .font(.title2)
                .foregroundColor(Color("AppPrimaryTextColor"))
        }
    }
    
    // MARK: - Letter Slots
    private func letterSlotsView(scaleFactor: CGFloat) -> some View {
        HStack(spacing: SpellQuestConstants.UI.slotSpacing * scaleFactor) {
            ForEach(Array(viewModel.boardState.slots.enumerated()), id: \.element.id) { index, slot in
                LetterSlotView(
                    slot: slot,
                    index: index,
                    isHighlighted: viewModel.highlightedSlotIndex == index,
                    isTargeted: false,
                    scaleFactor: scaleFactor
                )
                .onTapGesture {
                    // If slot is filled, remove the letter
                    if slot.isFilled && !slot.isRevealedByHint {
                        viewModel.removeLetter(at: index)
                    }
                }
            }
        }
        .modifier(ShakeEffect(shakes: viewModel.isShaking ? 2 : 0))
    }
    
    // MARK: - Letter Rack
    private func letterRackView(scaleFactor: CGFloat) -> some View {
        VStack(spacing: 12 * scaleFactor) {
            // First row: A-I
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6 * scaleFactor) {
                    ForEach(Array("ABCDEFGHI"), id: \.self) { letter in
                        letterTile(for: letter, scaleFactor: scaleFactor)
                    }
                }
                .padding(.horizontal, 4)
            }
            
            // Second row: J-R
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6 * scaleFactor) {
                    ForEach(Array("JKLMNOPQR"), id: \.self) { letter in
                        letterTile(for: letter, scaleFactor: scaleFactor)
                    }
                }
                .padding(.horizontal, 4)
            }
            
            // Third row: S-Z
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6 * scaleFactor) {
                    ForEach(Array("STUVWXYZ"), id: \.self) { letter in
                        letterTile(for: letter, scaleFactor: scaleFactor)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal, 10)
    }
    
    // MARK: - Letter Tile
    private func letterTile(for letter: Character, scaleFactor: CGFloat) -> some View {
        LetterTileView(
            letter: letter,
            isHighlighted: viewModel.highlightedLetter == letter,
            scaleFactor: scaleFactor,
            namespace: letterNamespace
        )
        .onTapGesture {
            handleLetterTap(letter)
        }
    }
    
    // MARK: - Letter Tap Handler
    private func handleLetterTap(_ letter: Character) {
        // Find first empty slot
        guard let firstEmptyIndex = viewModel.boardState.slots.firstIndex(where: { !$0.isFilled }) else {
            // No empty slots
            return
        }
        
        // Attempt to place the letter
        let result = viewModel.attemptPlace(letter: letter, atSlotIndex: firstEmptyIndex)
        
        switch result {
        case .correctPlacement:
            // Success - letter placed correctly
            showingIncorrectFeedback = false
            incorrectLetter = nil
            
        case .incorrectPlacement:
            // Show error feedback
            incorrectLetter = letter
            showingIncorrectFeedback = true
            
            // Hide feedback after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showingIncorrectFeedback = false
                incorrectLetter = nil
            }
            
        case .alreadyFilled:
            // Shouldn't happen with our logic
            break
        }
    }
}

// MARK: - Supporting Views

private struct LetterSlotView: View {
    let slot: LetterSlot
    let index: Int
    let isHighlighted: Bool
    let isTargeted: Bool
    let scaleFactor: CGFloat
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(slotBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(slotBorderColor, lineWidth: slot.isFilled ? 2 : 1)
                )
            
            if let letter = slot.currentLetter {
                Text(String(letter))
                    .font(.system(size: 36 * scaleFactor, weight: .bold))
                    .foregroundColor(slot.isRevealedByHint ? .orange : SpellQuestConstants.Colors.letterColor(for: letter))
                    .transition(.scale.combined(with: .opacity))
            } else {
                // Show placeholder dash for empty slots
                Text("_")
                    .font(.system(size: 36 * scaleFactor, weight: .light))
                    .foregroundColor(.gray.opacity(0.3))
            }
        }
        .frame(
            width: 65 * scaleFactor,
            height: 65 * scaleFactor
        )
        .scaleEffect(slot.isFilled ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: slot.isFilled)
    }
    
    private var slotBackgroundColor: Color {
        if slot.isFilled {
            return slot.isRevealedByHint ? Color.orange.opacity(0.1) : Color.white
        } else if isTargeted {
            return Color.blue.opacity(0.2)
        } else {
            return SpellQuestConstants.Colors.slotEmpty
        }
    }
    
    private var slotBorderColor: Color {
        if isHighlighted {
            return .yellow
        } else if isTargeted {
            return .blue
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}

private struct LetterTileView: View {
    let letter: Character
    let isHighlighted: Bool
    let scaleFactor: CGFloat
    let namespace: Namespace.ID
    
    var body: some View {
        Text(String(letter))
            .font(.system(size: 28 * scaleFactor, weight: .bold))
            .foregroundColor(SpellQuestConstants.Colors.letterColor(for: letter))
            .frame(
                width: 60 * scaleFactor,
                height: 60 * scaleFactor
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(SpellQuestConstants.Colors.letterTileBackground)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHighlighted ? Color.yellow : SpellQuestConstants.Colors.letterTileBorder, lineWidth: isHighlighted ? 2 : 1)
            )
            .scaleEffect(isHighlighted ? 1.1 : 1.0)
            .animation(.spring(response: 0.3), value: isHighlighted)
    }
}

// MARK: - Effects

private struct ShakeEffect: GeometryEffect {
    var shakes: Int
    
    var animatableData: CGFloat {
        get { CGFloat(shakes) }
        set { shakes = Int(newValue) }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = sin(animatableData * .pi * 2) * 10
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}