//
//  SpellQuestGameView.swift
//  Bemo
//
//  Root view for SpellQuest game managing navigation between screens
//

// WHAT: Main container view handling navigation between mode select, library, and gameplay
// ARCHITECTURE: View layer in MVVM-S, observes ViewModel state changes
// USAGE: Created by SpellQuestGame.makeGameView()

import SwiftUI

struct SpellQuestGameView: View {
    @State private var viewModel: SpellQuestGameViewModel
    
    init(viewModel: SpellQuestGameViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Navigation
                VStack {
                    switch viewModel.navigationState {
                    case .modeSelect:
                        ModeSelectView(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                        
                    case .librarySelect:
                        LibraryView(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                        
                    case .playing:
                        GameplayContainerView(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.navigationState)
    }
}

// Container for different gameplay modes
private struct GameplayContainerView: View {
    let viewModel: SpellQuestGameViewModel
    
    var body: some View {
        Group {
            switch viewModel.selectedMode {
            case .zen:
                ZenView(viewModel: viewModel)
            case .zenJunior:
                ZenJuniorView(viewModel: viewModel)
            case nil:
                EmptyView()
            }
        }
    }
}