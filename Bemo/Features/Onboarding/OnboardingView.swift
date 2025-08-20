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
    @State private var currentStep = 0
    @State private var animateContent = false
    @State private var showPageIndicator = true
    
    @Namespace private var animation
    private let onboardingSteps = OnboardingStep.allSteps
    
    init(viewModel: OnboardingViewModel) {
        self._viewModel = State(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            // Dynamic background
            backgroundView
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if currentStep < onboardingSteps.count {
                    // Onboarding content
                    onboardingContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .gesture(
                            DragGesture(minimumDistance: 30)
                                .onEnded { value in
                                    handleSwipeGesture(value)
                                }
                        )
                } else {
                    // Sign-in screen
                    signInContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateContent = true
            }
            // Show character for the initial step
            viewModel.showCharacterForStep(currentStep)
        }
        .onChange(of: currentStep) { _, newStep in
            // Show character animation for each new step
            if newStep < onboardingSteps.count {
                viewModel.showCharacterForStep(newStep)
            } else {
                // Show character on sign-in screen
                viewModel.showSignInCharacter()
            }
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
    
    private var onboardingContent: some View {
        let step = onboardingSteps[currentStep]
        
        return VStack(spacing: 0) {
            // Top section with page indicator
            VStack(spacing: BemoTheme.Spacing.medium) {
                // Page indicator
                if showPageIndicator {
                    pageIndicator
                        .padding(.top, 60)
                        .transition(.opacity)
                }
            }
            
            Spacer()
            
            // Main content
            VStack(spacing: BemoTheme.Spacing.xxlarge) {
                // Icon with animation
                ZStack {
                    Circle()
                        .fill(step.iconBackgroundColors.0.opacity(0.08))
                        .frame(width: 140, height: 140)
                        .scaleEffect(animateContent ? 1 : 0.9)
                        .animation(
                            Animation.easeInOut(duration: 2)
                                .repeatForever(autoreverses: true),
                            value: animateContent
                        )
                    
                    Image(systemName: step.imageName)
                        .font(.system(size: 64, weight: .regular, design: .rounded))
                        .foregroundColor(step.iconBackgroundColors.0)
                        .scaleEffect(animateContent ? 1 : 0.8)
                        .opacity(animateContent ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateContent)
                }
                
                // Text content
                VStack(spacing: BemoTheme.Spacing.medium) {
                    Text(step.title)
                        .font(BemoTheme.font(for: .heading3))
                        .foregroundColor(Color("AppPrimaryTextColor"))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(0.2), value: animateContent)
                    
                    Text(step.description)
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundColor(Color("AppPrimaryTextColor").opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(0.3), value: animateContent)
                }
            }
            .padding(.horizontal, BemoTheme.Spacing.large)
            
            Spacer()
            
            // Bottom navigation
            VStack(spacing: BemoTheme.Spacing.medium) {
                // Primary action button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        goToNextStep()
                    }
                }) {
                    HStack {
                        Text(currentStep < onboardingSteps.count - 1 ? "Continue" : "Get Started")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(BemoTheme.Colors.primary)
                    .cornerRadius(BemoTheme.CornerRadius.large)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, BemoTheme.Spacing.large)
                .scaleEffect(animateContent ? 1 : 0.9)
                .opacity(animateContent ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4), value: animateContent)
                
                // Skip button
                if currentStep < onboardingSteps.count - 1 {
                    Button("Skip") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = onboardingSteps.count
                        }
                    }
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(Color("AppPrimaryTextColor").opacity(0.6))
                    .padding(.vertical, BemoTheme.Spacing.xsmall)
                }
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
    
    private var pageIndicator: some View {
        HStack(spacing: 12) {
            ForEach(0..<onboardingSteps.count + 1, id: \.self) { index in
                Capsule()
                    .fill(
                        index == currentStep 
                            ? BemoTheme.Colors.primary
                            : Color.gray.opacity(0.2)
                    )
                    .frame(
                        width: index == currentStep ? 28 : 8,
                        height: 8
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentStep)
            }
        }
    }
    
    private var signInContent: some View {
        VStack(spacing: 0) {
            // Top section with page indicator
            VStack(spacing: BemoTheme.Spacing.medium) {
                if showPageIndicator {
                    pageIndicator
                        .padding(.top, 60)
                        .transition(.opacity)
                }
            }
            
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
                        Image(systemName: "sparkles")
                            .font(.system(size: 32, weight: .regular, design: .rounded))
                            .foregroundColor(BemoTheme.Colors.secondary)
                        
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
                
                // Back button
                if currentStep > 0 {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            goToPreviousStep()
                        }
                    }) {
                        Text("Back")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(Color("AppPrimaryTextColor").opacity(0.6))
                    }
                    .padding(.vertical, BemoTheme.Spacing.xsmall)
                }
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
    
    // MARK: - Navigation Methods
    
    private func handleSwipeGesture(_ value: DragGesture.Value) {
        let threshold: CGFloat = 50
        let horizontalMovement = value.translation.width
        
        if abs(horizontalMovement) > threshold {
            withAnimation(.easeInOut(duration: 0.3)) {
                if horizontalMovement > 0 {
                    // Swipe right - go back
                    goToPreviousStep()
                } else {
                    // Swipe left - go forward
                    goToNextStep()
                }
            }
        }
    }
    
    private func goToPreviousStep() {
        if currentStep > 0 {
            currentStep -= 1
        }
    }
    
    private func goToNextStep() {
        if currentStep < onboardingSteps.count {
            currentStep += 1
        }
    }
}

// MARK: - Onboarding Steps

struct OnboardingStep {
    let title: String
    let description: String
    let imageName: String
    let iconBackgroundColors: (Color, Color)
    
    static let allSteps = [
        OnboardingStep(
            title: "Tangram Adventures",
            description: "Watch your child develop spatial reasoning and problem-solving skills through engaging tangram puzzles designed for their age.",
            imageName: "square.on.square.dashed",
            iconBackgroundColors: (Color(hex: "#3B82F6"), Color(hex: "#60A5FA"))  // Blue
        ),
        OnboardingStep(
            title: "Real Objects, Real Learning",
            description: "Our computer vision technology recognizes physical tangram pieces, bridging the gap between digital and hands-on learning.",
            imageName: "viewfinder.circle.fill",
            iconBackgroundColors: (Color(hex: "#10B981"), Color(hex: "#34D399"))  // Green
        ),
        OnboardingStep(
            title: "Smart Progress Tracking",
            description: "Every puzzle solved builds a comprehensive skill profile. Watch your child master rotation, reflection, decomposition, and planning skills.",
            imageName: "chart.xyaxis.line",
            iconBackgroundColors: (Color(hex: "#F97316"), Color(hex: "#FB923C"))  // Orange
        ),
        OnboardingStep(
            title: "Parent Dashboard",
            description: "Stay connected to your child's learning journey with detailed insights, achievements, and personalized recommendations.",
            imageName: "person.2.badge.gearshape.fill",
            iconBackgroundColors: (Color(hex: "#EC4899"), Color(hex: "#F472B6"))  // Pink
        )
    ]
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

