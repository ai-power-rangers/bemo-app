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
    @State private var showingSideMenu = false
    
    var body: some View {
        ZStack {
            // Background using AppBackground asset
            Color("AppBackground")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Navigation Bar with Profile badge and Hamburger menu
                HStack {
                    // Profile Badge
                    Button(action: {
                        viewModel.showProfileDetailsView()
                    }) {
                        ProfileBadgeView(
                            name: viewModel.currentUserProfile?.name,
                            avatarSymbol: viewModel.currentUserProfile?.avatarSymbol,
                            avatarColor: viewModel.currentUserProfile?.avatarColor
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    // Hamburger Menu Button
                    Button(action: {
                        showingSideMenu = true
                    }) {
                        Image(systemName: "line.horizontal.3")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(Color(hex: "#333333"))
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)
                
                // Welcome Message
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back,")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(Color(hex: "#666666"))
                    
                    Text(viewModel.displayProfile?.name ?? "Friend")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(hex: "#333333"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                
                // Games Grid
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 20),
                            GridItem(.flexible(), spacing: 20)
                        ],
                        spacing: 20
                    ) {
                        ForEach(Array(viewModel.availableGames.enumerated()), id: \.element.id) { index, gameItem in
                            GameCardView(
                                game: {
                                    if let game = gameItem.game {
                                        return GameItem(game: game, colorScheme: (index % 4) + 1, isLocked: false)
                                    } else if let devTool = gameItem.devTool {
                                        return GameItem(devTool: devTool, colorScheme: (index % 4) + 1, isLocked: false)
                                    } else {
                                        fatalError("GameItem has neither game nor devTool")
                                    }
                                }(),
                                onTap: {
                                    viewModel.selectGameItem(gameItem)
                                }
                            )
                            .aspectRatio(1, contentMode: .fit)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .sheet(isPresented: $showingSideMenu) {
            SideMenuView(
                isPresented: $showingSideMenu,
                onParentDashboardTapped: {
                    showingSideMenu = false
                    viewModel.requestParentalAccess()
                },
                audioService: viewModel.audioService,
                profileService: viewModel.profileService
            )
        }
        .sheet(isPresented: $viewModel.showProfileDetails) {
            if let currentProfile = viewModel.currentUserProfile {
                ProfileDetailsView(
                    profile: currentProfile,
                    profileService: viewModel.profileService,
                    audioService: viewModel.audioService,
                    onSwitchProfile: {
                        viewModel.switchProfileFromDetails()
                    },
                    onDismiss: {
                        viewModel.hideProfileDetailsView()
                    }
                )
            }
        }
        .sheet(isPresented: $viewModel.showProfileModal) {
            ProfileSelectionModal(
                profiles: viewModel.availableProfiles,
                onProfileSelected: { profile in
                    viewModel.selectProfile(profile)
                },
                onAddProfile: {
                    viewModel.addNewProfile()
                },
                onDismiss: {
                    viewModel.hideProfileSelectionModal()
                }
            )
        }
        .alert("Authentication Required", isPresented: $viewModel.showAuthenticationError) {
            Button("OK") {}
        } message: {
            Text("You must have Face ID, Touch ID, or a passcode set up to access the parent dashboard.")
        }
    }
}

