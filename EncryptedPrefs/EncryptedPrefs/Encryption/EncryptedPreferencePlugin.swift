//
//  EncryptedPreferencePlugin.swift
//  EncryptedPrefs
//
//  Created by Adam Dahan on 2024-10-21.
//

import Foundation

@objc class EncryptedPreferencePlugin: NSObject, EncryptedPreferencePluginInterface {

    private let secureStore = SecureStore(service: "com.cibc.encrypted.preferences")

    func getPreference(key: String, default: String) async throws -> String {
        guard let data = secureStore.retrieve(forKey: key, storageType: .keychain(biometric: false)) else {
            throw SecureStoreError.dataNotFound
        }
        guard let value = String(data: data, encoding: .utf8) else {
            throw SecureStoreError.encodingError
        }
        return value
    }

    func putPreference(key: String, value: String) async throws {
        guard let data = value.data(using: .utf8) else {
            throw SecureStoreError.encodingError
        }

        let deleted = secureStore.delete(forKey: key)
        if !deleted {
            throw SecureStoreError.keychainError("Failed to delete previously stored value for key")
        }

        let success = secureStore.save(data: data, forKey: key, storageType: .keychain(biometric: false))
        if !success {
            throw SecureStoreError.keychainError("Failed to save data to Keychain.")
        }
    }

    func hasPreference(key: String) async throws -> Bool {
        guard secureStore.retrieve(forKey: key, storageType: .keychain(biometric: false)) != nil else {
            throw SecureStoreError.dataNotFound
        }
        return true
    }
    
    func removePreference(key: String) async throws {
        let success = secureStore.delete(forKey: key)
        if !success {
            throw SecureStoreError.keychainError("Failed to delete item from Keychain.")
        }
    }
}
