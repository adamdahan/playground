import Foundation
import LocalAuthentication
import Security

/// A class that provides secure storage using Keychain and Secure Enclave.
class SecureStore {

    enum StorageType {
        case keychain(biometric: Bool)  // Standard Keychain with optional biometric access
        case secureEnclave  // Secure Enclave-backed storage
    }

    private let service: String

    init(service: String) {
        self.service = service
    }

    // MARK: - Save Data

    func save(data: Data, forKey key: String, storageType: StorageType) -> Bool {
        switch storageType {
        case .keychain(let biometric):
            return saveToKeychain(data: data, forKey: key, biometric: biometric)
        case .secureEnclave:
            return saveToSecureEnclave(data: data, forKey: key)
        }
    }

    // MARK: - Retrieve Data

    func retrieve(forKey key: String, storageType: StorageType, context: LAContext? = nil) -> Data? {
        switch storageType {
        case .keychain(let biometric):
            return retrieveFromKeychain(forKey: key, biometric: biometric, context: context)
        case .secureEnclave:
            return retrieveFromSecureEnclave(forKey: key)
        }
    }

    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Keychain Operations

    private func saveToKeychain(data: Data, forKey key: String, biometric: Bool) -> Bool {
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            biometric ? kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly : kSecAttrAccessibleWhenUnlocked,
            biometric ? .userPresence : [],
            nil
        ) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func retrieveFromKeychain(forKey key: String, biometric: Bool, context: LAContext? = nil) -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if biometric {
            let authContext = context ?? LAContext()
            authContext.localizedReason = "Authenticate to access this item."
            query[kSecUseAuthenticationContext as String] = authContext
        }

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        return status == errSecSuccess ? dataTypeRef as? Data : nil
    }

    // MARK: - Secure Enclave Operations

    private func saveToSecureEnclave(data: Data, forKey key: String) -> Bool {
        // Check if a key with this label already exists
        if getSecureEnclavePrivateKey(forKey: key) != nil {
            print("Key already exists in Secure Enclave. Skipping creation.")
        } else {
            guard createSecureEnclaveKey(forKey: key) != nil else {
                print("Failed to generate new key for Secure Enclave.")
                return false
            }
        }

        guard let privateKey = getSecureEnclavePrivateKey(forKey: key),
              let publicKey = SecKeyCopyPublicKey(privateKey) else {
            print("Failed to retrieve keys.")
            return false
        }

        guard let encryptedData = encryptData(data, with: publicKey) else {
            print("Encryption failed.")
            return false
        }

        return saveEncryptedData(encryptedData, forKey: key)
    }

    private func retrieveFromSecureEnclave(forKey key: String) -> Data? {
        guard let privateKey = getSecureEnclavePrivateKey(forKey: key) else {
            print("Failed to retrieve private key from Secure Enclave.")
            return nil
        }

        guard let encryptedData = retrieveEncryptedData(forKey: key) else {
            print("Failed to retrieve encrypted data.")
            return nil
        }

        var error: Unmanaged<CFError>?
        guard let decryptedData = SecKeyCreateDecryptedData(
            privateKey,
            .eciesEncryptionStandardX963SHA256AESGCM,
            encryptedData as CFData,
            &error
        ) else {
            if let error = error?.takeRetainedValue() {
                print("Decryption error: \(error.localizedDescription)")
            } else {
                print("Decryption failed with unknown error.")
            }
            return nil
        }

        return decryptedData as Data
    }

    
    private func createSecureEnclaveKey(forKey key: String) -> SecKey? {
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .privateKeyUsage,
            nil
        ) else { return nil }

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecAttrLabel as String: key,
            kSecPrivateKeyAttrs as String: [
                kSecAttrAccessControl as String: accessControl
            ]
        ]

        var error: Unmanaged<CFError>?
        return SecKeyCreateRandomKey(query as CFDictionary, &error)
    }

    private func getSecureEnclavePrivateKey(forKey key: String) -> SecKey? {
        // Query to retrieve the private key from Secure Enclave
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrLabel as String: key,
            kSecReturnRef as String: true
        ]

        // Attempt to retrieve the key reference
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        // If the query succeeds, force-cast the result to SecKey (safe in this context)
        guard status == errSecSuccess else {
            print("Failed to retrieve the private key from Secure Enclave with status: \(status)")
            return nil
        }

        return (item as! SecKey)
    }

    private func encryptData(_ data: Data, with publicKey: SecKey) -> Data? {
        var error: Unmanaged<CFError>?
        guard let encryptedData = SecKeyCreateEncryptedData(
            publicKey,
            .eciesEncryptionStandardX963SHA256AESGCM,
            data as CFData,
            &error
        ) else {
            print("Encryption failed: \(error?.takeRetainedValue().localizedDescription ?? "Unknown error")")
            return nil
        }

        return encryptedData as Data
    }

    func saveEncryptedData(_ data: Data, forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // Check if the item already exists; update it if needed
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            return updateStatus == errSecSuccess
        } else {
            // Item does not exist, so add it
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            return addStatus == errSecSuccess
        }
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
}
