//
//  EncryptedPrefsApp.swift
//  EncryptedPrefs
//
//  Created by Adam Dahan on 2024-10-21.
//

import SwiftUI

@main
struct EncryptedPrefsApp: App {
    var body: some Scene {
        WindowGroup {
            SecureStoreListView(
                viewModel: SecureStoreListViewModel(
                    encryptedPlugin: EncryptedPreferencePlugin(),
                    biometricsPlugin: BiometricsPreferencePlugin(),
                    secureEnclavePlugin: SecureEnclavePreferencePlugin(),
                    biometricsSecureEnclavePlugin: BiometricsSecureEnclavePreferencePlugin()
                )
            )
        }
    }
}
