//
//  SecureEnclavePreferencePlugin.swift
//  EncryptedPrefs
//
//  Created by Adam Dahan on 2024-10-21.
//

import Foundation

import Foundation

@objc class SecureEnclavePreferencePlugin: NSObject, EncryptedPreferencePluginInterface {

    private let secureStore = SecureStore(service: "com.cibc.secureenclave.preferences")

    // MARK: - Get Preference
    func getPreference(key: String, default: String) async throws -> String {
        guard let data = secureStore.retrieve(forKey: key, storageType: .secureEnclave) else {
            return `default`  // Return default if no data is found
        }
        guard let value = String(data: data, encoding: .utf8) else {
            throw SecureStoreError.encodingError  // Handle encoding error
        }
        return value
    }

    // MARK: - Put Preference
    func putPreference(key: String, value: String) async throws {
        guard let data = value.data(using: .utf8) else {
            throw SecureStoreError.encodingError  // Handle invalid string encoding
        }
        let success = secureStore.save(data: data, forKey: key, storageType: .secureEnclave)
        if !success {
            throw SecureStoreError.keychainError("Failed to save data to Secure Enclave.")
        }
    }

    // MARK: - Has Preference
    func hasPreference(key: String) async throws -> Bool {
        let data = secureStore.retrieve(forKey: key, storageType: .secureEnclave)
        return data != nil  // Return true if data exists, false otherwise
    }
    
    func removePreference(key: String) async throws {
        let success = secureStore.delete(forKey: key)
        if !success {
            throw SecureStoreError.keychainError("Failed to delete item from Keychain.")
        }
    }
}
