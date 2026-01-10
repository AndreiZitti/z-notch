//
//  AccountSettings.swift
//  boringNotch
//
//  Account settings view for Supabase authentication
//

import SwiftUI

struct AccountSettings: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSignUp: Bool = false
    @State private var showError: Bool = false
    @State private var isSubmitting: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                Text("Account")
                    .font(.title)
                    .fontWeight(.bold)

                if authManager.isLoading {
                    // Loading state
                    VStack {
                        ProgressView()
                            .padding()
                        Text("Loading...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
                } else if authManager.isAuthenticated {
                    // Logged in state
                    loggedInView
                } else {
                    // Login form
                    loginForm
                }

                Spacer()
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Logged In View

    private var loggedInView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // User info card
            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 60, height: 60)
                    Text(authManager.userInitials)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Signed in as")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(authManager.userEmail ?? "Unknown")
                        .font(.headline)
                }

                Spacer()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Sign out button
            Button(action: {
                Task {
                    try? await authManager.signOut()
                }
            }) {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }

    // MARK: - Login Form

    private var loginForm: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Info text
            Text(isSignUp ? "Create an account to sync your settings and data across devices." : "Sign in to access your synced settings and data.")
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 16) {
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
                        .padding(.vertical, 4)
                }

                // Submit button
                HStack {
                    Button(action: handleSubmit) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .padding(.trailing, 4)
                            }
                            Text(isSignUp ? "Create Account" : "Sign In")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(email.isEmpty || password.isEmpty || isSubmitting)

                    Spacer()

                    // Toggle sign up / sign in
                    Button(action: {
                        withAnimation {
                            isSignUp.toggle()
                            showError = false
                            authManager.error = nil
                        }
                    }) {
                        Text(isSignUp ? "Have an account? Sign In" : "Need an account? Sign Up")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Actions

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
                // Clear form on success
                email = ""
                password = ""
            } catch {
                showError = true
            }
            isSubmitting = false
        }
    }
}

#Preview {
    AccountSettings()
        .frame(width: 500, height: 400)
}
