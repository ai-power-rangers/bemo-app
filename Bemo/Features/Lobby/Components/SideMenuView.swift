//
//  SideMenuView.swift
//  Bemo
//
//  Side menu drawer with Parent Dashboard access
//

// WHAT: Simplified side menu with only Parent Dashboard option for parent access
// ARCHITECTURE: UI component presented as sheet from GameLobbyView
// USAGE: SideMenuView(isPresented: $showMenu, onParentDashboardTapped: { })

import SwiftUI

struct SideMenuView: View {
    @Binding var isPresented: Bool
    let onParentDashboardTapped: () -> Void
    let audioService: AudioService?
    let profileService: ProfileService?
    
    var body: some View {
        NavigationView {
                            ZStack {
                    // App background color from assets
                    Color("AppBackground")
                        .ignoresSafeArea()
                    
                    VStack(alignment: .leading, spacing: 0) {
                        // Menu header
                        VStack(alignment: .leading, spacing: BemoTheme.Spacing.small) {
                            Text("Menu")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(Color("AppPrimaryTextColor"))
                        }
                    .padding(.horizontal, BemoTheme.Spacing.large)
                    .padding(.top, BemoTheme.Spacing.xlarge)
                    .padding(.bottom, BemoTheme.Spacing.large)
                    
                    // Menu Items
                    VStack(spacing: BemoTheme.Spacing.large) {
                        // Parent Dashboard Section
                        MenuItemView(
                            icon: "person.2.fill",
                            title: "Parent Dashboard",
                            description: "View children's progress and settings",
                            iconColor: BemoTheme.Colors.primary,
                            action: onParentDashboardTapped
                        )
                        
                        // Audio Preferences Section
                        VStack(alignment: .leading, spacing: BemoTheme.Spacing.small) {
                            Text("Audio Settings")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(Color("AppPrimaryTextColor"))
                                .padding(.horizontal, BemoTheme.Spacing.small)
                            
                            VStack(spacing: 0) {
                                // Sound Effects Toggle
                                HStack {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    
                                    Text("Sound Effects")
                                        .font(.system(size: 15, design: .rounded))
                                        .foregroundColor(Color("AppPrimaryTextColor"))
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: Binding(
                                        get: { audioService?.isSoundEffectsEnabled ?? true },
                                        set: { newValue in
                                            audioService?.isSoundEffectsEnabled = newValue
                                            // Update current profile preferences
                                            if var profile = profileService?.activeProfile {
                                                profile.preferences.soundEnabled = newValue
                                                profileService?.updatePreferences(profile.preferences, for: profile.id)
                                            }
                                        }
                                    ))
                                    .labelsHidden()
                                }
                                .padding(.horizontal, BemoTheme.Spacing.medium)
                                .padding(.vertical, BemoTheme.Spacing.small)
                                
                                Divider()
                                    .padding(.leading, 48)
                                
                                // Background Music Toggle
                                HStack {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 18))
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    
                                    Text("Background Music")
                                        .font(.system(size: 15, design: .rounded))
                                        .foregroundColor(Color("AppPrimaryTextColor"))
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: Binding(
                                        get: { audioService?.isBackgroundMusicEnabled ?? true },
                                        set: { newValue in
                                            audioService?.isBackgroundMusicEnabled = newValue
                                            // Update current profile preferences
                                            if var profile = profileService?.activeProfile {
                                                profile.preferences.musicEnabled = newValue
                                                profileService?.updatePreferences(profile.preferences, for: profile.id)
                                            }
                                        }
                                    ))
                                    .labelsHidden()
                                }
                                .padding(.horizontal, BemoTheme.Spacing.medium)
                                .padding(.vertical, BemoTheme.Spacing.small)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                                    .fill(Color.gray.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                                            .stroke(Color.gray.opacity(0.08), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, BemoTheme.Spacing.medium)
                    
                    Spacer()
                    
                    // Footer note
                    VStack(alignment: .leading, spacing: BemoTheme.Spacing.small) {
                        HStack(spacing: BemoTheme.Spacing.xsmall) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.gray)
                            
                            Text("For parents only")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(Color("AppPrimaryTextColor").opacity(0.6))
                        }
                        
                        Text("Access parental controls and view your children's learning progress")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(Color("AppPrimaryTextColor").opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, BemoTheme.Spacing.large)
                    .padding(.bottom, BemoTheme.Spacing.xlarge)
                }
            }
            .navigationBarHidden(true)
        }
        .overlay(alignment: .topTrailing) {
            // Close button
            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(Color("AppPrimaryTextColor").opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.gray.opacity(0.08))
                    )
            }
            .padding(.top, 60)
            .padding(.trailing, BemoTheme.Spacing.large)
        }
    }
}

// MARK: - Menu Item Component

struct MenuItemView: View {
    let icon: String
    let title: String
    let description: String
    let iconColor: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: BemoTheme.Spacing.medium) {
                // Icon container
                ZStack {
                    RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(Color("AppPrimaryTextColor"))
                    
                    Text(description)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(Color("AppPrimaryTextColor").opacity(0.6))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color("AppPrimaryTextColor").opacity(0.4))
            }
            .padding(BemoTheme.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.large)
                    .fill(Color.gray.opacity(isPressed ? 0.08 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.large)
                            .stroke(Color.gray.opacity(0.08), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity) { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isPressed = pressing
            }
        } perform: {
            action()
        }
    }
}

// MARK: - Preview

#Preview {
    SideMenuView(
        isPresented: .constant(true),
        onParentDashboardTapped: {
            print("Parent Dashboard tapped")
        },
        audioService: nil,
        profileService: nil
    )
}