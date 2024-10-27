//
//  BiometricsPreferencePlugin.swift
//  EncryptedPrefs
//
//  Created by Adam Dahan on 2024-10-21.
//

import Foundation

@objc class BiometricsPreferencePlugin: NSObject, EncryptedPreferencePluginInterface {

    // MARK: - Properties
    private let keychainStore = KeychainStore(service: "com.cibc.biometrics.preferences")

    // MARK: - Get Preference
    func getPreference(key: String, default: String) async throws -> String {
        guard let data = keychainStore.retrieve(forKey: key, biometric: true) else {
            throw StoreError.dataNotFound  // Throw if data is not found
        }
        guard let value = String(data: data, encoding: .utf8) else {
            throw StoreError.encodingError  // Handle encoding error
        }
        return value
    }

    // MARK: - Put Preference
    func putPreference(key: String, value: String) async throws {
        guard let data = value.data(using: .utf8) else {
            throw StoreError.encodingError  // Handle invalid string encoding
        }

        let success = keychainStore.save(data: data, forKey: key, biometric: true)
        if !success {
            throw StoreError.keychainError("Failed to save data to Keychain with biometric authentication.")
        }
    }

    // MARK: - Has Preference
    func hasPreference(key: String) async throws -> Bool {
        let data = keychainStore.retrieve(forKey: key, biometric: true)
        return data != nil  // Return true if data exists, false otherwise
    }

    // MARK: - Remove Preference
    func removePreference(key: String) async throws {
        let success = keychainStore.delete(forKey: key)
        if !success {
            throw StoreError.keychainError("Failed to delete item from Keychain.")
        }
    }
}
