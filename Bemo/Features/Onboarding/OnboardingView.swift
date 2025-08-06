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
    
    private let onboardingSteps = OnboardingStep.allSteps
    
    init(viewModel: OnboardingViewModel) {
        self._viewModel = State(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if currentStep < onboardingSteps.count {
                    // Onboarding content
                    onboardingContent
                        .gesture(
                            DragGesture()
                                .onEnded { value in
                                    handleSwipeGesture(value)
                                }
                        )
                } else {
                    // Sign-in screen
                    signInContent
                        .gesture(
                            DragGesture()
                                .onEnded { value in
                                    handleSwipeGesture(value)
                                }
                        )
                }
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
    
    private var onboardingContent: some View {
        let step = onboardingSteps[currentStep]
        
        return VStack(spacing: 40) {
            Spacer()
            
            // Step indicator
            HStack(spacing: 8) {
                ForEach(0..<onboardingSteps.count + 1, id: \.self) { index in
                    Circle()
                        .fill(index == currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: index == currentStep ? 10 : 8, height: index == currentStep ? 10 : 8)
                        .animation(.easeInOut(duration: 0.2), value: currentStep)
                }
            }
            .padding(.top, 20)
            
            // Content
            VStack(spacing: 24) {
                Image(systemName: step.imageName)
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text(step.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(step.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // Navigation buttons
            VStack(spacing: 16) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        goToNextStep()
                    }
                }) {
                    Text(currentStep < onboardingSteps.count - 1 ? "Next" : "Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                
                if currentStep > 0 && currentStep < onboardingSteps.count {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            goToPreviousStep()
                        }
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            // Swipe hint
            Text("← Swipe to navigate →")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.bottom, 20)
        }
    }
    
    private var signInContent: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Step indicator
            HStack(spacing: 8) {
                ForEach(0..<onboardingSteps.count + 1, id: \.self) { index in
                    Circle()
                        .fill(index == currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: index == currentStep ? 10 : 8, height: index == currentStep ? 10 : 8)
                        .animation(.easeInOut(duration: 0.2), value: currentStep)
                }
            }
            .padding(.top, 20)
            
            // Welcome content
            VStack(spacing: 24) {
                Image(systemName: "person.2.circle")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Welcome to Bemo!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Sign in to create profiles for your children and track their progress.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // Sign-in section
            VStack(spacing: 24) {
                // Apple Sign-In Button or Loading
                if viewModel.isLoading {
                    HStack {
                        ProgressView()
                            .tint(.white)
                        Text("Signing in...")
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.black)
                    .cornerRadius(8)
                    .padding(.horizontal, 40)
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
                    .frame(height: 50)
                    .padding(.horizontal, 40)
                }
                
                // Privacy note
                Text("By signing in, you agree to our Privacy Policy and Terms of Service. We only use your information to create and manage child profiles.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // Back button
                Button("Back to Tutorial") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        goToPreviousStep()
                    }
                }
                .foregroundColor(.secondary)
            }
            
            // Swipe hint
            Text("← Swipe to navigate →")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.bottom, 20)
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
    
    static let allSteps = [
        OnboardingStep(
            title: "Learn Through Play",
            description: "Engage your child with educational games that make learning fun and interactive.",
            imageName: "gamecontroller.fill"
        ),
        OnboardingStep(
            title: "Computer Vision Magic",
            description: "Use your device's camera to interact with physical objects and bring them to life.",
            imageName: "camera.fill"
        ),
        OnboardingStep(
            title: "Track Progress",
            description: "Monitor your child's learning journey with detailed progress tracking and achievements.",
            imageName: "chart.line.uptrend.xyaxis"
        ),
        OnboardingStep(
            title: "Safe & Secure",
            description: "Your child's privacy and safety are our top priority. All data is encrypted and secure.",
            imageName: "shield.checkered"
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
            onAuthenticationComplete: { _ in }
        ))
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
    }
}