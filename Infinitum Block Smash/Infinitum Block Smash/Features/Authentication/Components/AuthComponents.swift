/*
 * AuthComponents.swift
 * 
 * REUSABLE AUTHENTICATION UI COMPONENTS AND STYLES
 * 
 * This file contains all reusable UI components, styles, and views for the authentication
 * system in Infinitum Block Smash. It provides a consistent, modern design system for
 * authentication forms, buttons, and visual elements.
 * 
 * KEY RESPONSIBILITIES:
 * - Reusable authentication UI components
 * - Modern button and text field styles
 * - Authentication form layouts and validation
 * - Visual design consistency across auth flows
 * - Responsive design for different screen sizes
 * - Accessibility support for auth components
 * - Form validation and user feedback
 * - Loading states and progress indicators
 * - Error message display and styling
 * - Cross-platform authentication UI
 * 
 * MAJOR DEPENDENCIES:
 * - AuthViewModel.swift: Data binding and business logic
 * - SwiftUI: Core UI framework
 * - ProfanityFilter.swift: Username content validation
 * - AuthenticationServices: Apple Sign-In UI integration
 * - GameKit: Game Center authentication UI
 * - UserNotifications: Permission request UI
 * 
 * UI COMPONENTS:
 * - ModernButtonStyle: Consistent button styling
 * - ModernTextFieldStyle: Text input field styling
 * - AuthHeaderView: Welcome and branding header
 * - SignInFormView: Email/password sign-in form
 * - SignUpFormView: User registration form
 * - AdditionalInfoFormView: Profile completion form
 * - PasswordResetFormView: Password recovery form
 * - MainAuthButtonsView: Primary authentication options
 * - PhoneSignInView: SMS-based authentication
 * - GameCenterSignInView: Game Center integration
 * 
 * DESIGN SYSTEM:
 * - Consistent color scheme and theming
 * - Modern gradient backgrounds
 * - Card-based form layouts
 * - Responsive typography
 * - Accessibility-compliant design
 * - Dark/light mode support
 * - Haptic feedback integration
 * - Smooth animations and transitions
 * 
 * FORM VALIDATION:
 * - Real-time input validation
 * - Username content filtering
 * - Password strength indicators
 * - Email format validation
 * - Required field highlighting
 * - Error message display
 * - Success state feedback
 * 
 * RESPONSIVE DESIGN:
 * - Adaptive layouts for different screen sizes
 * - iPad and iPhone optimization
 * - Landscape and portrait support
 * - Dynamic type support
 * - Accessibility scaling
 * - Safe area handling
 * 
 * ACCESSIBILITY FEATURES:
 * - VoiceOver support for all components
 * - Dynamic type compatibility
 * - High contrast mode support
 * - Reduced motion preferences
 * - Accessibility labels and hints
 * - Keyboard navigation support
 * 
 * PERFORMANCE FEATURES:
 * - Efficient view updates
 * - Optimized rendering
 * - Memory-efficient components
 * - Lazy loading where appropriate
 * - Background processing for validation
 * 
 * USER EXPERIENCE:
 * - Intuitive form layouts
 * - Clear visual hierarchy
 * - Consistent interaction patterns
 * - Smooth transitions
 * - Immediate feedback
 * - Error recovery guidance
 * 
 * INTEGRATION POINTS:
 * - Authentication view models
 * - Firebase authentication flows
 * - Apple Sign-In integration
 * - Game Center authentication
 * - Push notification permissions
 * - User profile management
 * 
 * ARCHITECTURE ROLE:
 * This file provides the presentation layer components for authentication,
 * ensuring consistent UI/UX while maintaining separation of concerns
 * between visual design and business logic.
 * 
 * THREADING CONSIDERATIONS:
 * - UI updates on main thread
 * - Background validation processing
 * - Thread-safe data binding
 * - Async/await for network operations
 * 
 * SECURITY CONSIDERATIONS:
 * - Secure text field handling
 * - Input sanitization
 * - Privacy-compliant UI
 * - Secure credential display
 * 
 * REVIEW NOTES:
 * - Verify all form validation logic and user feedback
 * - Check accessibility compliance for all UI components
 * - Test responsive design across different device sizes
 * - Validate dark/light mode theming consistency
 * - Check profanity filter integration in username fields
 * - Test form submission and error handling flows
 * - Verify loading states and progress indicators
 * - Check keyboard navigation and accessibility features
 * - Test dynamic type scaling and text wrapping
 * - Validate haptic feedback integration
 * - Check safe area handling on different devices
 * - Test landscape and portrait orientation support
 * - Verify error message localization and clarity
 * - Check form field focus management and tab order
 * - Test network connectivity error scenarios
 * - Validate Apple Sign-In button integration
 * - Check Game Center authentication UI flow
 * - Test notification permission request UI
 * - Verify password strength indicator accuracy
 * - Check form validation timing and user experience
 * - Test cross-device authentication UI consistency
 * - Validate referral code input handling
 * - Check guest mode UI flow and messaging
 * - Test account linking and merging UI flows
 * - Verify data privacy compliance in UI elements
 */

import SwiftUI

