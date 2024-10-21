//
//  AddItemView.swift
//  EncryptedPrefs
//
//  Created by Adam Dahan on 2024-10-21.
//

import SwiftUI

struct AddItemView: View {
    
    @ObservedObject var viewModel: SecureStoreListViewModel
    
    @State private var key = ""
    @State private var value = ""
    @State private var selectedType: StorageTypeUI = .encryptedPreferences

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Key")) {
                    TextField("Enter key", text: $key)
                }
                Section(header: Text("Value")) {
                    TextField("Enter value", text: $value)
                }
                Section(header: Text("Storage Type")) {
                    Picker("Select Storage Type", selection: $selectedType) {
                        ForEach(StorageTypeUI.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationTitle("Add Item")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.showAddItemSheet = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.addItem(key: key, value: value, type: selectedType)
                            
                            await MainActor.run {
                                viewModel.showAddItemSheet = false
                            }
                        }
                    }
                }
            }
        }
    }
}
