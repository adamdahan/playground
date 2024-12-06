//
//  StoreError.swift
//  EncryptedPrefs
//
//  Created by Adam Dahan on 2024-10-21.
//

import Foundation

enum StoreError: Error {
    case keychainError(String)
    case encodingError
    case dataNotFound
    case userFallback
}
