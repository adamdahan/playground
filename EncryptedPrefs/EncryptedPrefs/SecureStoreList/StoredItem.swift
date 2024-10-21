//
//  StoredItem.swift
//  EncryptedPrefs
//
//  Created by Adam Dahan on 2024-10-21.
//

import Foundation

struct StoredItem: Identifiable, Codable {
    var id = UUID()
    let key: String
    let storageType: StorageTypeUI
    var isRevealed: Bool = false
}
