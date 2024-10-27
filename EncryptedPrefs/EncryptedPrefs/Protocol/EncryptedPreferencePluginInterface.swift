//
//  EncryptedPreferencePluginInterface.swift
//  EncryptedPrefs
//
//  Created by Adam Dahan on 2024-10-21.
//

import Foundation

protocol EncryptedPreferencePluginInterface {
    func getPreference(key: String, default: String) async throws -> String
    func putPreference(key: String, value: String) async throws
    func hasPreference(key: String) async throws -> Bool
    func removePreference(key: String) async throws
}
