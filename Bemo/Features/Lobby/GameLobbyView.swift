//
//  GameLobbyView.swift
//  Bemo
//
//  Game selection screen where children choose which game to play
//

// WHAT: Main menu view showing available games, active child profile, and parent dashboard access. First screen users see.
// ARCHITECTURE: View layer for game selection in MVVM-S. Displays games grid and profile info from GameLobbyViewModel.
// USAGE: Created by AppCoordinator as default view. Shows game cards, handles selection, displays profile badge and XP.

import SwiftUI

struct GameLobbyView: View {
    @State var viewModel: GameLobbyViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [Color.orange.opacity(0.3), Color.pink.opacity(0.3)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack {
                    // Profile section
                    HStack {
                        if let profile = viewModel.displayProfile {
                            ProfileBadgeView(profile: profile)
                        } else {
                            Text("No Profile Selected")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(15)
                        }
                        
                        Spacer()
                        
                        // Parent dashboard button
                        Button(action: {
                            viewModel.openParentDashboard()
                        }) {
                            Image(systemName: "person.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.purple)
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    
                    // Title
                    Text("Choose Your Adventure!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                    
                    // Games grid
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 20),
                            GridItem(.flexible(), spacing: 20)
                        ], spacing: 20) {
                            ForEach(viewModel.availableGames) { gameItem in
                                GameCardView(
                                    game: gameItem,
                                    isLocked: !viewModel.isGameUnlocked(gameItem.game)
                                ) {
                                    viewModel.selectGame(gameItem.game)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .alert(isPresented: $viewModel.showProfileSelection) {
            Alert(
                title: Text("Who's Playing?"),
                message: Text("Please select a profile to continue"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct ProfileBadgeView: View {
    let profile: GameLobbyViewModel.Profile
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.white)
            
            VStack(alignment: .leading) {
                Text(profile.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("Level \(profile.level)")
                        .foregroundColor(.white)
                    Text("• \(profile.xp) XP")
                        .foregroundColor(.white.opacity(0.8))
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(15)
    }
}

struct GameCardView: View {
    let game: GameLobbyViewModel.GameItem
    let isLocked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                // Game thumbnail
                RoundedRectangle(cornerRadius: 20)
                    .fill(game.color)
                    .frame(height: 150)
                    .overlay(
                        Image(systemName: game.iconName)
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    )
                    .overlay(
                        isLocked ? 
                        Color.black.opacity(0.6)
                            .overlay(
                                Image(systemName: "lock.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                            )
                        : nil
                    )
                
                // Game info
                VStack(alignment: .leading) {
                    Text(game.game.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Ages \(game.game.recommendedAge.lowerBound)-\(game.game.recommendedAge.upperBound)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 5)
        }
        .disabled(isLocked)
    }
}