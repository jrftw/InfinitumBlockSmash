import SwiftUI

// MARK: - Modern Button Style
struct ModernButtonStyle: ButtonStyle {
    var filled: Bool = true
    var accent: Color = Color.accentColor
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let backgroundColor: Color = filled ? accent : Color(UIColor.systemBackground).opacity(0.85)
        let foregroundColor: Color = filled ? Color(UIColor.systemBackground) : accent
        let borderColor: Color = filled ? .clear : accent

        return configuration.label
            .padding(.vertical, 14)
            .background(backgroundColor.opacity(configuration.isPressed ? 0.7 : 1))
            .foregroundColor(foregroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: filled ? 0 : 2)
            )
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: filled ? 8 : 2, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
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
            Text("Complete Your Profile")
                .font(.title2)
                .foregroundColor(.white)
                .padding(.bottom, 8)
            
            TextField("Username", text: $viewModel.username)
                .textFieldStyle(ModernTextFieldStyle())
            
            if viewModel.tempAuthProvider == "gamecenter" {
                TextField("Email", text: $viewModel.email)
                    .textFieldStyle(ModernTextFieldStyle())
                
                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(ModernTextFieldStyle())
            }
            
            Button("Complete Setup") {
                viewModel.completeAdditionalInfo()
            }
            .buttonStyle(ModernButtonStyle())
            
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
        .padding(24)
        .background(BlurView(style: .systemUltraThinMaterialDark))
        .cornerRadius(28)
        .padding(.horizontal, 24)
    }
}

// MARK: - Main Auth Buttons View
struct MainAuthButtonsView: View {
    @ObservedObject var viewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 18) {
            Button(action: { viewModel.showSignIn = true }) {
                Label("Sign In", systemImage: "person.crop.circle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 40)
            }
            .buttonStyle(ModernButtonStyle())

            Button(action: { viewModel.showSignUp = true }) {
                Label("Sign Up with Email", systemImage: "envelope.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ModernButtonStyle(filled: false))

            Button(action: { viewModel.signInWithGameCenter() }) {
                Label("Sign In with Game Center", systemImage: "gamecontroller.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ModernButtonStyle(filled: false, accent: .green))

            Button(action: {
                viewModel.userID = UUID().uuidString
                viewModel.isGuest = true
                viewModel.dismiss()
            }) {
                Label("Continue as Guest", systemImage: "person.fill.questionmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ModernButtonStyle(filled: false, accent: .gray))
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