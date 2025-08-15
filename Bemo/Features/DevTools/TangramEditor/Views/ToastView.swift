//
//  ToastView.swift
//  Bemo
//
//  View for displaying toast notifications
//

// WHAT: SwiftUI view that displays toast notifications with animations
// ARCHITECTURE: View layer in MVVM-S pattern, observes ToastService
// USAGE: Add as overlay to main content view, automatically displays toasts from service

import SwiftUI

struct ToastView: View {
    @Bindable var toastService: ToastService
    
    var body: some View {
        VStack {
            if let toast = toastService.currentToast {
                ToastMessageView(toast: toast) {
                    toastService.dismiss()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: toastService.currentToast)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(toastService.currentToast != nil)
    }
}

struct ToastMessageView: View {
    let toast: ToastMessage
    let onDismiss: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: toast.severity.iconName)
                .font(.title3)
                .foregroundColor(Color(toast.severity.color))
            
            // Message
            Text(toast.text)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 8)
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(4)
                    .background(Circle().fill(Color.gray.opacity(0.2)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundView)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
        .padding(.top, 50)  // Account for status bar
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 12)
                .fill(TangramTheme.Backgrounds.panel)
            
            // Severity indicator stripe
            HStack {
                Rectangle()
                    .fill(Color(toast.severity.color).opacity(0.8))
                    .frame(width: 4)
                Spacer()
            }
        }
    }
}

// MARK: - Modifier Extension

extension View {
    func toastOverlay(toastService: ToastService) -> some View {
        self.overlay(
            ToastView(toastService: toastService)
                .allowsHitTesting(toastService.currentToast != nil)
        )
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Text("Main Content")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.gray.opacity(0.1))
    .toastOverlay(toastService: {
        let service = ToastService()
        service.show("This is a test toast message", severity: .success)
        return service
    }())
}