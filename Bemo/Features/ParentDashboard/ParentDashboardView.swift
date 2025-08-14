//
//  ParentDashboardView.swift
//  Bemo
//
//  Parent-facing dashboard for monitoring child progress and settings
//

// WHAT: Parent control panel showing child profiles, progress metrics, achievements, and app settings. Analytics and management hub.
// ARCHITECTURE: View layer for parent features in MVVM-S. Displays child data and settings from ParentDashboardViewModel.
// USAGE: Accessed from GameLobby via parent button. Shows list of children, selected child's progress, insights, and settings.

import SwiftUI

struct ParentDashboardView: View {
    @State var viewModel: ParentDashboardViewModel
    @State private var profileToEdit: UserProfile?
    
    var body: some View {
        NavigationView {
            ZStack {
                // App background color from assets
                Color("AppBackground")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Header section with account info
                        if let user = viewModel.authenticatedUser {
                            VStack(spacing: BemoTheme.Spacing.medium) {
                                HStack {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 44))
                                        .foregroundColor(BemoTheme.Colors.primary)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        if let fullName = user.fullName {
                                            Text("\(fullName.givenName ?? "") \(fullName.familyName ?? "")")
                                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                                .foregroundColor(Color("AppPrimaryTextColor"))
                                        } else {
                                            Text("Parent Account")
                                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                                .foregroundColor(Color("AppPrimaryTextColor"))
                                        }
                                        
                                        if let email = user.email {
                                            Text(email)
                                                .font(.system(size: 14, design: .rounded))
                                                .foregroundColor(Color("AppPrimaryTextColor").opacity(0.6))
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, BemoTheme.Spacing.large)
                                .padding(.top, BemoTheme.Spacing.large)
                                .padding(.bottom, BemoTheme.Spacing.medium)
                            }
                        }
                        
                        // Children profiles section
                        VStack(alignment: .leading, spacing: BemoTheme.Spacing.medium) {
                            Text("Children")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(Color("AppPrimaryTextColor"))
                                .padding(.horizontal, BemoTheme.Spacing.large)
                                .padding(.top, BemoTheme.Spacing.medium)
                            
                            VStack(spacing: BemoTheme.Spacing.small) {
                                ForEach(viewModel.childProfiles) { child in
                                    ChildProfileCard(
                                        profile: child,
                                        onSelect: {
                                            viewModel.selectChild(child)
                                        },
                                        onEdit: {
                                            if let userProfile = viewModel.getUserProfile(for: child) {
                                                profileToEdit = userProfile
                                            }
                                        }
                                    )
                                }
                                
                                // Add child button
                                Button(action: {
                                    viewModel.addChild()
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(BemoTheme.Colors.primary)
                                        
                                        Text("Add Child")
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(BemoTheme.Colors.primary)
                                        
                                        Spacer()
                                    }
                                    .padding(BemoTheme.Spacing.medium)
                                    .background(
                                        RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.large)
                                            .fill(BemoTheme.Colors.primary.opacity(0.08))
                                    )
                                }
                                .padding(.horizontal, BemoTheme.Spacing.large)
                            }
                        }
                        
                        // Selected child details
                        if let selectedChild = viewModel.selectedChild {
                            VStack(alignment: .leading, spacing: BemoTheme.Spacing.large) {
                                // Progress section
                                VStack(alignment: .leading, spacing: BemoTheme.Spacing.medium) {
                                    Text("\(selectedChild.name)'s Progress")
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .foregroundColor(Color("AppPrimaryTextColor"))
                                        .padding(.horizontal, BemoTheme.Spacing.large)
                                        .padding(.top, BemoTheme.Spacing.xlarge)
                                    
                                    // Progress cards
                                    HStack(spacing: BemoTheme.Spacing.medium) {
                                        ProgressCard(
                                            title: "Level",
                                            value: "\(selectedChild.level)",
                                            icon: "star.fill",
                                            color: Color(hex: "#F97316")
                                        )
                                        
                                        ProgressCard(
                                            title: "Total XP",
                                            value: "\(selectedChild.totalXP)",
                                            icon: "bolt.fill",
                                            color: Color(hex: "#3B82F6")
                                        )
                                    }
                                    .padding(.horizontal, BemoTheme.Spacing.large)
                                    
                                    // Play time card
                                    VStack(alignment: .leading, spacing: BemoTheme.Spacing.small) {
                                        HStack {
                                            Image(systemName: "clock.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(Color(hex: "#10B981"))
                                            
                                            Text("Play Time Today")
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundColor(Color("AppPrimaryTextColor").opacity(0.7))
                                            
                                            Spacer()
                                            
                                            Text(viewModel.formattedPlayTime(selectedChild.playTimeToday))
                                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                                .foregroundColor(Color("AppPrimaryTextColor"))
                                        }
                                        .padding(BemoTheme.Spacing.medium)
                                        .background(
                                            RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                                                .fill(Color(hex: "#10B981").opacity(0.08))
                                        )
                                    }
                                    .padding(.horizontal, BemoTheme.Spacing.large)
                                }
                                
                                // Skills section
                                if !viewModel.skills.isEmpty {
                                    VStack(alignment: .leading, spacing: BemoTheme.Spacing.medium) {
                                        Text("Current Skills (Tangram)")
                                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                                            .foregroundColor(Color("AppPrimaryTextColor"))
                                            .padding(.horizontal, BemoTheme.Spacing.large)
                                        
                                        VStack(spacing: BemoTheme.Spacing.small) {
                                            ForEach(viewModel.skills) { skill in
                                                SkillRow(skill: skill)
                                            }
                                        }
                                        .padding(.horizontal, BemoTheme.Spacing.large)
                                    }
                                }
                                
                                // Recent achievements
                                if !selectedChild.recentAchievements.isEmpty {
                                    VStack(alignment: .leading, spacing: BemoTheme.Spacing.medium) {
                                        Text("Recent Achievements")
                                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                                            .foregroundColor(Color("AppPrimaryTextColor"))
                                            .padding(.horizontal, BemoTheme.Spacing.large)
                                        
                                        VStack(spacing: BemoTheme.Spacing.small) {
                                            ForEach(selectedChild.recentAchievements) { achievement in
                                                HStack {
                                                    Image(systemName: achievement.iconName)
                                                        .font(.system(size: 18))
                                                        .foregroundColor(Color(hex: "#F97316"))
                                                    
                                                    Text(achievement.name)
                                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                                        .foregroundColor(Color("AppPrimaryTextColor").opacity(0.85))
                                                    
                                                    Spacer()
                                                    
                                                    Text(achievement.date, style: .date)
                                                        .font(.system(size: 13, design: .rounded))
                                                        .foregroundColor(Color("AppPrimaryTextColor").opacity(0.6))
                                                }
                                                .padding(BemoTheme.Spacing.medium)
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
                                        .padding(.horizontal, BemoTheme.Spacing.large)
                                    }
                                }
                                
                                // Insights section
                                if !viewModel.insights.isEmpty {
                                    VStack(alignment: .leading, spacing: BemoTheme.Spacing.medium) {
                                        Text("Learning Insights")
                                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                                            .foregroundColor(Color("AppPrimaryTextColor"))
                                            .padding(.horizontal, BemoTheme.Spacing.large)
                                        
                                        VStack(spacing: BemoTheme.Spacing.small) {
                                            ForEach(viewModel.insights) { insight in
                                                InsightCard(insight: insight)
                                            }
                                        }
                                        .padding(.horizontal, BemoTheme.Spacing.large)
                                    }
                                }
                            }
                        }
                        
                        // Settings section
                        VStack(alignment: .leading, spacing: BemoTheme.Spacing.medium) {
                            Text("Settings")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(Color("AppPrimaryTextColor"))
                                .padding(.horizontal, BemoTheme.Spacing.large)
                                .padding(.top, BemoTheme.Spacing.xlarge)
                            
                            VStack(spacing: BemoTheme.Spacing.small) {
                                SettingsRow(
                                    icon: "timer",
                                    title: "Screen Time Limits",
                                    action: {
                                        // Navigate to screen time settings
                                    }
                                )
                                
                                SettingsRow(
                                    icon: "slider.horizontal.3",
                                    title: "Content Preferences",
                                    action: {
                                        // Navigate to content settings
                                    }
                                )
                                
                                SettingsRow(
                                    icon: "person.circle",
                                    title: "Account",
                                    action: {
                                        // Navigate to account settings
                                    }
                                )
                                
                                Button(action: {
                                    viewModel.signOut()
                                }) {
                                    HStack {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .font(.system(size: 18))
                                            .foregroundColor(.red)
                                        
                                        Text("Sign Out")
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(.red)
                                        
                                        Spacer()
                                    }
                                    .padding(BemoTheme.Spacing.medium)
                                    .background(
                                        RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                                            .fill(Color.red.opacity(0.08))
                                    )
                                }
                                .padding(.horizontal, BemoTheme.Spacing.large)
                            }
                        }
                        .padding(.bottom, BemoTheme.Spacing.xxlarge)
                    }
                }
            }
            .navigationTitle("Parent Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        viewModel.dismiss()
                    }
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(BemoTheme.Colors.primary)
                }
            }
            .sheet(item: $profileToEdit) { profile in
                ChildProfileEditView(
                    profile: profile,
                    profileService: viewModel.getProfileService,
                    onSave: { updatedProfile in
                        viewModel.updateChildProfile(updatedProfile)
                    },
                    onDelete: {
                        viewModel.deleteChildProfile(profile.id)
                    }
                )
            }
        }
    }
}

