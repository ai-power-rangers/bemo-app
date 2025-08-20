//
//  OnboardingView.swift
//  Bemo
//
//  Onboarding screens with Apple Sign-In integration
//

// WHAT: Main onboarding flow with Apple Sign-In. Shows welcome screens and handles authentication.
// ARCHITECTURE: View in MVVM-S. Uses OnboardingViewModel for authentication logic and state management.
// USAGE: Presented by AppCoordinator when user is not authenticated. Handles Apple Sign-In flow and navigation.

import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel
    @State private var animateContent = false
    
    @Namespace private var animation
    
    init(viewModel: OnboardingViewModel) {
        self._viewModel = State(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            // Dynamic background
            backgroundView
                .ignoresSafeArea()
            
            // Sign-in screen
            signInContent
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateContent = true
            }
            // Show character on sign-in screen
            viewModel.showSignInCharacter()
        }
        .alert("Authentication Error", isPresented: .constant(viewModel.authenticationError != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.authenticationError {
                Text(error.localizedDescription)
            }
        }
    }
    
    private var backgroundView: some View {
        ZStack {
            // App background color from assets
            Color("AppBackground")
            
            // Tangram background image with 66% opacity
            Image("tangram-background")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.33)
                .ignoresSafeArea()
            
            // Subtle animated shapes
            GeometryReader { geometry in
                ForEach(0..<2) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.gray.opacity(0.03),
                                    Color.gray.opacity(0.01)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blur(radius: 40)
                        .frame(width: geometry.size.width * 0.8)
                        .offset(
                            x: CGFloat.random(in: -50...50),
                            y: CGFloat(index) * 300 - 100
                        )
                        .animation(
                            Animation.easeInOut(duration: Double.random(in: 15...20))
                                .repeatForever(autoreverses: true),
                            value: animateContent
                        )
                }
            }
        }
    }
    


    private var signInContent: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Main content
            VStack(spacing: BemoTheme.Spacing.xxlarge) {
                // Logo/Icon section
                ZStack {
                    // Subtle background circle
                    Circle()
                        .fill(Color.gray.opacity(0.05))
                        .frame(width: 160, height: 160)
                        .scaleEffect(animateContent ? 1 : 0.9)
                        .animation(
                            Animation.easeInOut(duration: 2)
                                .repeatForever(autoreverses: true),
                            value: animateContent
                        )
                    
                    // Bemo logo placeholder (using shapes)
                    VStack(spacing: 8) {                        
                        Text("Bemo")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(BemoTheme.Colors.primary)
                    }
                    .scaleEffect(animateContent ? 1 : 0.8)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateContent)
                }
                
                // Welcome text
                VStack(spacing: BemoTheme.Spacing.medium) {
                    Text("Ready to Begin?")
                        .font(BemoTheme.font(for: .heading3))
                        .foregroundColor(Color("AppPrimaryTextColor"))
                        .multilineTextAlignment(.center)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(0.2), value: animateContent)
                    
                    Text("Sign in to unlock personalized learning experiences tailored for your child.")
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundColor(Color("AppPrimaryTextColor").opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(0.3), value: animateContent)
                }
            }
            .padding(.horizontal, BemoTheme.Spacing.large)
            
            Spacer()
            
            // Sign-in section
            VStack(spacing: BemoTheme.Spacing.large) {
                // Apple Sign-In Button or Loading
                if viewModel.isLoading {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.9)
                        Text("Signing in...")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(BemoTheme.CornerRadius.medium)
                    .padding(.horizontal, BemoTheme.Spacing.large)
                } else {
                    Button(action: {
                        viewModel.signInWithApple()
                    }) {
                        SignInWithAppleButton(
                            onRequest: { _ in },
                            onCompletion: { _ in }
                        )
                        .allowsHitTesting(false)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 56)
                    .cornerRadius(BemoTheme.CornerRadius.medium)
                    .padding(.horizontal, BemoTheme.Spacing.large)
                    .scaleEffect(animateContent ? 1 : 0.9)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4), value: animateContent)
                }
                
                // Privacy & Security badge
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.gray)
                    
                    Text("Your data is secure and private")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color("AppPrimaryTextColor").opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.gray.opacity(0.06))
                )
                .opacity(animateContent ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.5), value: animateContent)
                
                // Terms text
                Text("By continuing, you agree to our [Terms of Service](https://bemo.app/terms) and [Privacy Policy](https://bemo.app/privacy)")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(Color("AppPrimaryTextColor").opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .tint(BemoTheme.Colors.primary)
            }
            .padding(.bottom, 50)
        }
        .onAppear {
            animateContent = false
            withAnimation(.easeOut(duration: 0.6)) {
                animateContent = true
            }
        }
    }
    
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.1)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Loading...")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Previews

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(viewModel: OnboardingViewModel(
            authenticationService: AuthenticationService(),
            characterAnimationService: CharacterAnimationService(),
            onAuthenticationComplete: { _ in }
        ))
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
    }
}

