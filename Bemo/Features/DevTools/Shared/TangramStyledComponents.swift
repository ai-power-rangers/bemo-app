//
//  TangramStyledComponents.swift
//  Bemo
//
//  Reusable styled UI components for Tangram dev tools
//

// WHAT: Provides consistently styled UI components for dev tools using TangramTheme
// ARCHITECTURE: Shared UI layer components for MVVM-S Views
// USAGE: Use these components instead of raw SwiftUI views for consistent theming

import SwiftUI

// MARK: - Styled Button

/// A consistently styled button for dev tools
struct TangramButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let style: ButtonStyle
    let isEnabled: Bool
    
    enum ButtonStyle {
        case primary
        case secondary
        case destructive
        case tool
    }
    
    init(
        _ title: String,
        icon: String? = nil,
        style: ButtonStyle = .primary,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                }
                Text(title)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, BemoTheme.Spacing.medium)
            .padding(.vertical, BemoTheme.Spacing.small)
            .background(backgroundColor)
            .cornerRadius(BemoTheme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
    
    private var foregroundColor: Color {
        if !isEnabled { return TangramTheme.UI.disabled }
        switch style {
        case .primary:
            return TangramTheme.Text.onColor
        case .secondary:
            return TangramTheme.Text.primary
        case .destructive:
            return TangramTheme.Text.onColor
        case .tool:
            return TangramTheme.Text.primary
        }
    }
    
    private var backgroundColor: Color {
        if !isEnabled { return TangramTheme.UI.disabled.opacity(0.2) }
        switch style {
        case .primary:
            return TangramTheme.UI.primaryButton
        case .secondary:
            return Color.clear
        case .destructive:
            return TangramTheme.UI.destructive
        case .tool:
            return TangramTheme.UI.selection
        }
    }
    
    private var borderColor: Color {
        if !isEnabled { return TangramTheme.UI.disabled }
        switch style {
        case .primary:
            return Color.clear
        case .secondary:
            return TangramTheme.UI.primaryButton
        case .destructive:
            return Color.clear
        case .tool:
            return TangramTheme.UI.separator
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .secondary, .tool:
            return 1
        default:
            return 0
        }
    }
}

// MARK: - Styled Panel

/// A consistently styled panel container
struct TangramPanel<Content: View>: View {
    let title: String?
    let content: Content
    
    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = title {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(TangramTheme.Text.secondary)
                    .padding(.horizontal, BemoTheme.Spacing.medium)
                    .padding(.vertical, BemoTheme.Spacing.small)
                
                Divider()
                    .background(TangramTheme.UI.separator)
            }
            
            content
                .padding(BemoTheme.Spacing.medium)
        }
        .background(TangramTheme.Backgrounds.panel)
        .cornerRadius(BemoTheme.CornerRadius.large)
        .shadow(
            color: TangramTheme.Shadow.panel.color,
            radius: TangramTheme.Shadow.panel.radius,
            x: TangramTheme.Shadow.panel.x,
            y: TangramTheme.Shadow.panel.y
        )
    }
}

// MARK: - Styled Toolbar

/// A consistently styled toolbar
struct TangramToolbar<Content: View>: View {
    let content: Content
    let position: Position
    
    enum Position {
        case top
        case bottom
    }
    
    init(position: Position = .top, @ViewBuilder content: () -> Content) {
        self.position = position
        self.content = content()
    }
    
    var body: some View {
        HStack {
            content
        }
        .padding(.horizontal, BemoTheme.Spacing.medium)
        .padding(.vertical, BemoTheme.Spacing.small)
        .background(TangramTheme.Backgrounds.toolbar)
        .overlay(
            Rectangle()
                .fill(TangramTheme.UI.separator)
                .frame(height: 1),
            alignment: position == .top ? .bottom : .top
        )
    }
}

// MARK: - Styled Section Header

/// A consistently styled section header
struct TangramSectionHeader: View {
    let title: String
    let icon: String?
    