// MARK: - Child Profile Card

struct ChildProfileCard: View {
    let profile: ParentDashboardViewModel.ChildProfile
    let onSelect: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: BemoTheme.Spacing.medium) {
                // Avatar
                if let avatarSymbol = profile.avatarSymbol,
                   let avatarColor = profile.avatarColor {
                    AvatarView(
                        symbol: avatarSymbol,
                        colorName: avatarColor,
                        size: 56
                    )
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(BemoTheme.Colors.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(Color("AppPrimaryTextColor"))
                    Text("Level \(profile.level) • \(profile.totalXP) XP")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(Color("AppPrimaryTextColor").opacity(0.6))
                }
                
                Spacer()
                
                if profile.isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#10B981"))
                }
                
                // Edit button
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(BemoTheme.Colors.primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(BemoTheme.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.large)
                    .fill(profile.isSelected ? BemoTheme.Colors.primary.opacity(0.08) : Color.gray.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.large)
                            .stroke(profile.isSelected ? BemoTheme.Colors.primary.opacity(0.2) : Color.gray.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, BemoTheme.Spacing.large)
    }
}

// MARK: - Progress Card

struct ProgressCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: BemoTheme.Spacing.small) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Color("AppPrimaryTextColor").opacity(0.7))
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color("AppPrimaryTextColor"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BemoTheme.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                .fill(color.opacity(0.08))
        )
    }
}

