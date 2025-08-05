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