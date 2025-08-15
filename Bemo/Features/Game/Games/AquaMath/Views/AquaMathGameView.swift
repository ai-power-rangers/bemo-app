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
                TileTrayView(viewModel: viewModel)
                    .frame(height: 100)
                    .background(Color(red: 0.85, green: 0.92, blue: 0.98))
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
            
            // Equation display
            if !viewModel.equationString.isEmpty {
                Text(viewModel.equationString)
                    .font(.title.monospaced().bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .animation(.easeInOut, value: viewModel.equationString)
            }
            
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                ForEach(viewModel.availableTiles, id: \.self) { tileKind in
                    TileView(kind: tileKind, viewModel: viewModel)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Individual Tile View

struct TileView: View {
    let kind: TileKind
    let viewModel: AquaMathGameViewModel
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: {
            viewModel.tapTile(kind)
        }) {
            ZStack {
                // White background tile
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .frame(width: 70, height: 70)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                
                // Colored number/content
                Text(kind.displayValue)
                    .font(kind.displayValue.count > 2 ? .body.bold() : .title.bold())
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