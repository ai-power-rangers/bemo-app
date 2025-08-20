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
                // Top Navigation Bar with Hamburger menu, Profile badge, and Welcome message
                HStack(spacing: 16) {
                    // Hamburger Menu Button (Left)
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
                    
                    Spacer()
                    
                    // Profile Badge and Welcome Message (Right)
                    HStack(spacing: 12) {
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
                        
                        Text(viewModel.displayProfile?.name ?? "Friend")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(Color("AppPrimaryTextColor"))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
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
                                    } else if gameItem.isComingSoon {
                                        // Create a placeholder GameItem for "Coming Soon"
                                        return GameItem(
                                            id: "coming_soon",
                                            game: nil,
                                            devTool: nil,
                                            title: "Coming Soon",
                                            iconName: "icons8-surprise-box-100",
                                            hasCustomIcon: true,
                                            colorScheme: (index % 4) + 1,
                                            isLocked: false
                                        )
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

