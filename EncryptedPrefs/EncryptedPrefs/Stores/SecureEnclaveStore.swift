//
//  SecureEnclaveStore.swift
//  EncryptedPrefs
//
//  Created by Adam Dahan on 2024-10-21.
//

import Foundation
import Security
import LocalAuthentication

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

    /// Save data to the Secure Enclave.
    func save(data: Data, forKey key: String, biometric: Bool, hasPasscodeFallback: Bool) -> Bool {
        guard let privateKey = createOrRetrieveSecureEnclaveKey(forKey: key, biometric: biometric, hasPasscodeFallback: hasPasscodeFallback) else {
            print("Failed to create or retrieve Secure Enclave key.")
            return false
        }
        
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            print("Failed to extract public key from Secure Enclave key.")
            return false
        }
        
        guard let encryptedData = encryptData(data, with: publicKey) else {
            print("Failed to encrypt data.")
            return false
        }
        
        return saveEncryptedData(encryptedData, forKey: key)
    }

    /// Retrieve data from the Secure Enclave.
    func retrieve(forKey key: String, biometric: Bool, hasPasscodeFallback: Bool) -> Data? {
        guard let privateKey = retrievePrivateKey(forKey: key, biometric: biometric, hasPasscodeFallback: hasPasscodeFallback),
              let encryptedData = retrieveEncryptedData(forKey: key) else {
            print("Failed to retrieve data or key.")
            return nil
        }

        var error: Unmanaged<CFError>?
        guard let decryptedData = SecKeyCreateDecryptedData(
            privateKey,
            .eciesEncryptionStandardX963SHA256AESGCM,
            encryptedData as CFData,
            &error
        ) as Data? else {
            print("Decryption failed with error: \(error?.takeRetainedValue() as Error?)")
            return nil
        }
        
        return decryptedData
    }

    /// Delete the key and associated encrypted data.
    func delete(forKey key: String) -> Bool {
        let keyDeleted = deleteKey(forKey: key)
        let dataDeleted = deleteEncryptedData(forKey: key)

        if !keyDeleted || !dataDeleted {
            print("Failed to delete item from Secure Enclave.")
            return false
        }
        return true
    }

    /// Check if a key exists in the Keychain.
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

    private func createOrRetrieveSecureEnclaveKey(forKey key: String, biometric: Bool, hasPasscodeFallback: Bool) -> SecKey? {
        if biometric || hasPasscodeFallback {
            guard laContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
                print("Biometric authentication or passcode fallback is required but unavailable.")
                return nil
            }
        }
        
        if let existingKey = retrievePrivateKey(forKey: key, biometric: biometric, hasPasscodeFallback: hasPasscodeFallback) {
            return existingKey
        }
        
        print("Key not found. Creating a new Secure Enclave key...")
        return createSecureEnclaveKey(forKey: key, biometric: biometric, hasPasscodeFallback: hasPasscodeFallback)
    }

    private func retrievePrivateKey(forKey key: String, biometric: Bool, hasPasscodeFallback: Bool) -> SecKey? {
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
            print("Failed to retrieve private key with status \(status)")
            return nil
        }

        return (item as! SecKey)
    }

    private func createSecureEnclaveKey(forKey key: String, biometric: Bool, hasPasscodeFallback: Bool) -> SecKey? {
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
            print("Failed to create access control.")
            return nil
        }

        let query: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecAttrLabel as String: key,
            kSecAttrAccessControl as String: accessControl
        ]

        var error: Unmanaged<CFError>?
        
        guard let newKey = SecKeyCreateRandomKey(query as CFDictionary, &error) else {
            print("Failed to create Secure Enclave key with error \(error?.takeRetainedValue() as Error?)")
            return nil
        }
        
        print("Successfully created Secure Enclave key.")
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
            print("Encryption failed with error \(error?.takeRetainedValue() as Error?)")
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
        
        print("Failed to check keychain item with status \(status)")
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
