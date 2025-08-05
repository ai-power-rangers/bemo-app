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
    @StateObject var viewModel: GameHostViewModel
    
    var body: some View {
        ZStack {
            // Game content
            viewModel.gameView
                .ignoresSafeArea()
            
            // Overlay UI elements
            VStack {
                HStack {
                    // Back button
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
                    
                    Spacer()
                    
                    // Progress indicator
                    if viewModel.showProgress {
                        ProgressView(value: viewModel.progress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 200)
                            .padding()
                    }
                }
                
                Spacer()
                
                // Bottom controls
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