    init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(TangramTheme.Text.secondary)
            }
            
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(TangramTheme.Text.primary)
            
            Spacer()
        }
        .padding(.horizontal, BemoTheme.Spacing.medium)
        .padding(.vertical, BemoTheme.Spacing.small)
        .background(TangramTheme.Backgrounds.secondaryPanel)
    }
}

// MARK: - Styled Toggle

/// A consistently styled toggle switch
struct TangramToggle: View {
    let label: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(TangramTheme.Text.primary)
        }
        .tint(TangramTheme.UI.primaryButton)
    }
}

// MARK: - Styled Text Field

/// A consistently styled text field
struct TangramTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String?
    
    init(_ placeholder: String, text: Binding<String>, icon: String? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(TangramTheme.Text.secondary)
            }
            
            TextField(placeholder, text: $text)
                .font(.system(size: 15))
                .foregroundColor(TangramTheme.Text.primary)
        }
        .padding(.horizontal, BemoTheme.Spacing.small)
        .padding(.vertical, BemoTheme.Spacing.xsmall)
        .background(TangramTheme.Backgrounds.secondaryPanel)
        .cornerRadius(BemoTheme.CornerRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.small)
                .stroke(TangramTheme.UI.separator, lineWidth: 1)
        )
    }
}

// MARK: - Styled Picker

/// A consistently styled picker
struct TangramPicker<SelectionValue: Hashable, Content: View>: View {
    let selection: Binding<SelectionValue>
    let content: Content
    
    init(selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {
        self.selection = selection
        self.content = content()
    }
    
    var body: some View {
        Picker(selection: selection) {
            content
        } label: {
            EmptyView()
        }
        .pickerStyle(MenuPickerStyle())
        .tint(TangramTheme.UI.primaryButton)
        .foregroundColor(TangramTheme.Text.primary)
        .padding(.horizontal, BemoTheme.Spacing.small)
        .padding(.vertical, BemoTheme.Spacing.xsmall)
        .background(TangramTheme.Backgrounds.secondaryPanel)
        .cornerRadius(BemoTheme.CornerRadius.small)
    }
}

// MARK: - Status Indicator

/// A status indicator with consistent theming
struct TangramStatusIndicator: View {
    let status: Status
    let message: String?
    
    enum Status {
        case success
        case warning
        case error
        case info
        case neutral
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundColor(color)
            
            if let message = message {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(TangramTheme.Text.secondary)
            }
        }
        .padding(.horizontal, BemoTheme.Spacing.small)
        .padding(.vertical, BemoTheme.Spacing.xxsmall)
        .background(color.opacity(0.1))
        .cornerRadius(BemoTheme.CornerRadius.small)
    }
    
    private var iconName: String {
        switch status {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        case .info:
            return "info.circle.fill"
        case .neutral:
            return "circle.fill"
        }
    }
    
    private var color: Color {
        switch status {
        case .success:
            return TangramTheme.UI.success
        case .warning:
            return TangramTheme.UI.warning
        case .error:
            return TangramTheme.UI.destructive
        case .info:
            return TangramTheme.UI.info
        case .neutral:
            return TangramTheme.UI.disabled
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        TangramSectionHeader("Components Preview", icon: "paintbrush")
        
        HStack(spacing: 12) {
            TangramButton("Primary", icon: "play.fill", style: .primary) {}
            TangramButton("Secondary", style: .secondary) {}
            TangramButton("Delete", icon: "trash", style: .destructive) {}
        }
        
        TangramPanel(title: "Settings") {
            VStack(alignment: .leading, spacing: 12) {
                TangramToggle(label: "Enable Feature", isOn: .constant(true))
                TangramTextField("Enter name", text: .constant(""), icon: "pencil")
            }
        }
        
        HStack(spacing: 12) {
            TangramStatusIndicator(status: .success, message: "Valid")
            TangramStatusIndicator(status: .warning, message: "Check")
            TangramStatusIndicator(status: .error, message: "Error")
        }
        
        Spacer()
    }
    .padding()
    .background(TangramTheme.Backgrounds.editor)
}