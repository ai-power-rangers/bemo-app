//
//  AquaMathGameView.swift
//  Bemo
//
//  Main SwiftUI view for AquaMath game
//

// WHAT: Root SwiftUI view composing the AquaMath game UI
// ARCHITECTURE: View layer in MVVM-S, observes ViewModel state
// USAGE: Created by AquaMathGame.makeGameView(), renders game UI

import SwiftUI
import SpriteKit

struct AquaMathGameView: View {
    @State private var viewModel: AquaMathGameViewModel
    @State private var gameScene: GameScene?
    
    init(viewModel: AquaMathGameViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            // Base layer: SpriteKit scene
            SpriteView(
                scene: makeGameScene(),
                options: [.allowsTransparency]
            )
            .ignoresSafeArea()
            
            // UI overlay
            VStack(spacing: 0) {
                // HUD at top
                HUDView(viewModel: viewModel)
                    .padding(.horizontal)
                    .padding(.top, 50)
                
                Spacer()
                
                // Calculation display above tile tray
                CalculationDisplayView(viewModel: viewModel)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                
                // Tile tray at bottom
                GeometryReader { geometry in
                    let isLargeScreen = geometry.size.width > 600
                    TileTrayView(viewModel: viewModel)
                        .frame(height: isLargeScreen ? 140 : 100)
                        .background(Color(red: 0.85, green: 0.92, blue: 0.98))
                }
                .frame(height: UIScreen.main.bounds.width > 600 ? 140 : 100)
            }
        }
        .onAppear {
            viewModel.audioService.startBackgroundMusic()
        }
        .onDisappear {
            viewModel.audioService.stopBackgroundMusic()
        }
    }
    
    private func makeGameScene() -> GameScene {
        if let scene = gameScene {
            return scene
        } else {
            let scene = GameScene(size: UIScreen.main.bounds.size)
            scene.scaleMode = .resizeFill
            viewModel.setGameScene(scene)
            self.gameScene = scene
            return scene
        }
    }
}

// MARK: - HUD View

struct HUDView: View {
    let viewModel: AquaMathGameViewModel
    
    var body: some View {
        HStack {
            // Mode name on the left
            Text(viewModel.selectedMode.displayName.uppercased())
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            
            Spacer()
            
            // Score in center
            VStack(spacing: 4) {
                Text("Score")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text("\(viewModel.score)")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(.easeInOut, value: viewModel.score)
            }
            .shadow(radius: 2)
            
            Spacer()
            
            // Fish progress on right
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Image(systemName: index < viewModel.collectedFish.count ? "fish.fill" : "fish")
                        .font(.title2)
                        .foregroundColor(index < viewModel.collectedFish.count ? .yellow : .white.opacity(0.3))
                        .shadow(radius: 2)
                }
            }
        }
    }
}

// MARK: - Calculation Display

struct CalculationDisplayView: View {
    let viewModel: AquaMathGameViewModel
    
    var body: some View {
        HStack {
            // Clear workspace button
            Button(action: {
                viewModel.clearWorkspace()
            }) {
                Image(systemName: "trash.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
            }
            .opacity(viewModel.gameState.tileGroups.isEmpty ? 0.3 : 1.0)
            .disabled(viewModel.gameState.tileGroups.isEmpty)
            
            Spacer()
            
            // Equation display - now shown inline in the workspace
            // Removed to avoid duplication
            
            Spacer()
            
            // Mode selector
            Menu {
                ForEach(GameMode.allCases, id: \.self) { mode in
                    Button(mode.displayName) {
                        viewModel.selectedMode = mode
                    }
                }
            } label: {
                Image(systemName: "gear.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Tile Tray

struct TileTrayView: View {
    let viewModel: AquaMathGameViewModel
    
    var body: some View {
        GeometryReader { geometry in
            let isLargeScreen = geometry.size.width > 600
            let tileCount = viewModel.availableTiles.count
            let tileSize = calculateTileSize(for: geometry.size.width, isLargeScreen: isLargeScreen)
            let spacing = isLargeScreen ? 20.0 : 15.0
            let totalWidth = CGFloat(tileCount) * tileSize + CGFloat(tileCount - 1) * spacing
            let needsScroll = totalWidth > geometry.size.width - 40
            
            if needsScroll {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing) {
                        ForEach(viewModel.availableTiles, id: \.self) { tileKind in
                            TileView(kind: tileKind, viewModel: viewModel, tileSize: tileSize, isLargeScreen: isLargeScreen)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, isLargeScreen ? 15 : 10)
                }
            } else {
                // Center tiles when they fit
                HStack(spacing: spacing) {
                    ForEach(viewModel.availableTiles, id: \.self) { tileKind in
                        TileView(kind: tileKind, viewModel: viewModel, tileSize: tileSize, isLargeScreen: isLargeScreen)
                    }
                }
                .padding(.vertical, isLargeScreen ? 15 : 10)
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func calculateTileSize(for screenWidth: CGFloat, isLargeScreen: Bool) -> CGFloat {
        if isLargeScreen {
            // iPad/large screens
            return min(110, screenWidth / 12)
        } else {
            // iPhone/small screens
            return 70
        }
    }
}

// MARK: - Individual Tile View

struct TileView: View {
    let kind: TileKind
    let viewModel: AquaMathGameViewModel
    let tileSize: CGFloat
    let isLargeScreen: Bool
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: {
            viewModel.tapTile(kind)
        }) {
            ZStack {
                // White background tile
                RoundedRectangle(cornerRadius: isLargeScreen ? 16 : 12)
                    .fill(Color.white)
                    .frame(width: tileSize, height: tileSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: isLargeScreen ? 16 : 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: isLargeScreen ? 1.5 : 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: isLargeScreen ? 4 : 2, x: 0, y: isLargeScreen ? 3 : 2)
                
                // Colored number/content with dynamic font size
                Text(kind.displayValue)
                    .font(dynamicFont(for: kind.displayValue.count))
                    .foregroundColor(kind.numberColor)
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    private func dynamicFont(for charCount: Int) -> Font {
        if isLargeScreen {
            // Larger fonts for iPads
            return charCount > 2 ? .title2.bold() : .system(size: 48, weight: .bold)
        } else {
            // Standard fonts for iPhones
            return charCount > 2 ? .body.bold() : .title.bold()
        }
    }
}

// MARK: - Preview

#Preview {
    AquaMathGameView(
        viewModel: AquaMathGameViewModel(
            delegate: PreviewGameDelegate()
        )
    )
}

// Preview helper
class PreviewGameDelegate: GameDelegate {
    func gameDidCompleteLevel(xpAwarded: Int) {}
    func gameDidRequestQuit() {}
    func gameDidRequestHint() {}
    func gameDidEncounterError(_ error: Error) {}
    func gameDidUpdateProgress(_ progress: Float) {}
    func gameDidDetectFrustration(level: Float) {}
}