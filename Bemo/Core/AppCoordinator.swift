//
//  AppCoordinator.swift
//  Bemo
//
//  Central navigation coordinator that manages app flow
//

import SwiftUI
import Combine

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
                profileService: dependencyContainer.profileService,
                gamificationService: dependencyContainer.gamificationService
            ) { [weak self] selectedGame in
                self?.currentState = .game(selectedGame)
            })
            
        case .game(let game):
            GameHostView(viewModel: GameHostViewModel(
                game: game,
                cvService: dependencyContainer.cvService,
                gamificationService: dependencyContainer.gamificationService,
                profileService: dependencyContainer.profileService
            ) { [weak self] in
                self?.currentState = .lobby
            })
            
        case .parentDashboard:
            ParentDashboardView(viewModel: ParentDashboardViewModel(
                profileService: dependencyContainer.profileService,
                apiService: dependencyContainer.apiService
            ) { [weak self] in
                self?.currentState = .lobby
            })
        }
    }
}