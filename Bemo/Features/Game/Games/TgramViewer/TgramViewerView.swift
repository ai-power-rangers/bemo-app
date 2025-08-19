//
//  TgramViewerView.swift
//  Bemo
//
//  Main view for the TgramViewer game
//

// WHAT: Primary view for TgramViewer, displays front camera feed and frustration detection
// ARCHITECTURE: View in MVVM-S pattern, observes TgramViewerViewModel
// USAGE: Created by TgramViewerGame.makeGameView, shows camera feed and frustration status

import SwiftUI
import AVFoundation
import RealityKit

struct TgramViewerView: View {
    @State private var viewModel: TgramViewerViewModel
    
    init(viewModel: TgramViewerViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color("AppBackground")
                    .ignoresSafeArea()
                
                if let error = viewModel.errorMessage {
                    // Error state
                    VStack(spacing: BemoTheme.Spacing.medium) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(BemoTheme.Colors.primary)
                        
                        Text("Error")
                            .font(BemoTheme.font(for: .heading2))
                            .foregroundColor(BemoTheme.Colors.primary)
                        
                        Text(error)
                            .font(BemoTheme.font(for: .body))
                            .foregroundColor(BemoTheme.Colors.gray2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, BemoTheme.Spacing.large)
                        
                        Button(action: {
                            viewModel.reset()
                            viewModel.startSession()
                        }) {
                            Text("Retry")
                                .foregroundColor(.white)
                                .padding(.horizontal, BemoTheme.Spacing.large)
                                .padding(.vertical, BemoTheme.Spacing.small)
                                .background(BemoTheme.Colors.primary)
                                .cornerRadius(BemoTheme.CornerRadius.medium)
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        // Top half: Camera preview
                        GeometryReader { geometry in
                            if let arView = viewModel.arView {
                                ARViewContainer(arView: arView)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .cornerRadius(BemoTheme.CornerRadius.large)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.large)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                    )
                            } else {
                                // Placeholder while camera loads
                                ZStack {
                                    Color.black.opacity(0.8)
                                    VStack {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 50))
                                            .foregroundColor(.white.opacity(0.6))
                                        Text("AR initializing...")
                                            .font(BemoTheme.font(for: .body))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                                .cornerRadius(BemoTheme.CornerRadius.large)
                            }
                            
                            // Status overlay
                            if viewModel.isSessionActive {
                                VStack {
                                    HStack {
                                        Label("Face Tracking Active", systemImage: "face.smiling")
                                            .font(BemoTheme.font(for: .caption))
                                            .padding(8)
                                            .background(Color.green.opacity(0.8))
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                        
                                        Spacer()
                                    }
                                    Spacer()
                                }
                                .padding()
                            }
                        }
                        .frame(maxHeight: .infinity)
                        .padding(BemoTheme.Spacing.medium)
                        
                        // Bottom half: Frustration status
                        VStack(spacing: BemoTheme.Spacing.medium) {
                            // Main frustration indicator
                            ZStack {
                                RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.large)
                                    .fill(viewModel.isFrustrated ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.large)
                                            .stroke(viewModel.isFrustrated ? Color.red : Color.green, lineWidth: 3)
                                    )
                                
                                VStack(spacing: BemoTheme.Spacing.small) {
                                    Image(systemName: viewModel.isFrustrated ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(viewModel.isFrustrated ? Color.red : Color.green)
                                    
                                    Text(viewModel.isFrustrated ? "Frustrated" : "Not Frustrated")
                                        .font(BemoTheme.font(for: .heading1))
                                        .foregroundColor(viewModel.isFrustrated ? Color.red : Color.green)
                                    
                                    Text(String(format: "Score: %.2f", viewModel.frustrationScore))
                                        .font(BemoTheme.font(for: .body))
                                        .foregroundColor(BemoTheme.Colors.gray2)
                                }
                                .padding()
                            }
                            .frame(height: 200)
                            
                            // Debug information
                            Text(viewModel.debugInfo)
                                .font(BemoTheme.font(for: .caption))
                                .foregroundColor(BemoTheme.Colors.gray2)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxHeight: .infinity)
                        .padding(BemoTheme.Spacing.medium)
                    }
                }
            }
            .navigationTitle("Frustration Detector")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        if viewModel.isSessionActive {
                            viewModel.stopSession()
                        } else {
                            viewModel.startSession()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.isSessionActive ? "stop.fill" : "play.fill")
                            Text(viewModel.isSessionActive ? "Stop" : "Start")
                        }
                        .foregroundColor(viewModel.isSessionActive ? .red : .green)
                    }
                    .font(BemoTheme.font(for: .body))
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: viewModel.quit) {
                        Text("Done")
                            .foregroundColor(BemoTheme.Colors.primary)
                    }
                    .font(BemoTheme.font(for: .body))
                }
            }
        }
        .onAppear {
            // Configure navigation bar appearance
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color("AppBackground"))
            appearance.titleTextAttributes = [.foregroundColor: UIColor(Color("AppPrimaryTextColor"))]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color("AppPrimaryTextColor"))]
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            
            // Start face tracking session automatically
            viewModel.startSession()
        }
        .onDisappear {
            // Clean up when view disappears
            viewModel.reset()
        }
    }
}
