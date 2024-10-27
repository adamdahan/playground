//
//  SecureStoreListView.swift
//  EncryptedPrefs
//
//  Created by Adam Dahan on 2024-10-21.
//

import SwiftUI
import LocalAuthentication

struct SecureStoreListView: View {
    @StateObject private var viewModel: SecureStoreListViewModel

    init(viewModel: SecureStoreListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            List {
                if let errorString = viewModel.revealErrorString {
                    Text(errorString)
                        .font(.headline)
                        .foregroundColor(.red)
                }
                ForEach(viewModel.items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            
                            Text("Key: \(item.key)")
                                .font(.headline)

                            if item.isRevealed {
                                Text("Value: \(viewModel.revealedValues[item.key] ?? "******")")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Value: ******")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Text("Storage Type: \(item.storageType.rawValue)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer() // Push the button to the right

                        Button(item.isRevealed ? "Hide" : "Show") {
                            viewModel.toggleValueVisibility(for: item)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 8)
                }
                .onDelete(perform: viewModel.deleteItems) // Enable swipe-to-delete
            }
            .navigationTitle("Secure Store")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        viewModel.showAddItemSheet = true
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddItemSheet) {
                AddItemView(viewModel: viewModel)
            }
        }
    }
}

