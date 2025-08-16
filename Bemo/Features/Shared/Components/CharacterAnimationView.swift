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
        .scaleEffect(animation.scale)
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
    }
    
    private func startAnimation() {
        guard !hasAppeared else { return }
        hasAppeared = true
        
        // Fade in
        withAnimation(.easeIn(duration: animation.fadeInDuration)) {
            opacity = 1
        }
        
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
    }
}
