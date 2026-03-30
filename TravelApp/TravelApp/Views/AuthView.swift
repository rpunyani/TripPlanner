import SwiftUI

struct AuthView: View {
    @Environment(FirebaseService.self) private var firebase
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showResetPassword = false
    @State private var resetEmail = ""
    @State private var showResetSuccess = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    formSection
                    actionButtons
                    toggleSection
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground))
            .alert("Reset Password", isPresented: $showResetPassword) {
                TextField("Email", text: $resetEmail)
                    .textContentType(.emailAddress)
                Button("Cancel", role: .cancel) {}
                Button("Send Reset Link") {
                    Task { await resetPassword() }
                }
            } message: {
                Text("Enter your email to receive a password reset link.")
            }
            .alert("Check Your Email", isPresented: $showResetSuccess) {
                Button("OK") {}
            } message: {
                Text("A password reset link has been sent to your email.")
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 70))
                .foregroundStyle(.blue)
                .padding(.top, 40)
            
            Text("TravelApp")
                .font(.largeTitle.bold())
            
            Text(isSignUp ? "Create your account to start planning" : "Sign in to access your trips")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Form
    private var formSection: some View {
        VStack(spacing: 16) {
            if isSignUp {
                TextField("Display Name", text: $displayName)
                    .textContentType(.name)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            SecureField("Password", text: $password)
                .textContentType(isSignUp ? .newPassword : .password)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Actions
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task { await authenticate() }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isSignUp ? "Create Account" : "Sign In")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isFormValid ? .blue : .gray)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isFormValid || isLoading)
            
            if !isSignUp {
                Button("Forgot Password?") {
                    resetEmail = email
                    showResetPassword = true
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
            }
        }
    }
    
    // MARK: - Toggle
    private var toggleSection: some View {
        HStack {
            Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(isSignUp ? "Sign In" : "Sign Up") {
                withAnimation(.snappy) {
                    isSignUp.toggle()
                    errorMessage = nil
                }
            }
            .font(.subheadline.bold())
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helpers
    private var isFormValid: Bool {
        let emailValid = !email.trimmingCharacters(in: .whitespaces).isEmpty
        let passValid = password.count >= 6
        let nameValid = !isSignUp || !displayName.trimmingCharacters(in: .whitespaces).isEmpty
        return emailValid && passValid && nameValid
    }
    
    private func authenticate() async {
        isLoading = true
        errorMessage = nil
        
        do {
            if isSignUp {
                try await firebase.signUp(email: email, password: password, displayName: displayName)
            } else {
                try await firebase.signIn(email: email, password: password)
            }
        } catch let error as NSError {
            await MainActor.run {
                let code = error.code
                switch code {
                case 17999:
                    errorMessage = "Email/Password sign-in is not enabled. Please enable it in Firebase Console → Authentication → Sign-in method."
                case 17007:
                    errorMessage = "An account with this email already exists."
                case 17008:
                    errorMessage = "Please enter a valid email address."
                case 17009:
                    errorMessage = "Incorrect password. Please try again."
                case 17011:
                    errorMessage = "No account found with this email."
                case 17026:
                    errorMessage = "Password must be at least 6 characters."
                case 17010:
                    errorMessage = "Too many failed attempts. Please try again later."
                default:
                    errorMessage = "Error (\(code)): \(error.localizedDescription)"
                }
            }
        }
        
        await MainActor.run { isLoading = false }
    }
    
    private func resetPassword() async {
        do {
            try await firebase.resetPassword(email: resetEmail)
            await MainActor.run { showResetSuccess = true }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}

#Preview {
    AuthView()
        .environment(FirebaseService())
}
