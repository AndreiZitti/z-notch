//
//  SupabaseManager.swift
//  boringNotch
//
//  Created for Supabase integration
//

import Foundation
import Supabase

/// Singleton manager for Supabase client
@MainActor
final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://supabase.zitti.ro")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY2NTYzMjAwLCJleHAiOjE5MjQzMjk2MDB9.rucK8VpVAV4EcBs3ZTFYJxIf7CzA8TVeYpYWdfp8GWM"
        )
    }
}
