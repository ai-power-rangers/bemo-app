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
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                // Single Menu Item - Parent Dashboard Only
                MenuItemView(
                    icon: "person.2.fill",
                    title: "Parent Dashboard",
                    action: onParentDashboardTapped
                )
                
                Spacer()
                
                // Subtle note for parents
                Text("For parents only")
                    .font(.caption)
                    .foregroundColor(BemoTheme.Colors.gray2)
                    .padding(.horizontal, BemoTheme.Spacing.large)
                    .padding(.bottom, BemoTheme.Spacing.large)
            }
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(BemoTheme.Colors.primary)
                }
            }
        }
    }
}

// MARK: - Menu Item Component

struct MenuItemView: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: BemoTheme.Spacing.medium) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(BemoTheme.Colors.primary)
                    .frame(width: 30)
                
                Text(title)
                    .font(BemoTheme.font(for: .body))
                    .foregroundColor(BemoTheme.Colors.gray1)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(BemoTheme.Colors.gray2)
            }
            .padding(.horizontal, BemoTheme.Spacing.large)
            .padding(.vertical, BemoTheme.Spacing.medium)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    SideMenuView(
        isPresented: .constant(true),
        onParentDashboardTapped: {
            print("Parent Dashboard tapped")
        }
    )
}