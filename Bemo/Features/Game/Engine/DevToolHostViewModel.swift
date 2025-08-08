//
//  DevToolHostViewModel.swift
//  Bemo
//
//  ViewModel that manages the dev tool session and connects services to the dev tool
//

// WHAT: Manages active dev tool lifecycle. Implements DevToolDelegate, manages notifications and state. NO CV, NO session tracking, NO child profiles.
// ARCHITECTURE: Central dev tool coordinator in MVVM-S. Bridges services with dev tool logic. Implements DevToolDelegate for callbacks.
// USAGE: Created with a DevTool instance and required services. Handle delegate callbacks for quit, save, notifications.

import SwiftUI
import Combine
import Observation

@Observable
class DevToolHostViewModel {
    var devToolView: AnyView = AnyView(EmptyView())
    var showError = false
    var errorMessage = ""
    var progress: Float = 0.0
    var showProgress = false
    var showNotification = false
    var notificationMessage = ""
    var notificationType: NotificationType = .info
    
    let devTool: DevTool
    private let supabaseService: SupabaseService  // Uses service role for dev tools
    private let errorTrackingService: ErrorTrackingService?
    private let onQuit: () -> Void
    
    init(
        devTool: DevTool,
        supabaseService: SupabaseService,  // This should be the service role version
        errorTrackingService: ErrorTrackingService? = nil,
        onQuit: @escaping () -> Void
    ) {
        self.devTool = devTool
        self.supabaseService = supabaseService
        self.errorTrackingService = errorTrackingService
        self.onQuit = onQuit
        
        // Defer dev tool view creation until after initialization
        defer {
            self.devToolView = devTool.makeDevToolView(delegate: self)
        }
    }
    
    func startSession() {
        // Start dev tool session - no CV service, no game sessions
        devTool.reset()
        print("Dev tool session started: \(devTool.id)")
    }
    
    func endSession() {
        // Save dev tool state if needed
        if let _ = devTool.saveState() {
            // TODO: Persist dev tool state if needed
            print("Dev tool state saved")
        }
        
        print("Dev tool session ended: \(devTool.id)")
    }
    
    func handleQuitRequest() {
        devToolDidRequestQuit()
    }
    
    func handleSaveRequest() {
        // Trigger save through dev tool if it supports it
        // Dev tools can implement their own save logic and call devToolDidSaveSuccessfully
        print("Save requested for dev tool: \(devTool.id)")
    }
    
    private func showNotificationToast(message: String, type: NotificationType) {
        notificationMessage = message
        notificationType = type
        showNotification = true
        
        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.showNotification = false
        }
    }
}

// MARK: - DevToolDelegate Implementation
extension DevToolHostViewModel: DevToolDelegate {
    func devToolDidRequestQuit() {
        print("Dev tool requested quit: \(devTool.id)")
        onQuit()
    }
    
    func devToolDidEncounterError(_ error: Error) {
        print("Dev tool error: \(error.localizedDescription)")
        
        errorMessage = error.localizedDescription
        showError = true
        
        // Track error for debugging
        errorTrackingService?.trackError(error, context: ErrorContext(
            feature: "DevToolHost",
            action: "devToolError",
            metadata: [
                "devToolId": devTool.id,
                "devToolTitle": devTool.title
            ]
        ))
    }
    
    func devToolDidUpdateProgress(_ progress: Float) {
        self.progress = progress
        self.showProgress = progress > 0.0 && progress < 1.0
    }
    
    func devToolDidSaveSuccessfully(message: String?) {
        let successMessage = message ?? "Saved successfully"
        showNotificationToast(message: successMessage, type: .success)
        print("Dev tool save successful: \(devTool.id)")
    }
    
    func devToolDidShowNotification(message: String, type: NotificationType) {
        showNotificationToast(message: message, type: type)
    }
}