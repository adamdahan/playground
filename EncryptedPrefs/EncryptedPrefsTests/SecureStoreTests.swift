//
//  SecureStoreTests.swift
//  EncryptedPrefsTests
//
//  Created by Adam Dahan on 2024-10-21.
//

@testable import EncryptedPrefs  // Replace `YourModuleName` with the name of your app/module
import XCTest
import LocalAuthentication

final class SecureStoreTests: XCTestCase {

    var secureStore: SecureStore!
    let service = "com.example.SecureStoreTest"
    let key = "testKey"
    let testData = "TestData".data(using: .utf8)!

    override func setUpWithError() throws {
        secureStore = SecureStore(service: service)
        // Ensure no existing key/value pair for a clean start.
        secureStore.delete(forKey: key)
    }

    override func tearDownWithError() throws {
        secureStore.delete(forKey: key)
    }

    func testSaveAndRetrieveDataFromKeychainWithoutBiometric() {
        let success = secureStore.save(data: testData, forKey: key, storageType: .keychain(biometric: false))
        XCTAssertTrue(success, "Failed to save data to Keychain")

        let retrievedData = secureStore.retrieve(forKey: key, storageType: .keychain(biometric: false))
        XCTAssertEqual(retrievedData, testData, "Retrieved data does not match saved data")
    }

    func testSaveAndRetrieveDataFromKeychainWithBiometric() {
        let context = LAContext()
        context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)

        let success = secureStore.save(data: testData, forKey: key, storageType: .keychain(biometric: true))
        XCTAssertTrue(success, "Failed to save data to Keychain with biometric")

        let retrievedData = secureStore.retrieve(forKey: key, storageType: .keychain(biometric: true), context: context)
        XCTAssertEqual(retrievedData, testData, "Retrieved data does not match saved data with biometric")
    }

    func testDeleteDataFromKeychain() {
        let success = secureStore.save(data: testData, forKey: key, storageType: .keychain(biometric: false))
        XCTAssertTrue(success, "Failed to save data to Keychain")

        let deletionSuccess = secureStore.delete(forKey: key)
        XCTAssertTrue(deletionSuccess, "Failed to delete data from Keychain")

        let retrievedData = secureStore.retrieve(forKey: key, storageType: .keychain(biometric: false))
        XCTAssertNil(retrievedData, "Data should be nil after deletion")
    }

    func testSaveAndRetrieveDataFromSecureEnclave() {
        let saveSuccess = secureStore.save(data: testData, forKey: key, storageType: .secureEnclave)
        XCTAssertTrue(saveSuccess, "Failed to save data to Secure Enclave")

        guard let retrievedData = secureStore.retrieve(forKey: key, storageType: .secureEnclave) else {
            XCTFail("Failed to retrieve data from Secure Enclave")
            return
        }

        XCTAssertEqual(retrievedData, testData, "Retrieved data does not match saved data from Secure Enclave")
    }

    func testDeleteDataFromSecureEnclave() {
        let success = secureStore.save(data: testData, forKey: key, storageType: .secureEnclave)
        XCTAssertTrue(success, "Failed to save data to Secure Enclave")

        let deletionSuccess = secureStore.delete(forKey: key)
        XCTAssertTrue(deletionSuccess, "Failed to delete data from Secure Enclave")

        let retrievedData = secureStore.retrieve(forKey: key, storageType: .secureEnclave)
        XCTAssertNil(retrievedData, "Data should be nil after deletion from Secure Enclave")
    }
}