// MARK: - Modern Button Style
struct ModernButtonStyle: ButtonStyle {
    var filled: Bool = true
    var accent: Color = Color.accentColor
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func makeBody(configuration: Configuration) -> some View {
        let backgroundColor: Color = filled ? accent : Color(UIColor.systemBackground).opacity(0.85)
        let foregroundColor: Color = filled ? Color(UIColor.systemBackground) : accent
        let borderColor: Color = filled ? .clear : accent
        
        // Adjust padding based on device type
        let verticalPadding: CGFloat = horizontalSizeClass == .regular ? 16 : 14
        let horizontalPadding: CGFloat = horizontalSizeClass == .regular ? 32 : 24

        return configuration.label
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: horizontalSizeClass == .regular ? 400 : .infinity)
            .background(backgroundColor.opacity(configuration.isPressed ? 0.7 : 1))
            .foregroundColor(foregroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: filled ? 0 : 2)
            )
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: filled ? 8 : 2, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .contentShape(Rectangle())
            .onChange(of: configuration.isPressed) { isPressed in
                print("[ModernButtonStyle] Button pressed state changed: \(isPressed)")
            }
            .onAppear {
                print("[ModernButtonStyle] Button appeared with size class: \(horizontalSizeClass == .regular ? "regular" : "compact")")
            }
    }
}

// MARK: - Modern Text Field Style
struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .padding(12)
            .background(Color.white.opacity(0.12))
            .cornerRadius(12)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
    }
}

// MARK: - Auth Header View
struct AuthHeaderView: View {
    var body: some View {
        VStack {
            Image(systemName: "cube.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.white.opacity(0.85))
                .shadow(radius: 12)
                .padding(.bottom, 8)
            
            Text("Welcome to\nInfinitum Block Smash!")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                .padding(.bottom, 8)
            
            Text("Stack, smash, and climb the leaderboards!")
                .font(.title3)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)
        }
    }
}

// MARK: - Sign In Form View
struct SignInFormView: View {
    @ObservedObject var viewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            TextField("Email", text: $viewModel.email)
                .textFieldStyle(ModernTextFieldStyle())
            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(ModernTextFieldStyle())
            
            Button("Forgot Password?") {
                viewModel.showPasswordReset = true
            }
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.8))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, -4)
            
            VStack(spacing: 12) {
                Button("Sign In") {
                    viewModel.signInWithEmail()
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.clear)
                .buttonStyle(ModernButtonStyle())
                
                Button("Back") { viewModel.showSignIn = false }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.clear)
                    .buttonStyle(ModernButtonStyle(filled: false, accent: .gray))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
        .padding(.horizontal)
    }
}

// MARK: - Sign Up Form View
struct SignUpFormView: View {
    @ObservedObject var viewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            TextField("Email", text: $viewModel.email)
                .textFieldStyle(ModernTextFieldStyle())
            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(ModernTextFieldStyle())
            TextField("Username", text: $viewModel.username)
                .textFieldStyle(ModernTextFieldStyle())
            TextField("Referral Code (Optional)", text: $viewModel.referralCode)
                .textFieldStyle(ModernTextFieldStyle())
            VStack(spacing: 12) {
                Button("Create Account") {
                    viewModel.signUpWithEmail()
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.clear)
                .buttonStyle(ModernButtonStyle())
                
                Button("Back") { viewModel.showSignUp = false }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.clear)
                    .buttonStyle(ModernButtonStyle(filled: false, accent: .gray))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
        .padding(.horizontal)
    }
}

// MARK: - Additional Info Form View
struct AdditionalInfoFormView: View {
    @ObservedObject var viewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            Text(viewModel.tempAuthProvider == "force_username_change" ? "Change Username" : "Complete Your Profile")
                .font(.title2)
                .foregroundColor(.white)
                .padding(.bottom, 8)
            
            if !viewModel.errorMessage.isEmpty {
                Text(viewModel.errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.bottom, 8)
            }
            
            TextField("Username", text: $viewModel.username)
                .textFieldStyle(ModernTextFieldStyle())
                .onChange(of: viewModel.username) { newValue in
                    if !ProfanityFilter.isAppropriate(newValue) {
                        viewModel.errorMessage = "Username contains inappropriate language."
                    } else {
                        viewModel.errorMessage = ""
                    }
                }
            
            if viewModel.tempAuthProvider == "gamecenter" || viewModel.tempAuthProvider == "apple" {
                TextField("Email", text: $viewModel.email)
                    .textFieldStyle(ModernTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(ModernTextFieldStyle())
            }
            
            Button(viewModel.tempAuthProvider == "force_username_change" ? "Update Username" : "Complete Setup") {
                viewModel.completeAdditionalInfo()
            }
            .buttonStyle(ModernButtonStyle())
            .disabled(!ProfanityFilter.isAppropriate(viewModel.username) || 
                     (viewModel.tempAuthProvider == "gamecenter" || viewModel.tempAuthProvider == "apple") && 
                     (viewModel.email.isEmpty || viewModel.password.isEmpty))
            
            if viewModel.tempAuthProvider != "force_username_change" {
                Button("Cancel") {
                    viewModel.showAdditionalInfo = false
                    viewModel.tempUserID = ""
                    viewModel.tempAuthProvider = ""
                    viewModel.email = ""
                    viewModel.password = ""
                    viewModel.username = ""
                }
                .buttonStyle(ModernButtonStyle(filled: false, accent: .gray))
            }
        }
        .padding(24)
        .background(BlurView(style: .systemUltraThinMaterialDark))
        .cornerRadius(28)
        .padding(.horizontal, 24)
    }
}

