//
//  CharacterAnimationView.swift
//  Bemo
//
//  Individual character animation view with GIF/video/image support
//

// WHAT: Renders a single character animation with fade in/out, scaling, and rotation effects
// ARCHITECTURE: View component that displays GIF, video, or static image based on animation type
// USAGE: Created by CharacterAnimationOverlay for each active animation in the service

import SwiftUI
import AVKit

struct CharacterAnimationView: View {
    let animation: CharacterAnimationService.CharacterAnimation
    let containerSize: CGSize
    let onRemove: () -> Void
    
    @State private var opacity: Double = 0
    @State private var hasAppeared = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Group {
            switch animation.animationType {
            case .gif:
                GIFImageView(gifName: animation.character.resourceName)
                    .frame(width: animation.size.width, height: animation.size.height)
            case .video:
                VideoPlayerView(videoName: animation.character.resourceName)
                    .frame(width: animation.size.width, height: animation.size.height)
            case .staticImage:
                Image(animation.character.resourceName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: animation.size.width, height: animation.size.height)
            }
        }
        .scaleEffect(animation.scale * pulseScale)
        .rotationEffect(.degrees(animation.rotation))
        .opacity(opacity)
        .onTapGesture {
            if animation.interactive {
                animation.onTap?()
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            // If animation is looping and we're disappearing, it means it was cleared
            if animation.loop {
                print("CharacterAnimationService: Looping animation '\(animation.character.resourceName)' is being removed")
            }
        }
    }
    
    private func startAnimation() {
        guard !hasAppeared else { return }
        hasAppeared = true
        
        // Fade in
        withAnimation(.easeIn(duration: animation.fadeInDuration)) {
            opacity = 1
        }
        
        // Only schedule fade out if not looping
        if !animation.loop {
            // Schedule fade out
            DispatchQueue.main.asyncAfter(deadline: .now() + animation.duration) {
                withAnimation(.easeOut(duration: animation.fadeOutDuration)) {
                    opacity = 0
                }
                
                // Remove after fade out completes
                DispatchQueue.main.asyncAfter(deadline: .now() + animation.fadeOutDuration) {
                    onRemove()
                }
            }
        } else {
            // If looping, add a subtle pulse effect to show it's active
            withAnimation(
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.05
            }
        }
    }
}
