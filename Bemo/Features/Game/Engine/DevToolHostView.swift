//
//  DevToolHostView.swift
//  Bemo
//
//  SwiftUI view that hosts the active dev tool's view
//

// WHAT: Container view that displays the active dev tool's UI. Provides common overlay controls (quit, save, progress, notifications) for all dev tools.
// ARCHITECTURE: View layer of dev tool hosting in MVVM-S. Displays dev tool view from ViewModel and handles common UI elements.
// USAGE: Created by AppCoordinator with DevToolHostViewModel. The devToolView property displays the active dev tool's content.

import SwiftUI

struct DevToolHostView: View {
    @State var viewModel: DevToolHostViewModel
    
    var body: some View {
        let config = viewModel.devTool.devToolUIConfig
        
        ZStack {
            // Background color if specified
            if let backgroundColor = config.backgroundColor {
                backgroundColor.ignoresSafeArea()
            }
            
            // Dev tool content with conditional safe area handling
            Group {
                if config.respectsSafeAreas {
                    viewModel.devToolView
                } else {
                    viewModel.devToolView
                        .ignoresSafeArea()
                }
            }
            
            // Overlay UI elements - only if we have something to show
            if config.showQuitButton || (config.showProgressBar && viewModel.showProgress) || config.showSaveButton || config.customTopBar != nil || config.customBottomBar != nil {
                VStack {
                    // Top bar (quit button, progress, save button)
                    HStack {
                        // Quit button (if enabled)
                        if config.showQuitButton {
                            Button(action: {
                                viewModel.handleQuitRequest()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            .padding()
                        }
                        
                        Spacer()
                        
                        // Progress indicator (if enabled and showing)
                        if config.showProgressBar && viewModel.showProgress {
                            ProgressView(value: viewModel.progress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(width: 200)
                                .padding()
                        }
                        
                        Spacer()
                        
                        // Save button (if enabled)
                        if config.showSaveButton {
                            Button(action: {
                                viewModel.handleSaveRequest()
                            }) {
                                Image(systemName: "square.and.arrow.down.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                                    .background(Color.blue.opacity(0.8))
                                    .clipShape(Circle())
                            }
                            .padding()
                        }
                    }
                    
                    // Custom top bar if provided
                    if let customTopBar = config.customTopBar {
                        customTopBar
                    }
                    
                    Spacer()
                    
                    // Custom bottom bar if provided
                    if let customBottomBar = config.customBottomBar {
                        customBottomBar
                    }
                }
                .allowsHitTesting(true)
            }
            
            // Notification toast overlay
            if viewModel.showNotification {
                VStack {
                    HStack {
                        Spacer()
                        
                        NotificationToastView(
                            message: viewModel.notificationMessage,
                            type: viewModel.notificationType
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: viewModel.showNotification)
                        
                        Spacer()
                    }
                    .padding(.top, 60) // Below top bar
                    
                    Spacer()
                }
            }
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.endSession()
        }
    }
}

// MARK: - Supporting Views
struct NotificationToastView: View {
    let message: String
    let type: NotificationType
    
    private var backgroundColor: Color {
        switch type {
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        case .info:
            return .blue
        }
    }
    
    private var iconName: String {
        switch type {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(.white)
            
            Text(message)
                .foregroundColor(.white)
                .font(.body)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .cornerRadius(8)
        .shadow(radius: 4)
    }
}