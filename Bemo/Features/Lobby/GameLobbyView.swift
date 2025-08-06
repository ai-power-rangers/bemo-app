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
    @State private var showingFontTest = false // Temporary for font testing
    
    var body: some View {
        ZStack {
            BemoTheme.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Navigation Bar
                HeaderView(
                    profileName: viewModel.displayProfile?.name,
                    profileAvatar: viewModel.displayProfile?.avatar,
                    onMenuTapped: {
                        showingSideMenu = true
                    }
                )
                
                // Welcome Message & Font Test Button
                HStack {
                    VStack(alignment: .leading, spacing: BemoTheme.Spacing.xsmall) {
                        Text("Hello,")
                            .font(BemoTheme.font(for: .heading2))
                            .foregroundColor(BemoTheme.Colors.primary)
                        
                        Text("\(viewModel.displayProfile?.name ?? "Friend")!")
                            .font(BemoTheme.font(for: .heading2))
                            .foregroundColor(BemoTheme.Colors.primary)
                        
                        Text("Nice to see you again!")
                            .font(BemoTheme.font(for: .body))
                            .foregroundColor(BemoTheme.Colors.gray2)
                    }
                    
                    Spacer()
                    
                    // Temporary Font Test Button
                    Button("🔤") {
                        showingFontTest = true
                    }
                    .font(.title2)
                    .padding(.trailing)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, BemoTheme.Spacing.xlarge)
                .padding(.top, BemoTheme.Spacing.large)
                
                // Section Title
                Text("Games")
                    .font(BemoTheme.font(for: .heading3))
                    .foregroundColor(BemoTheme.Colors.gray1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, BemoTheme.Spacing.xlarge)
                    .padding(.top, BemoTheme.Spacing.xxlarge)
                    .padding(.bottom, BemoTheme.Spacing.large)
                
                // Games Grid
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150), spacing: BemoTheme.Spacing.large)],
                        spacing: BemoTheme.Spacing.large
                    ) {
                        ForEach(Array(viewModel.availableGames.enumerated()), id: \.element.id) { index, gameItem in
                            GameCardView(
                                game: GameItem(
                                    game: gameItem.game,
                                    colorScheme: (index % 4) + 1,
                                    isLocked: false  // MVP: All games accessible
                                ),
                                onTap: {
                                    viewModel.selectGame(gameItem.game)
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
        .sheet(isPresented: $showingFontTest) {
            FontTestView()
        }
        .alert("Authentication Required", isPresented: $viewModel.showAuthenticationError) {
            Button("OK") {}
        } message: {
            Text("You must have Face ID, Touch ID, or a passcode set up to access the parent dashboard.")
        }
    }
}

