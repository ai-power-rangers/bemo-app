//
//  ToastService.swift
//  Bemo
//
//  Service for managing toast notifications
//

// WHAT: Manages the display queue and lifecycle of toast notifications
// ARCHITECTURE: Service layer in MVVM-S pattern, manages toast state
// USAGE: Injected into ViewModel via DependencyContainer, call show() to display toasts

import Foundation
import Observation

@Observable
@MainActor
class ToastService {
    
    // MARK: - Published Properties
    
    var currentToast: ToastMessage?
    private var toastQueue: [ToastMessage] = []
    private var dismissTask: Task<Void, Never>?
    
    // MARK: - Public Methods
    
    /// Show a toast message with specified severity
    func show(_ message: String, severity: ToastMessage.Severity = .info) {
        let toast: ToastMessage
        
        switch severity {
        case .error:
            toast = .error(message)
        case .warning:
            toast = .warning(message)
        case .info:
            toast = .info(message)
        case .success:
            toast = .success(message)
        }
        
        enqueueToast(toast)
    }
    
    /// Show a pre-configured toast message
    func show(_ toast: ToastMessage) {
        enqueueToast(toast)
    }
    
    /// Dismiss the current toast immediately
    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        currentToast = nil
        processQueue()
    }
    
    /// Clear all toasts including queued ones
    func clearAll() {
        dismissTask?.cancel()
        dismissTask = nil
        currentToast = nil
        toastQueue.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func enqueueToast(_ toast: ToastMessage) {
        // If no current toast, show immediately
        if currentToast == nil {
            showToast(toast)
        } else {
            // Otherwise, add to queue
            toastQueue.append(toast)
        }
    }
    
    private func showToast(_ toast: ToastMessage) {
        currentToast = toast
        
        // Cancel any existing dismiss task
        dismissTask?.cancel()
        
        // Schedule auto-dismiss
        dismissTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(toast.duration * 1_000_000_000))
                
                // Only dismiss if this is still the current toast
                if self.currentToast?.id == toast.id {
                    self.currentToast = nil
                    self.processQueue()
                }
            } catch {
                // Task was cancelled, do nothing
            }
        }
    }
    
    private func processQueue() {
        // Show next toast in queue if available
        if !toastQueue.isEmpty {
            let nextToast = toastQueue.removeFirst()
            showToast(nextToast)
        }
    }
    
    // MARK: - Convenience Methods
    
    func showError(_ message: String) {
        show(message, severity: .error)
    }
    
    func showWarning(_ message: String) {
        show(message, severity: .warning)
    }
    
    func showInfo(_ message: String) {
        show(message, severity: .info)
    }
    
    func showSuccess(_ message: String) {
        show(message, severity: .success)
    }
    
    // MARK: - Error Handling
    
    func show(error: TangramEditorError) {
        showError(error.userMessage)
    }
}