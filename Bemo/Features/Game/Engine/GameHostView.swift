//
//  GameHostView.swift
//  Bemo
//
//  SwiftUI view that hosts the active game's view
//


// This is the physical screen or the container View. It's a SwiftUI View struct.
// Its Job: To display the UI of whatever game is currently active.

// What it Does:
// It holds an instance of the GameHostViewModel.
// It asks the active Game module to provide its specific SwiftUI view (by calling makeGameView(...)).
// It places that game's view inside itself for the user to see. It might also contain UI elements that are common to all games, like a main "Pause" button or a header.



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