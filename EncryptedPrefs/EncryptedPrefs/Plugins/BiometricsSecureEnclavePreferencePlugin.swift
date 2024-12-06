//
//  BiometricsSecureEnclavePreferencePlugin.swift
//  EncryptedPrefs
//
//  Created by Adam Dahan on 2024-10-21.
//

import Foundation

// NOTE: - Operations requiring biometric authentication must run on the main thread to properly trigger the UI.

@objc class BiometricsSecureEnclavePreferencePlugin: NSObject, EncryptedPreferencePluginInterface {

    // MARK: - Properties
    private let secureEnclaveStore = SecureEnclaveStore(service: "com.cibc.biometrics.secureenclave.preferences")

    // MARK: - Get Preference
    @MainActor
    func getPreference(key: String, default: String) async throws -> String {
        do {
            let data = try secureEnclaveStore.retrieve(forKey: key, biometric: true, hasPasscodeFallback: false)
            guard let value = String(data: data, encoding: .utf8) else {
                throw StoreError.encodingError // Handle decoding error
            }
            return value
        } catch {
            throw StoreError.keychainError("Failed to retrieve preference: \(error.localizedDescription)")
        }
    }

    // MARK: - Put Preference
    @MainActor
    func putPreference(key: String, value: String) async throws {
        guard let data = value.data(using: .utf8) else {
            throw StoreError.encodingError // Handle invalid string encoding
        }
        do {
            try secureEnclaveStore.save(data: data, forKey: key, biometric: true, hasPasscodeFallback: false)
        } catch {
            throw StoreError.keychainError("Failed to store preference: \(error.localizedDescription)")
        }
    }

    // MARK: - Has Preference
    @MainActor
    func hasPreference(key: String) async throws -> Bool {
        return secureEnclaveStore.keyExists(forKey: key)
    }

    // MARK: - Remove Preference
    @MainActor
    func removePreference(key: String) async throws {
        let success = secureEnclaveStore.delete(forKey: key)
        if !success {
            throw StoreError.keychainError("Failed to delete preference.")
        }
    }
}