// MARK: - Skill Row

struct SkillRow: View {
    let skill: ParentDashboardViewModel.SkillStat
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(skill.displayName)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(Color("AppPrimaryTextColor").opacity(0.85))
                Text("Mastery: \(skill.masteryState)")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(Color("AppPrimaryTextColor").opacity(0.6))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Lvl \(skill.level)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(BemoTheme.Colors.primary)
                Text("\(skill.xpTotal) XP")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(Color("AppPrimaryTextColor").opacity(0.6))
            }
        }
        .padding(BemoTheme.Spacing.medium)
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

// MARK: - Insight Card

struct InsightCard: View {
    let insight: ParentDashboardViewModel.Insight
    
    var body: some View {
        HStack(spacing: BemoTheme.Spacing.medium) {
            Image(systemName: insight.iconName)
                .font(.system(size: 20))
                .foregroundColor(insight.color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(Color("AppPrimaryTextColor").opacity(0.85))
                Text(insight.description)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(Color("AppPrimaryTextColor").opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(BemoTheme.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                .fill(insight.color.opacity(0.08))
        )
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(BemoTheme.Colors.primary)
                    .frame(width: 28)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(Color("AppPrimaryTextColor").opacity(0.85))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color("AppPrimaryTextColor").opacity(0.4))
            }
            .padding(BemoTheme.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                    .fill(Color.gray.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                            .stroke(Color.gray.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, BemoTheme.Spacing.large)
    }
}