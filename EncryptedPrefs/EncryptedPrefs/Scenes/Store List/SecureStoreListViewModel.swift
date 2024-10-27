//
//  SecureStoreViewModle.swift
//  EncryptedPrefs
//
//  Created by Adam Dahan on 2024-10-21.
//

import Foundation

@MainActor final class SecureStoreListViewModel: ObservableObject {
    
    @Published var items: [StoredItem] = []
    @Published var showAddItemSheet = false
    @Published var revealedValues: [String: String] = [:]
    @Published var revealErrorString: String?

    private let encryptedPlugin: EncryptedPreferencePluginInterface
    private let biometricsPlugin: EncryptedPreferencePluginInterface
    private let secureEnclavePlugin: EncryptedPreferencePluginInterface
    private let biometricsSecureEnclavePlugin: EncryptedPreferencePluginInterface

    private let itemsKey = "storedItems"  // Key for UserDefaults

    init(
        encryptedPlugin: EncryptedPreferencePluginInterface,
        biometricsPlugin: EncryptedPreferencePluginInterface,
        secureEnclavePlugin: EncryptedPreferencePluginInterface,
        biometricsSecureEnclavePlugin: EncryptedPreferencePluginInterface
    ) {
        self.encryptedPlugin = encryptedPlugin
        self.biometricsPlugin = biometricsPlugin
        self.secureEnclavePlugin = secureEnclavePlugin
        self.biometricsSecureEnclavePlugin = biometricsSecureEnclavePlugin

        loadItems()  // Load items on app launch
    }

    // MARK: - Add Item Logic

    func addItem(key: String, value: String, type: StorageType) async {
        do {
            switch type {
            case .encryptedPreferences:
                try await encryptedPlugin.putPreference(key: key, value: value)
            case .biometricsPreference:
                try await biometricsPlugin.putPreference(key: key, value: value)
            case .secureEnclavePreference:
                try await secureEnclavePlugin.putPreference(key: key, value: value)
            case .biometricsSecureEnclavePreference:
                try await biometricsSecureEnclavePlugin.putPreference(key: key, value: value)
            }

            let newItem = StoredItem(key: key, storageType: type)

            DispatchQueue.main.async {
                self.items.append(newItem)
                self.saveItems()  // Persist the updated list
            }
        } catch {
            print("Failed to save preference: \(error)")
        }
    }

    // MARK: - Toggle Visibility

    func toggleValueVisibility(for item: StoredItem) {
        if item.isRevealed {
            hideValue(for: item)
        } else {
            Task {
                await showValue(for: item)
            }
        }
    }

    private func hideValue(for item: StoredItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isRevealed = false
            revealedValues[item.key] = nil
            saveItems()  // Persist the change
        }
    }

    private func showValue(for item: StoredItem) async {
        do {
            let value: String

            switch item.storageType {
            case .encryptedPreferences:
                value = try await encryptedPlugin.getPreference(key: item.key, default: "******")
            case .biometricsPreference:
                value = try await biometricsPlugin.getPreference(key: item.key, default: "******")
            case .secureEnclavePreference:
                value = try await secureEnclavePlugin.getPreference(key: item.key, default: "******")
            case .biometricsSecureEnclavePreference:
                value = try await biometricsSecureEnclavePlugin.getPreference(key: item.key, default: "******")
            }

            DispatchQueue.main.async {
                if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                    self.items[index].isRevealed = true
                    self.revealedValues[item.key] = value
                    self.saveItems()  // Persist the change
                }
            }
        } catch {
            self.revealErrorString = "Failed to retrieve preference: \(error)"
        }
    }
    
    // MARK: - Delete Items Logic

    func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = items[index]

            // Delete the item from the secure store
            Task {
                do {
                    try await deleteFromStore(item: item)
                    DispatchQueue.main.async {
                        self.items.remove(at: index)
                        self.saveItems()  // Persist the updated list
                    }
                } catch {
                    print("Failed to delete item: \(error)")
                }
            }
        }
    }

    private func deleteFromStore(item: StoredItem) async throws {
        switch item.storageType {
        case .encryptedPreferences:
            try await encryptedPlugin.removePreference(key: item.key)
        case .biometricsPreference:
            try await biometricsPlugin.removePreference(key: item.key)
        case .secureEnclavePreference:
            try await secureEnclavePlugin.removePreference(key: item.key)
        case .biometricsSecureEnclavePreference:
            try await biometricsSecureEnclavePlugin.removePreference(key: item.key)
        }
    }

    // MARK: - Persistence Logic

    private func saveItems() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: itemsKey)
        } catch {
            print("Failed to save items: \(error)")
        }
    }

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: itemsKey) else { return }
        do {
            items = try JSONDecoder().decode([StoredItem].self, from: data)
        } catch {
            print("Failed to load items: \(error)")
        }
    }
}