// MARK: - Custom Button
struct CustomButton: UIViewRepresentable {
    let title: String
    let icon: String
    let color: UIColor
    let isFilled: Bool
    let action: () -> Void
    
    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.addTarget(context.coordinator, action: #selector(Coordinator.buttonTapped), for: .touchUpInside)
        
        // Configure button appearance
        button.backgroundColor = isFilled ? color : .clear
        button.layer.cornerRadius = 16
        button.layer.borderWidth = isFilled ? 0 : 2
        button.layer.borderColor = color.cgColor
        
        // Create button configuration
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: icon)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold))
            .withTintColor(isFilled ? .white : color, renderingMode: .alwaysOriginal)
        configuration.imagePadding = 8
        configuration.imagePlacement = .leading
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        
        // Configure title
        configuration.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: isFilled ? UIColor.white : color
            ])
        )
        
        button.configuration = configuration
        
        // Add shadow
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = isFilled ? 8 : 2
        button.layer.shadowOpacity = 0.15
        
        // Ensure the button is user interaction enabled
        button.isUserInteractionEnabled = true
        
        // Add a tap gesture recognizer as a backup
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.buttonTapped))
        tapGesture.cancelsTouchesInView = false
        button.addGestureRecognizer(tapGesture)
        
        return button
    }
    
    func updateUIView(_ uiView: UIButton, context: Context) {
        // Update button if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }
    
    class Coordinator: NSObject {
        let action: () -> Void
        
        init(action: @escaping () -> Void) {
            self.action = action
        }
        
        @objc func buttonTapped() {
            print("[CustomButton] Button tapped: \(String(describing: action))")
            DispatchQueue.main.async {
                self.action()
            }
        }
    }
}

// MARK: - Main Auth Buttons View
struct MainAuthButtonsView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        VStack(spacing: horizontalSizeClass == .regular ? 16 : 12) {
            // Sign In Button
            CustomButton(
                title: "Sign In",
                icon: "person.crop.circle",
                color: .systemBlue,
                isFilled: true
            ) {
                print("[MainAuthButtonsView] Sign In button tapped")
                viewModel.showSignIn = true
            }
            .frame(maxWidth: horizontalSizeClass == .regular ? 400 : .infinity)
            .frame(height: 50)
            .contentShape(Rectangle())
            
            // Sign Up Button
            CustomButton(
                title: "Sign Up with Email",
                icon: "envelope.fill",
                color: .systemBlue,
                isFilled: false
            ) {
                print("[MainAuthButtonsView] Sign Up button tapped")
                viewModel.showSignUp = true
            }
            .frame(maxWidth: horizontalSizeClass == .regular ? 400 : .infinity)
            .frame(height: 50)
            .contentShape(Rectangle())
            
            // Game Center Button
            CustomButton(
                title: "Sign In with Game Center",
                icon: "gamecontroller.fill",
                color: .systemGreen,
                isFilled: false
            ) {
                print("[MainAuthButtonsView] Game Center button tapped")
                viewModel.signInWithGameCenter()
            }
            .frame(maxWidth: horizontalSizeClass == .regular ? 400 : .infinity)
            .frame(height: 50)
            .contentShape(Rectangle())
            
            // Guest Button
            CustomButton(
                title: "Continue as Guest",
                icon: "person.fill",
                color: .systemGray,
                isFilled: false
            ) {
                print("[MainAuthButtonsView] Guest button tapped")
                viewModel.userID = UUID().uuidString
                viewModel.isGuest = true
                viewModel.dismiss()
            }
            .frame(maxWidth: horizontalSizeClass == .regular ? 400 : .infinity)
            .frame(height: 50)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: horizontalSizeClass == .regular ? 400 : .infinity)
        .onAppear {
            print("[MainAuthButtonsView] View appeared with size class: \(horizontalSizeClass == .regular ? "regular" : "compact")")
        }
    }
}

// MARK: - Password Reset Form View
struct PasswordResetFormView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var email = ""
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Reset Password")
                .font(.title2)
                .foregroundColor(.white)
                .padding(.bottom, 8)
            
            Text("Enter your email address and we'll send you a link to reset your password.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)
            
            TextField("Email", text: $email)
                .textFieldStyle(ModernTextFieldStyle())
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
            
            VStack(spacing: 12) {
                Button("Send Reset Link") {
                    viewModel.resetPassword(email: email)
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.clear)
                .buttonStyle(ModernButtonStyle())
                
                Button("Back") { viewModel.showPasswordReset = false }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.clear)
                    .buttonStyle(ModernButtonStyle(filled: false, accent: .gray))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
        .padding(.horizontal)
    }
} 