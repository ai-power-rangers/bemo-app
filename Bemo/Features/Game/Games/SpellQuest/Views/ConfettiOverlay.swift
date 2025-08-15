//
//  ConfettiOverlay.swift
//  Bemo
//
//  Celebration confetti animation overlay
//

// WHAT: Animated confetti particles for celebrating word completion
// ARCHITECTURE: View layer in MVVM-S
// USAGE: Overlaid on game views when word is completed

import SwiftUI

struct ConfettiOverlay: View {
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<50, id: \.self) { index in
                    ConfettiPiece(
                        color: confettiColors.randomElement()!,
                        size: CGFloat.random(in: 8...15),
                        delay: Double(index) * 0.02,
                        screenSize: geometry.size
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            isAnimating = true
        }
    }
    
    private let confettiColors: [Color] = [
        .red, .blue, .green, .yellow, .orange, .purple, .pink
    ]
}

private struct ConfettiPiece: View {
    let color: Color
    let size: CGFloat
    let delay: Double
    let screenSize: CGSize
    
    @State private var position: CGPoint
    @State private var velocity: CGPoint
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1
    
    init(color: Color, size: CGFloat, delay: Double, screenSize: CGSize) {
        self.color = color
        self.size = size
        self.delay = delay
        self.screenSize = screenSize
        
        // Start from top center with random horizontal offset
        let startX = screenSize.width / 2 + CGFloat.random(in: -100...100)
        let startY = screenSize.height * 0.3
        self._position = State(initialValue: CGPoint(x: startX, y: startY))
        
        // Random initial velocity
        let vx = CGFloat.random(in: (-200)...200)
        let vy = CGFloat.random(in: (-400)...(-200))
        self._velocity = State(initialValue: CGPoint(x: vx, y: vy))
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: size / 4)
            .fill(color)
            .frame(width: size, height: size * 1.5)
            .rotationEffect(.degrees(rotation))
            .position(position)
            .opacity(opacity)
            .onAppear {
                withAnimation(.linear(duration: 3).delay(delay)) {
                    // Apply gravity and update position
                    let gravity: CGFloat = 500
                    let duration: CGFloat = 3
                    
                    // Final position after gravity
                    let finalX = position.x + velocity.x * duration
                    let finalY = position.y + velocity.y * duration + 0.5 * gravity * duration * duration
                    
                    position = CGPoint(x: finalX, y: finalY)
                    rotation = Double.random(in: 0...720)
                    
                    // Fade out as it falls
                    if finalY > screenSize.height * 0.8 {
                        opacity = 0
                    }
                }
            }
    }
}