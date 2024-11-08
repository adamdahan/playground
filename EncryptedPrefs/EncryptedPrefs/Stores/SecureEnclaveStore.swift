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
    func save(data: Data, forKey key: String, biometric: Bool) -> Bool {
        guard
            let privateKey = createOrRetrieveSecureEnclaveKey(forKey: key, biometric: biometric),
            let publicKey = SecKeyCopyPublicKey(privateKey),
            let encryptedData = encryptData(data, with: publicKey)
        else {
            print("Failed to save data.")
            return false
        }
        return saveEncryptedData(encryptedData, forKey: key)
    }

    /// Retrieve data from the Secure Enclave.
    func retrieve(forKey key: String, biometric: Bool) -> Data? {
        guard
            let privateKey = retrievePrivateKey(forKey: key, biometric: biometric),
            let encryptedData = retrieveEncryptedData(forKey: key)
        else {
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
            kSecReturnData as String: false  // No need to retrieve data, just check existence
        ]
        
        // Attempt to find the item in the keychain
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        
        // If the item is found, return true; otherwise, return false
        return status == errSecSuccess
    }

    // MARK: - Private Helper Methods

    /// Delete the Secure Enclave key.
    private func deleteKey(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrLabel as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Delete encrypted data from the Keychain.
    private func deleteEncryptedData(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private func createOrRetrieveSecureEnclaveKey(forKey key: String, biometric: Bool) -> SecKey? {
        if biometric {
            guard laContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
                print("Biometric evaluation failed.")
                return nil
            }
        }
        if let existingKey = retrievePrivateKey(forKey: key, biometric: biometric) {
            return existingKey
        }
        print("Key not found. Creating a new Secure Enclave key...")
        return createSecureEnclaveKey(forKey: key, biometric: biometric)
    }

    private func retrievePrivateKey(forKey key: String, biometric: Bool) -> SecKey? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrLabel as String: key,
            kSecReturnRef as String: true
        ]

        if biometric {
            let context = createLAContext(biometric)
            query[kSecUseAuthenticationContext as String] = context
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            // Suppress unnecessary logs for a missing key during the first-time creation flow.
            return nil
        } else if status != errSecSuccess {
            print("Failed to retrieve private key with status \(status)")
            return nil
        }

        return (item as! SecKey)
    }

    /// Create a new Secure Enclave key with optional biometric authentication.
    private func createSecureEnclaveKey(forKey key: String, biometric: Bool) -> SecKey? {
        let flags : SecAccessControlCreateFlags = biometric ? [.privateKeyUsage, .userPresence] : [.privateKeyUsage]

        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            flags,
            nil
        ) else {
            print("Failed to create access control.")
            return nil
        }

        let query:[String : Any] = [
            kSecClass as String : kSecClassKey,
            kSecAttrKeyType as String : kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrTokenID as String : kSecAttrTokenIDSecureEnclave,
            kSecAttrLabel as String : key,
            kSecAttrAccessControl as String : accessControl
        ]

        var error : Unmanaged<CFError>?
        
        guard let newKey = SecKeyCreateRandomKey(query as CFDictionary, &error) else {
            print("Failed to create Secure Enclave key with error \(error?.takeRetainedValue() as Error?)")
            return nil
        }
        
        print("Successfully created Secure Enclave key.")
        return newKey
    }

   /// Encrypt data with the given public key.
   private func encryptData(_ data : Data , with publicKey : SecKey) -> Data? {
       var error : Unmanaged<CFError>?
       
       guard let encryptedData = SecKeyCreateEncryptedData(
           publicKey ,
           .eciesEncryptionStandardX963SHA256AESGCM ,
           data as CFData ,
           &error ) else {
               print("Encryption failed with error \(error?.takeRetainedValue() as Error?)")
               return nil
       }
       
       return encryptedData as Data
   }

    /// Save encrypted data to the Keychain.
    private func saveEncryptedData(_ data: Data, forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        // Define attributes to update if the item already exists
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        // Check if the item already exists in the keychain
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            // Update the existing item if it exists
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if updateStatus != errSecSuccess {
                print("Failed to update encrypted data with status \\(updateStatus)")
                return false
            }
        } else if status == errSecItemNotFound {
            // Add the item if it doesn't exist
            var newQuery = query
            newQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(newQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                print("Failed to save encrypted data with status \\(addStatus)")
                return false
            }
        } else {
            print("Failed to check keychain item with status \\(status)")
            return false
        }
        
        return true
   }

   /// Retrieve encrypted data from the Keychain.
   private func retrieveEncryptedData(forKey key:String) -> Data? {
       let query:[String : Any] = [
           kSecClass as String : kSecClassGenericPassword ,
           kSecAttrService as String : service ,
           kSecAttrAccount as String : key ,
           kSecReturnData as String : true ,
           kSecMatchLimit as String : kSecMatchLimitOne
       ]

       var dataTypeRef : AnyObject?
       let status = SecItemCopyMatching(query as CFDictionary , &dataTypeRef)

       if status != errSecSuccess {
           print("Failed to retrieve encrypted data with status \(status)")
       }
       
       return status == errSecSuccess ? dataTypeRef as? Data : nil
   }

   /// Create an LAContext for biometric authentication.
   private func createLAContext(_ biometric: Bool) -> LAContext {
       let context = LAContext()
       context.interactionNotAllowed = !biometric
       return context
   }
}
