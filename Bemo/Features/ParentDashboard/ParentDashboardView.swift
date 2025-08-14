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
            List {
                // Children profiles section
                Section(header: Text("Children")) {
                    ForEach(viewModel.childProfiles) { child in
                        ChildProfileRow(
                            profile: child,
                            onSelect: {
                                viewModel.selectChild(child)
                            },
                            onEdit: {
                                // Find the UserProfile for editing
                                if let userProfile = viewModel.getUserProfile(for: child) {
                                    profileToEdit = userProfile
                                }
                            }
                        )
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let child = viewModel.childProfiles[index]
                            viewModel.deleteChild(child)
                        }
                    }
                    
                    Button(action: {
                        viewModel.addChild()
                    }) {
                        Label("Add Child", systemImage: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                // Selected child details
                if let selectedChild = viewModel.selectedChild {
                    Section(header: Text("\(selectedChild.name)'s Progress")) {
                        // Progress overview
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Level")
                                Spacer()
                                Text("\(selectedChild.level)")
                                    .fontWeight(.bold)
                            }
                            
                            HStack {
                                Text("Total XP")
                                Spacer()
                                Text("\(selectedChild.totalXP)")
                                    .fontWeight(.bold)
                            }
                            
                            HStack {
                                Text("Play Time Today")
                                Spacer()
                                Text(viewModel.formattedPlayTime(selectedChild.playTimeToday))
                                    .fontWeight(.bold)
                            }
                        }
                        
                        // Recent achievements
                        if !selectedChild.recentAchievements.isEmpty {
                            VStack(alignment: .leading) {
                                Text("Recent Achievements")
                                    .font(.headline)
                                    .padding(.top)
                                
                                ForEach(selectedChild.recentAchievements) { achievement in
                                    HStack {
                                        Image(systemName: achievement.iconName)
                                            .foregroundColor(.yellow)
                                        Text(achievement.name)
                                        Spacer()
                                        Text(achievement.date, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Learning insights
                    Section(header: Text("Learning Insights")) {
                        NavigationLink(destination: Text("Detailed Analytics")) {
                            Label("View Detailed Report", systemImage: "chart.line.uptrend.xyaxis")
                        }
                        
                        ForEach(viewModel.insights) { insight in
                            InsightRow(insight: insight)
                        }
                    }

                    // Current skills (Tangram)
                    Section(header: Text("Current Skills (Tangram)")) {
                        if viewModel.skills.isEmpty {
                            Text("No skill data yet")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(viewModel.skills) { skill in
                                HStack(alignment: .center) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(skill.displayName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text("Mastery: \(skill.masteryState)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("Lvl \(skill.level)")
                                            .fontWeight(.bold)
                                        Text("\(skill.xpTotal) XP")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
                
                // Settings section
                Section(header: Text("Settings")) {
                    NavigationLink(destination: Text("Screen Time Settings")) {
                        Label("Screen Time Limits", systemImage: "timer")
                    }
                    
                    NavigationLink(destination: Text("Content Settings")) {
                        Label("Content Preferences", systemImage: "slider.horizontal.3")
                    }
                    
                    NavigationLink(destination: Text("Account Settings")) {
                        Label("Account", systemImage: "person.circle")
                    }
                    
                    Button(action: {
                        viewModel.signOut()
                    }) {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
                
                // User info section
                if let user = viewModel.authenticatedUser {
                    Section(header: Text("Account")) {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                if let fullName = user.fullName {
                                    Text("\(fullName.givenName ?? "") \(fullName.familyName ?? "")")
                                        .font(.headline)
                                } else {
                                    Text("Parent Account")
                                        .font(.headline)
                                }
                                
                                if let email = user.email {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Parent Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        viewModel.dismiss()
                    }
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

struct ChildProfileRow: View {
    let profile: ParentDashboardViewModel.ChildProfile
    let onSelect: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onSelect) {
                HStack {
                    // Avatar
                    if let avatarSymbol = profile.avatarSymbol,
                       let avatarColor = profile.avatarColor {
                        AvatarView(
                            symbol: avatarSymbol,
                            colorName: avatarColor,
                            size: 44
                        )
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(.headline)
                        Text("Level \(profile.level) • \(profile.totalXP) XP")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if profile.isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Edit button
            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct InsightRow: View {
    let insight: ParentDashboardViewModel.Insight
    
    var body: some View {
        HStack {
            Image(systemName: insight.iconName)
                .foregroundColor(insight.color)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}