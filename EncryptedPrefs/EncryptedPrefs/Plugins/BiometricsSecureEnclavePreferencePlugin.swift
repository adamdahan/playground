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
        guard let data = secureEnclaveStore.retrieve(forKey: key, biometric: true) else {
            throw StoreError.dataNotFound
        }
        guard let value = String(data: data, encoding: .utf8) else {
            throw StoreError.encodingError  // Handle decoding error
        }
        return value
    }

    // MARK: - Put Preference
    @MainActor
    func putPreference(key: String, value: String) async throws {
        guard let data = value.data(using: .utf8) else {
            throw StoreError.encodingError  // Handle invalid string encoding
        }
        let success = secureEnclaveStore.save(data: data, forKey: key, biometric: true)
        if !success {
            throw StoreError.keychainError("Failed to store data with Secure Enclave.")
        }
    }

    // MARK: - Has Preference
    @MainActor
    func hasPreference(key: String) async throws -> Bool {
        return secureEnclaveStore.retrieve(forKey: key, biometric: true) != nil
    }

    // MARK: - Remove Preference
    @MainActor
    func removePreference(key: String) async throws {
        let success = secureEnclaveStore.delete(forKey: key)
        if !success {
            throw StoreError.keychainError("Failed to delete item from Secure Enclave.")
        }
    }
}