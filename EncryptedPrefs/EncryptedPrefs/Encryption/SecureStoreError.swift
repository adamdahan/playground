//
//  SecureStoreError.swift
//  EncryptedPrefs
//
//  Created by Adam Dahan on 2024-10-21.
//

import Foundation

enum SecureStoreError: Error {
    case keychainError(String)
    case encodingError
    case dataNotFound
}