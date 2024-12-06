//
//  SecureEnclaveStore.swift
//  EncryptedPrefs
//
//  Created by Adam Dahan on 2024-10-21.
//

import Foundation
import Security
import LocalAuthentication

/// Errors that can occur during Secure Enclave operations.
enum SecureEnclaveError: Error {
    case biometricNotAvailable
    case authenticationFailed(String)
    case keyCreationFailed(String)
    case keyRetrievalFailed(String)
    case encryptionFailed(String)
    case decryptionFailed(String)
    case dataNotFound
    case unknownError(String)
}

/// Manages Secure Enclave operations, including saving, retrieving, and encrypting data.
class SecureEnclaveStore {

    // MARK: - Properties
    private let service: String
    private var laContext: LAContextProtocol

    // MARK: - Initializer
    init(service: String, laContext: LAContextProtocol = LAContextWrapper()) {
        self.service = service
        self.laContext = laContext
    }

    // MARK: - Public Methods

    func save(data: Data, forKey key: String, biometric: Bool, hasPasscodeFallback: Bool) throws {
        guard let privateKey = try createOrRetrieveSecureEnclaveKey(forKey: key, biometric: biometric, hasPasscodeFallback: hasPasscodeFallback) else {
            throw SecureEnclaveError.keyCreationFailed("Failed to create or retrieve Secure Enclave key.")
        }
        
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw SecureEnclaveError.keyRetrievalFailed("Failed to extract public key.")
        }
        
        guard let encryptedData = encryptData(data, with: publicKey) else {
            throw SecureEnclaveError.encryptionFailed("Failed to encrypt data.")
        }
        
        guard saveEncryptedData(encryptedData, forKey: key) else {
            throw SecureEnclaveError.unknownError("Failed to save encrypted data to Keychain.")
        }
    }

    func retrieve(forKey key: String, biometric: Bool, hasPasscodeFallback: Bool) throws -> Data {
        // Check if the private key exists
        guard let privateKey = try? retrievePrivateKey(forKey: key, biometric: biometric, hasPasscodeFallback: hasPasscodeFallback) else {
            throw SecureEnclaveError.dataNotFound // Treat a missing key as "data not found"
        }

        // Check if the encrypted data exists
        guard let encryptedData = retrieveEncryptedData(forKey: key) else {
            throw SecureEnclaveError.dataNotFound
        }

        var error: Unmanaged<CFError>?
        guard let decryptedData = SecKeyCreateDecryptedData(
            privateKey,
            .eciesEncryptionStandardX963SHA256AESGCM,
            encryptedData as CFData,
            &error
        ) as Data? else {
            let errorMessage = error?.takeRetainedValue().localizedDescription ?? "Unknown decryption error."
            throw SecureEnclaveError.decryptionFailed(errorMessage)
        }

        return decryptedData
    }

    func delete(forKey key: String) -> Bool {
        let keyDeleted = deleteKey(forKey: key)
        let dataDeleted = deleteEncryptedData(forKey: key)

        if !keyDeleted || !dataDeleted {
            print("Failed to delete item from Secure Enclave.")
            return false
        }
        return true
    }

    func keyExists(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Private Helper Methods

    private func createOrRetrieveSecureEnclaveKey(forKey key: String, biometric: Bool, hasPasscodeFallback: Bool) throws -> SecKey? {
        if biometric || hasPasscodeFallback {
            var authError: NSError?
            guard laContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
                throw SecureEnclaveError.biometricNotAvailable
            }
        }
        
        if let existingKey = try retrievePrivateKey(forKey: key, biometric: biometric, hasPasscodeFallback: hasPasscodeFallback) {
            return existingKey
        }
        
        return try createSecureEnclaveKey(forKey: key, biometric: biometric, hasPasscodeFallback: hasPasscodeFallback)
    }

    private func retrievePrivateKey(forKey key: String, biometric: Bool, hasPasscodeFallback: Bool) throws -> SecKey? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrLabel as String: key,
            kSecReturnRef as String: true
        ]

        if biometric || hasPasscodeFallback {
            query[kSecUseAuthenticationContext as String] = createLAContext(hasPasscodeFallback: hasPasscodeFallback)
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        } else if status != errSecSuccess {
            throw SecureEnclaveError.keyRetrievalFailed("Failed to retrieve private key with status \(status).")
        }

        return (item as! SecKey)
    }

    private func createSecureEnclaveKey(forKey key: String, biometric: Bool, hasPasscodeFallback: Bool) throws -> SecKey? {
        let flags: SecAccessControlCreateFlags
        if biometric {
            flags = hasPasscodeFallback ? [.privateKeyUsage, .userPresence] : [.privateKeyUsage, .biometryCurrentSet]
        } else {
            flags = .privateKeyUsage
        }

        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            flags,
            nil
        ) else {
            throw SecureEnclaveError.keyCreationFailed("Failed to create access control.")
        }

        let query: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecAttrLabel as String: key,
            kSecAttrAccessControl as String: accessControl
        ]

        var error: Unmanaged<CFError>?
        
        guard let newKey = SecKeyCreateRandomKey(query as CFDictionary, &error) else {
            let errorMessage = error?.takeRetainedValue().localizedDescription ?? "Unknown key creation error."
            throw SecureEnclaveError.keyCreationFailed(errorMessage)
        }
        
        return newKey
    }

    private func createLAContext(hasPasscodeFallback: Bool) -> LAContext {
        let context = LAContext()
        context.localizedFallbackTitle = hasPasscodeFallback ? "Use Passcode" : ""
        return context
    }

    private func encryptData(_ data: Data, with publicKey: SecKey) -> Data? {
        var error: Unmanaged<CFError>?
        
        guard let encryptedData = SecKeyCreateEncryptedData(
            publicKey,
            .eciesEncryptionStandardX963SHA256AESGCM,
            data as CFData,
            &error
        ) else {
            return nil
        }
        
        return encryptedData as Data
    }

    private func saveEncryptedData(_ data: Data, forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            return updateStatus == errSecSuccess
        } else if status == errSecItemNotFound {
            var newQuery = query
            newQuery[kSecValueData as String] = data
            return SecItemAdd(newQuery as CFDictionary, nil) == errSecSuccess
        }
        
        return false
    }

    private func retrieveEncryptedData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        return status == errSecSuccess ? dataTypeRef as? Data : nil
    }

    private func deleteKey(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrLabel as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private func deleteEncryptedData(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
