//
//  BiometricsSecureEnclavePreferencePlugin.swift
//  EncryptedPrefs
//
//  Created by Adam Dahan on 2024-10-21.
//

import Foundation
import Security
import LocalAuthentication

@objc class BiometricsSecureEnclavePreferencePlugin: NSObject, EncryptedPreferencePluginInterface {

    private let secureStore: SecureStore = SecureStore(service: "com.cibc.biometrics.secureenclave.preferences")

    // MARK: - Get Preference
   func getPreference(key: String, default: String) async throws -> String {
        guard let data = try await retrieveDataWithBiometrics(forKey: key) else {
            return `default`  // Return default if data not found
        }
        guard let value = String(data: data, encoding: .utf8) else {
            throw SecureStoreError.encodingError  // Handle decoding error
        }
        return value
    }

    // MARK: - Put Preference
   func putPreference(key: String, value: String) async throws {
        guard let data = value.data(using: .utf8) else {
            throw SecureStoreError.encodingError  // Handle invalid string encoding
        }
        let success = try await saveDataWithBiometrics(data: data, forKey: key)
        if !success {
            throw SecureStoreError.keychainError("Failed to save data to Secure Enclave with biometric protection.")
        }
    }

    // MARK: - Has Preference
   func hasPreference(key: String) async throws -> Bool {
        let data = try await retrieveDataWithBiometrics(forKey: key)
        return data != nil  // Return true if data exists, false otherwise
    }
    
   func removePreference(key: String) async throws {
        let success = secureStore.delete(forKey: key)
        if !success {
            throw SecureStoreError.keychainError("Failed to delete item from Keychain.")
        }
    }

    // MARK: - Private Helper Methods

    private func saveDataWithBiometrics(data: Data, forKey key: String) async throws -> Bool {
        let success = secureStore.save(data: data, forKey: key, storageType: .secureEnclave)
        if !success {
            throw SecureStoreError.keychainError("Failed to store data with Secure Enclave.")
        }
        return true
    }

    private func retrieveDataWithBiometrics(forKey key: String) async throws -> Data? {
        // Use LAContext for biometric authentication
        let context = LAContext()
        context.localizedReason = "Authenticate to access your secure data."

        let authenticated = try await authenticateWithBiometrics(context: context)
        guard authenticated else {
            throw SecureStoreError.keychainError("Biometric authentication failed.")
        }

        // Retrieve data from Secure Enclave
        let data = secureStore.retrieve(forKey: key, storageType: .secureEnclave)
        if data == nil {
            throw SecureStoreError.dataNotFound
        }
        return data
    }

    private func authenticateWithBiometrics(context: LAContext) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Access your data") { success, error in
                if success {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(throwing: error ?? SecureStoreError.keychainError("Authentication failed."))
                }
            }
        }
    }
}
