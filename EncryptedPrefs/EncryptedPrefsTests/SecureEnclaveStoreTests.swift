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

    func testSaveDataSuccessfullyWithoutBiometricOrFallback() {
        mockLAContext.canEvaluatePolicyReturnValue = false  // Simulate no biometric or fallback

        let result = secureEnclaveStore.save(data: testData, forKey: testKey, biometric: false, hasPasscodeFallback: false)
        XCTAssertTrue(result, "Data should be saved successfully without biometric or fallback.")

        let retrievedData = secureEnclaveStore.retrieve(forKey: testKey, biometric: false, hasPasscodeFallback: false)
        XCTAssertNotNil(retrievedData, "Retrieved data should not be nil.")
        XCTAssertEqual(retrievedData, testData, "Retrieved data should match saved data.")
    }

    func testSaveDataSuccessfullyWithBiometricAndFallback() {
        mockLAContext.canEvaluatePolicyReturnValue = true  // Simulate successful evaluation

        let result = secureEnclaveStore.save(data: testData, forKey: testKey, biometric: true, hasPasscodeFallback: true)
        XCTAssertTrue(result, "Data should be saved successfully with biometric and fallback.")

        let retrievedData = secureEnclaveStore.retrieve(forKey: testKey, biometric: true, hasPasscodeFallback: true)
        XCTAssertNotNil(retrievedData, "Retrieved data should not be nil.")
        XCTAssertEqual(retrievedData, testData, "Retrieved data should match saved data.")
    }

    func testSaveFailsWithoutBiometricAndFallbackEnabled() {
        mockLAContext.canEvaluatePolicyReturnValue = false  // Simulate biometric failure

        let result = secureEnclaveStore.save(data: testData, forKey: testKey, biometric: true, hasPasscodeFallback: true)
        XCTAssertFalse(result, "Saving should fail when biometric evaluation fails and fallback is enabled but unavailable.")
    }

    func testRetrieveNonExistentData() {
        let retrievedData = secureEnclaveStore.retrieve(forKey: "NonExistentKey", biometric: false, hasPasscodeFallback: false)
        XCTAssertNil(retrievedData, "Retrieving non-existent data should return nil.")
    }

    func testDeleteDataSuccessfully() {
        // First save the data
        _ = secureEnclaveStore.save(data: testData, forKey: testKey, biometric: false, hasPasscodeFallback: false)

        // Now delete it
        let deleteResult = secureEnclaveStore.delete(forKey: testKey)
        XCTAssertTrue(deleteResult, "Data should be deleted successfully.")

        // Verify that the data is no longer retrievable
        let retrievedDataAfterDelete = secureEnclaveStore.retrieve(forKey: testKey, biometric: false, hasPasscodeFallback: false)
        XCTAssertNil(retrievedDataAfterDelete, "Retrieved data after deletion should be nil.")
    }

    func testDeleteNonExistentItem() {
        // Attempt to delete a non-existent item
        let deleteResult = secureEnclaveStore.delete(forKey: "NonExistentKey")
        XCTAssertTrue(deleteResult, "Deleting a non-existent item should return true.")
    }

    func testSaveAndRetrieveWithBiometricOnly() {
        mockLAContext.canEvaluatePolicyReturnValue = true  // Simulate successful biometric authentication

        let result = secureEnclaveStore.save(data: testData, forKey: testKey, biometric: true, hasPasscodeFallback: false)
        XCTAssertTrue(result, "Data should be saved successfully with biometric authentication only.")

        let retrievedData = secureEnclaveStore.retrieve(forKey: testKey, biometric: true, hasPasscodeFallback: false)
        XCTAssertNotNil(retrievedData, "Retrieved data should not be nil.")
        XCTAssertEqual(retrievedData, testData, "Retrieved data should match saved data.")
    }

    func testSaveFailsWithBiometricDisabled() {
        mockLAContext.canEvaluatePolicyReturnValue = true  // Simulate policy can be evaluated, but biometric is disabled

        let result = secureEnclaveStore.save(data: testData, forKey: testKey, biometric: false, hasPasscodeFallback: false)
        XCTAssertTrue(result, "Data should be saved successfully even if biometric is disabled.")
    }
}

