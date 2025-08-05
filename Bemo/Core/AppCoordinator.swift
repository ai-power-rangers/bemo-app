//
//  AppCoordinator.swift
//  Bemo
//
//  Central navigation coordinator that manages app flow
//

// WHAT: Manages app navigation and view transitions. Holds DependencyContainer and publishes the current root view based on app state.
// ARCHITECTURE: Central coordinator in MVVM-S. Creates ViewModels with injected dependencies and manages navigation flow between features.
// USAGE: Create as @StateObject in BemoApp. Access rootView property for display. Call start() to begin app flow.

import SwiftUI

class AppCoordinator: ObservableObject {
    private let dependencyContainer: DependencyContainer
    
    enum AppState {
        case lobby
        case game(Game)
        case parentDashboard
    }
    
    @Published private var currentState: AppState = .lobby
    
    init() {
        self.dependencyContainer = DependencyContainer()
    }
    
    func start() {
        currentState = .lobby
    }
    
    @ViewBuilder
    var rootView: some View {
        switch currentState {
        case .lobby:
            GameLobbyView(viewModel: GameLobbyViewModel(
                profileService: self.dependencyContainer.profileService,
                gamificationService: self.dependencyContainer.gamificationService,
                onGameSelected: { [weak self] selectedGame in
                    self?.currentState = .game(selectedGame)
                },
                onParentDashboardRequested: { [weak self] in
                    self?.currentState = .parentDashboard
                }
            ))
            
        case .game(let game):
            GameHostView(viewModel: GameHostViewModel(
                game: game,
                cvService: self.dependencyContainer.cvService,
                gamificationService: self.dependencyContainer.gamificationService,
                profileService: self.dependencyContainer.profileService
            ) { [weak self] in
                self?.currentState = .lobby
            })
            
        case .parentDashboard:
            ParentDashboardView(viewModel: ParentDashboardViewModel(
                profileService: self.dependencyContainer.profileService,
                apiService: self.dependencyContainer.apiService
            ) { [weak self] in
                self?.currentState = .lobby
            })
        }
    }
}