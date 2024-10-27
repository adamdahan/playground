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
    func save(data: Data, forKey key: String, biometric: Bool) -> Bool {
        if biometric && !laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
            print("Biometric authentication is not available.")
            return false
        }

        guard let accessControl = createAccessControl(biometric: biometric) else {
            print("Failed to create access control.")
            return false
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl,
            kSecUseAuthenticationContext as String: createLAContext(biometric)
        ]

        SecItemDelete(query as CFDictionary) // Avoid duplicates.

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Keychain save failed with status: \(status)")
        }

        return status == errSecSuccess
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
