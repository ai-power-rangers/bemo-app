//
//  HeaderView.swift
//  Bemo
//
//  Navigation header with hamburger menu and profile badge
//

// WHAT: Header component with hamburger menu button and user profile badge
// ARCHITECTURE: UI component used in GameLobbyView for navigation
// USAGE: HeaderView(profileName: "Alice", onMenuTapped: { })

import SwiftUI

struct HeaderView: View {
    let profileName: String?
    let profileAvatar: String?
    let onMenuTapped: () -> Void
    
    init(
        profileName: String? = nil,
        profileAvatar: String? = nil,
        onMenuTapped: @escaping () -> Void
    ) {
        self.profileName = profileName
        self.profileAvatar = profileAvatar
        self.onMenuTapped = onMenuTapped
    }
    
    var body: some View {
        HStack {
            // Hamburger Menu Button
            Button(action: onMenuTapped) {
                Image(systemName: "line.horizontal.3")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(BemoTheme.Colors.gray1)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            
            Spacer()
            
            // Profile Badge
            ProfileBadgeView(
                name: profileName,
                avatar: profileAvatar
            )
        }
        .padding(.horizontal, BemoTheme.Spacing.large)
        .padding(.vertical, BemoTheme.Spacing.medium)
        .background(Color.clear)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        HeaderView(
            profileName: "Alice",
            onMenuTapped: {
                print("Menu tapped")
            }
        )
        
        Spacer()
    }
    .background(BemoTheme.Colors.background)
}