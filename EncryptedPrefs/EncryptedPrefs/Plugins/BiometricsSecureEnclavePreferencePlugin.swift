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
    func getPreference(key: String, default defaultValue: String) async throws -> String {
        do {
            let data = try secureEnclaveStore.retrieve(forKey: key, biometric: true, reason: "Authenticate to access your secure data")

            // Attempt to decode the retrieved data into a string
            guard let value = String(data: data, encoding: .utf8) else {
                throw SecureEnclaveError.encodingFailed("Failed to decode preference as UTF-8 string.")
            }
            return value
        } catch SecureEnclaveError.dataNotFound {
            // Return the default value if the key doesn't exist
            return defaultValue
        } // Other SecureEnclaveError cases will propagate naturally
    }

    // MARK: - Put Preference
    @MainActor
    func putPreference(key: String, value: String) async throws {
        guard let data = value.data(using: .utf8) else {
            throw SecureEnclaveError.encodingFailed("Failed to encode preference as UTF-8 data.")
        }
        try secureEnclaveStore.save(data: data, forKey: key, biometric: true, reason: "Authenticate to access your secure data")
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
            throw SecureEnclaveError.keyDeletionFailed("Failed to delete preference.")
        }
    }
}
