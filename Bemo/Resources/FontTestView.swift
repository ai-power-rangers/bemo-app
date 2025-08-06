//
//  FontTestView.swift
//  Bemo
//
//  Temporary view for testing custom font loading
//

// WHAT: Debug view to test custom font loading and display available fonts
// ARCHITECTURE: Temporary utility view for font verification
// USAGE: Add this view temporarily to test fonts, then remove when fonts are working

import SwiftUI

struct FontTestView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Font Test View")
                    .font(.largeTitle)
                    .padding()
                
                // Test Bemo Theme Fonts
                Group {
                    Text("Heading 1 - Should use Sink")
                        .font(BemoTheme.font(for: .heading1))
                    
                    Text("Heading 2 - Should use Sink")
                        .font(BemoTheme.font(for: .heading2))
                    
                    Text("Body text - Should use Roxstar")
                        .font(BemoTheme.font(for: .body))
                    
                    Text("Caption text - Should use Roxstar")
                        .font(BemoTheme.font(for: .caption))
                }
                
                Divider()
                
                // Test Direct Font Loading
                Group {
                    Text("Direct Sink Test")
                        .font(.custom("Sink", size: 20))
                    
                    Text("Direct Roxstar Test")
                        .font(.custom("Roxstar", size: 20))
                }
                
                Divider()
                
                // Font List Button
                Button("Print Available Fonts to Console") {
                    BemoTheme.listAvailableFonts()
                }
                .primaryButtonStyle()
                
                Text("Check Xcode console for font list output")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
        }
    }
}

#Preview {
    FontTestView()
}