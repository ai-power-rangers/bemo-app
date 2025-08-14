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
            BemoTheme.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Navigation Bar
                HeaderView(
                    profileName: viewModel.currentUserProfile?.name,
                    avatarSymbol: viewModel.currentUserProfile?.avatarSymbol,
                    avatarColor: viewModel.currentUserProfile?.avatarColor,
                    onMenuTapped: {
                        showingSideMenu = true
                    },
                    onProfileTapped: {
                        viewModel.showProfileDetailsView()
                    }
                )
                
                // Welcome Message
                VStack(alignment: .leading, spacing: BemoTheme.Spacing.xsmall) {
                    Text("Hello,")
                        .font(BemoTheme.font(for: .heading2))
                        .foregroundColor(BemoTheme.Colors.primary)
                    
                    Text("\(viewModel.displayProfile?.name ?? "Friend")!")
                        .font(BemoTheme.font(for: .heading2))
                        .foregroundColor(BemoTheme.Colors.primary)                    
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, BemoTheme.Spacing.xlarge)
                .padding(.top, BemoTheme.Spacing.large)
                
                // Games Grid
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150), spacing: BemoTheme.Spacing.large)],
                        spacing: BemoTheme.Spacing.large
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
                        }
                    }
                    .padding(.horizontal, BemoTheme.Spacing.xlarge)
                    .padding(.bottom, BemoTheme.Spacing.xlarge)
                }
            }
        }
        .sheet(isPresented: $showingSideMenu) {
            SideMenuView(
                isPresented: $showingSideMenu,
                onParentDashboardTapped: {
                    showingSideMenu = false
                    viewModel.requestParentalAccess()
                }
            )
        }
        .sheet(isPresented: $viewModel.showProfileDetails) {
            if let currentProfile = viewModel.currentUserProfile {
                ProfileDetailsView(
                    profile: currentProfile,
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

