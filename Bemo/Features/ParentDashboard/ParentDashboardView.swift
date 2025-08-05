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
    @StateObject var viewModel: ParentDashboardViewModel
    
    var body: some View {
        NavigationView {
            List {
                // Children profiles section
                Section(header: Text("Children")) {
                    ForEach(viewModel.childProfiles) { child in
                        ChildProfileRow(profile: child) {
                            viewModel.selectChild(child)
                        }
                    }
                    
                    Button(action: {
                        viewModel.showAddChildSheet = true
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
        }
        .sheet(isPresented: $viewModel.showAddChildSheet) {
            Text("Add Child Profile")
                // In a real app, this would be a form to add a new child
        }
    }
}

struct ChildProfileRow: View {
    let profile: ParentDashboardViewModel.ChildProfile
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
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