//
//  AuthManager.swift
//  boringNotch
//
//  Handles Supabase authentication state
//

import Foundation
import Combine
import Supabase

/// Manages authentication state and user sessions
@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = true
    @Published var error: String?

    private var authStateTask: Task<Void, Never>?

    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    private init() {
        Task {
            await checkSession()
            startAuthStateListener()
        }
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - Session Management

    /// Check for existing session on app launch
    func checkSession() async {
        isLoading = true
        do {
            let session = try await supabase.auth.session
            currentUser = session.user
            isAuthenticated = true
        } catch {
            currentUser = nil
            isAuthenticated = false
        }
        isLoading = false
    }

    /// Listen for auth state changes
    private func startAuthStateListener() {
        authStateTask = Task {
            for await (event, session) in supabase.auth.authStateChanges {
                guard !Task.isCancelled else { break }

                switch event {
                case .signedIn:
                    currentUser = session?.user
                    isAuthenticated = true
                case .signedOut:
                    currentUser = nil
                    isAuthenticated = false
                case .tokenRefreshed:
                    currentUser = session?.user
                case .userUpdated:
                    currentUser = session?.user
                default:
                    break
                }
            }
        }
    }

    // MARK: - Authentication Methods

    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        isLoading = true
        error = nil

        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            currentUser = session.user
            isAuthenticated = true
            isLoading = false
        } catch let authError {
            isLoading = false
            error = authError.localizedDescription
            throw authError
        }
    }

    /// Sign up with email and password
    func signUp(email: String, password: String) async throws {
        isLoading = true
        error = nil

        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )
            if let session = response.session {
                currentUser = session.user
                isAuthenticated = true
            }
            isLoading = false
        } catch let authError {
            isLoading = false
            error = authError.localizedDescription
            throw authError
        }
    }

    /// Sign out the current user
    func signOut() async throws {
        do {
            try await supabase.auth.signOut()
            currentUser = nil
            isAuthenticated = false
        } catch let signOutError {
            error = signOutError.localizedDescription
            throw signOutError
        }
    }

    /// Get the current user's email
    var userEmail: String? {
        currentUser?.email
    }

    /// Get user initials for avatar
    var userInitials: String {
        guard let email = currentUser?.email else { return "?" }
        return String(email.prefix(2)).uppercased()
    }
}
