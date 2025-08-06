//
//  GameHostView.swift
//  Bemo
//
//  SwiftUI view that hosts the active game's view
//

// WHAT: Container view that displays the active game's UI. Provides common overlay controls (quit, hints, progress) for all games.
// ARCHITECTURE: View layer of game hosting in MVVM-S. Displays game view from ViewModel and handles common UI elements.
// USAGE: Created by AppCoordinator with GameHostViewModel. The gameView property displays the active game's content.

import SwiftUI

struct GameHostView: View {
    @State var viewModel: GameHostViewModel
    
    var body: some View {
        let config = viewModel.game.gameUIConfig
        
        ZStack {
            // Game content with conditional safe area handling
            Group {
                if config.respectsSafeAreas {
                    viewModel.gameView
                } else {
                    viewModel.gameView
                        .ignoresSafeArea()
                }
            }
            
            // Overlay UI elements
            VStack {
                // Top bar (quit button and progress)
                HStack {
                    // Quit button (if enabled)
                    if config.showQuitButton {
                        Button(action: {
                            viewModel.handleQuitRequest()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding()
                    }
                    
                    Spacer()
                    
                    // Progress indicator (if enabled and showing)
                    if config.showProgressBar && viewModel.showProgress {
                        ProgressView(value: viewModel.progress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 200)
                            .padding()
                    }
                }
                
                // Custom top bar if provided
                if let customTopBar = config.customTopBar {
                    customTopBar
                }
                
                Spacer()
                
                // Custom bottom bar if provided
                if let customBottomBar = config.customBottomBar {
                    customBottomBar
                }
                
                // Bottom controls
                if config.showHintButton {
                    HStack {
                        // Hint button
                        Button(action: {
                            viewModel.requestHint()
                        }) {
                            Label("Hint", systemImage: "lightbulb.fill")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding()
                        
                        Spacer()
                    }
                }
            }
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.endSession()
        }
    }
}