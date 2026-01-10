//
//  LoginView.swift
//  boringNotch
//
//  Login view for Supabase authentication
//

import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSignUp: Bool = false
    @State private var showError: Bool = false
    @State private var isSubmitting: Bool = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text(isSignUp ? "Create Account" : "Welcome Back")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(isSignUp ? "Sign up to get started" : "Sign in to your account")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)

            // Form
            VStack(spacing: 16) {
                // Email field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("you@example.com", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                }

                // Password field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Password")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SecureField("Enter your password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(isSignUp ? .newPassword : .password)
                }

                // Error message
                if let error = authManager.error, showError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Submit button
                Button(action: handleSubmit) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 4)
                        }
                        Text(isSignUp ? "Create Account" : "Sign In")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty || isSubmitting)

                // Toggle sign up / sign in
                Button(action: {
                    withAnimation {
                        isSignUp.toggle()
                        showError = false
                        authManager.error = nil
                    }
                }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
        }
        .padding(24)
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func handleSubmit() {
        isSubmitting = true
        showError = false

        Task {
            do {
                if isSignUp {
                    try await authManager.signUp(email: email, password: password)
                } else {
                    try await authManager.signIn(email: email, password: password)
                }
                dismiss()
            } catch {
                showError = true
            }
            isSubmitting = false
        }
    }
}

// MARK: - User Avatar View (for menu bar / notch)

struct UserAvatarView: View {
    @ObservedObject var authManager = AuthManager.shared
    @State private var showLoginSheet: Bool = false
    @State private var showUserMenu: Bool = false

    var body: some View {
        Group {
            if authManager.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 24, height: 24)
            } else if authManager.isAuthenticated {
                // Logged in - show avatar
                Menu {
                    Text(authManager.userEmail ?? "User")
                        .font(.caption)

                    Divider()

                    Button("Sign Out") {
                        Task {
                            try? await authManager.signOut()
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 24, height: 24)
                        Text(authManager.userInitials)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            } else {
                // Not logged in - show login button
                Button(action: { showLoginSheet = true }) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 24, height: 24)
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showLoginSheet) {
                    LoginView()
                }
            }
        }
    }
}

#Preview {
    LoginView()
}
