//
//  SecureEnclaveStoreTests.swift
//  EncryptedPrefsTests
//
//  Created by Adam Dahan on 2024-10-27.
//

import XCTest
@testable import EncryptedPrefs

// Do not run these tests in the simulator. There is no secure enclave in iOS simulator.

class SecureEnclaveStoreTests: XCTestCase {

    var secureEnclaveStore: SecureEnclaveStore!
    var mockLAContext: MockLAContext!
    
    let testService = "TestService"
    let testKey = "TestKey"
    let testData = "TestData".data(using: .utf8)!

    override func setUp() {
        super.setUp()
        
        mockLAContext = MockLAContext()
        secureEnclaveStore = SecureEnclaveStore(service: testService, laContext: mockLAContext)
        
        // Clean up any existing data before each test
        let _ = secureEnclaveStore.delete(forKey: testKey)
    }

    override func tearDown() {
        // Clean up any stored data after each test
        let _ = secureEnclaveStore.delete(forKey: testKey)
        secureEnclaveStore = nil
        mockLAContext = nil
        super.tearDown()
    }

    func testSaveDataSuccessfully() {
        mockLAContext.canEvaluatePolicyReturnValue = true  // Simulate successful evaluation

        let result = secureEnclaveStore.save(data: testData, forKey: testKey, biometric: false)
        XCTAssertTrue(result, "Data should be saved successfully.")

        // Verify that the data can be retrieved correctly
        let retrievedData = secureEnclaveStore.retrieve(forKey: testKey, biometric: false)
        XCTAssertNotNil(retrievedData, "Retrieved data should not be nil.")
        XCTAssertEqual(retrievedData, testData, "Retrieved data should match saved data.")
    }

    func testRetrieveNonExistentData() {
        let retrievedData = secureEnclaveStore.retrieve(forKey: "NonExistentKey", biometric: false)
        XCTAssertNil(retrievedData, "Retrieving non-existent data should return nil.")
    }

    func testDeleteDataSuccessfully() {
        // First save the data
        _ = secureEnclaveStore.save(data: testData, forKey: testKey, biometric: false)

        // Now delete it
        let deleteResult = secureEnclaveStore.delete(forKey: testKey)
        XCTAssertTrue(deleteResult, "Data should be deleted successfully.")

        // Verify that the data is no longer retrievable
        let retrievedDataAfterDelete = secureEnclaveStore.retrieve(forKey: testKey, biometric: false)
        XCTAssertNil(retrievedDataAfterDelete, "Retrieved data after deletion should be nil.")
    }

    func testBiometricAuthenticationFailureOnSave() {
        mockLAContext.canEvaluatePolicyReturnValue = false  // Simulate biometric failure

        let result = secureEnclaveStore.save(data: testData, forKey: testKey, biometric: true)
        XCTAssertFalse(result, "Saving should fail when biometric evaluation fails.")
    }

    /// This will fail miserably in the simulator.
    func testBiometricAuthenticationSuccessOnSave() {
        mockLAContext.canEvaluatePolicyReturnValue = true  // Simulate successful evaluation

        let result = secureEnclaveStore.save(data: testData, forKey: testKey, biometric: true)
        
        XCTAssertTrue(result, "Data should be saved successfully with biometric authentication.")

        // Verify that the data can be retrieved correctly
        let retrievedData = secureEnclaveStore.retrieve(forKey: testKey, biometric: true)
        
        XCTAssertNotNil(retrievedData, "Retrieved data should not be nil.")
        
        if let retrievedData = retrievedData {
            XCTAssertEqual(retrievedData, testData, "Retrieved data should match saved data.")
        } else {
            XCTFail("Failed to retrieve data after saving.")
        }
    }

    func testDeleteNonExistentItem() {
        // Attempt to delete a non-existent item
        let deleteResult = secureEnclaveStore.delete(forKey: "NonExistentKey")
        XCTAssertTrue(deleteResult, "Deleting a non-existent item should return true.")
    }
}
