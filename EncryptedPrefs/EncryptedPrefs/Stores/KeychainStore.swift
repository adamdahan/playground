import Foundation
import LocalAuthentication
import Security

/// Manages Keychain operations including saving, retrieving, and deleting items.
class KeychainStore {

    // MARK: - Properties
    private let service: String
    private var laContext: LAContextProtocol

    // MARK: - Initializer
    init(service: String, laContext: LAContextProtocol = LAContextWrapper()) {
        self.service = service
        self.laContext = laContext
    }

    // MARK: - Public Methods

    /// Save data to the Keychain.
    /// Save data to the Keychain.
    /// Save data to the Keychain.
    func save(data: Data, forKey key: String, biometric: Bool) -> Bool {
        
        if biometric && !laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
            print("Biometric authentication is not available.")
            return false
        }

        guard let accessControl = createAccessControl(biometric: biometric) else {
            print("Failed to create access control.")
            return false
        }

        // Create the base query with service and key.
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        // Add the access control attribute only if biometric is enabled.
        if biometric {
            query[kSecAttrAccessControl as String] = accessControl
        }

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecUseAuthenticationContext as String: createLAContext(biometric)
        ]

        // Check if the item already exists with the same attributes.
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            // Update the existing keychain item.
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if updateStatus != errSecSuccess {
                print("Keychain update failed with status: \(updateStatus)")
                return false
            }
        } else if status == errSecItemNotFound {
            // If it doesn't exist, add the new item.
            var combinedQuery = query
            attributes.forEach { combinedQuery[$0.key] = $0.value }
            
            let addStatus = SecItemAdd(combinedQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                print("Keychain save failed with status: \(addStatus)")
                return false
            }
        } else {
            print("Keychain lookup failed with status: \(status)")
            return false
        }

        return true
    }

    /// Retrieve data from the Keychain.
    func retrieve(forKey key: String, biometric: Bool) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: createLAContext(biometric)
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status != errSecSuccess {
            print("Keychain retrieve failed with status: \(status)")
        }

        return status == errSecSuccess ? dataTypeRef as? Data : nil
    }

    /// Delete an item from the Keychain.
    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Private Helper Methods

    /// Create access control for Keychain items.
    private func createAccessControl(biometric: Bool) -> SecAccessControl? {
        let flags: SecAccessControlCreateFlags = biometric ? [.userPresence] : []
        return SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenUnlocked, flags, nil)
    }

    /// Create an LAContext for biometric authentication.
    private func createLAContext(_ biometric: Bool) -> LAContext {
        let context = LAContext()
        context.interactionNotAllowed = !biometric
        return context
    }
}
