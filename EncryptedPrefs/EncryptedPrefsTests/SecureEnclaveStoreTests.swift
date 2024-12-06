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

        do {
            try secureEnclaveStore.save(data: testData, forKey: testKey, biometric: false, hasPasscodeFallback: false)
            let retrievedData = try secureEnclaveStore.retrieve(forKey: testKey, biometric: false, hasPasscodeFallback: false)
            XCTAssertNotNil(retrievedData, "Retrieved data should not be nil.")
            XCTAssertEqual(retrievedData, testData, "Retrieved data should match saved data.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSaveDataSuccessfullyWithBiometricAndFallback() {
        mockLAContext.canEvaluatePolicyReturnValue = true  // Simulate successful evaluation

        do {
            try secureEnclaveStore.save(data: testData, forKey: testKey, biometric: true, hasPasscodeFallback: true)
            let retrievedData = try secureEnclaveStore.retrieve(forKey: testKey, biometric: true, hasPasscodeFallback: true)
            XCTAssertNotNil(retrievedData, "Retrieved data should not be nil.")
            XCTAssertEqual(retrievedData, testData, "Retrieved data should match saved data.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSaveFailsWithoutBiometricAndFallbackEnabled() {
        mockLAContext.canEvaluatePolicyReturnValue = false  // Simulate biometric failure

        XCTAssertThrowsError(try secureEnclaveStore.save(data: testData, forKey: testKey, biometric: true, hasPasscodeFallback: true)) { error in
            guard case SecureEnclaveError.biometricNotAvailable = error else {
                XCTFail("Expected biometricNotAvailable error, but got \(error)")
                return
            }
        }
    }

    func testRetrieveNonExistentData() {
        XCTAssertThrowsError(try secureEnclaveStore.retrieve(forKey: "NonExistentKey", biometric: false, hasPasscodeFallback: false)) { error in
            guard case SecureEnclaveError.dataNotFound = error else {
                XCTFail("Expected dataNotFound error, but got \(error)")
                return
            }
        }
    }

    func testDeleteDataSuccessfully() {
        // First save the data
        do {
            try secureEnclaveStore.save(data: testData, forKey: testKey, biometric: false, hasPasscodeFallback: false)
            let deleteResult = secureEnclaveStore.delete(forKey: testKey)
            XCTAssertTrue(deleteResult, "Data should be deleted successfully.")

            XCTAssertThrowsError(try secureEnclaveStore.retrieve(forKey: testKey, biometric: false, hasPasscodeFallback: false)) { error in
                guard case SecureEnclaveError.dataNotFound = error else {
                    XCTFail("Expected dataNotFound error, but got \(error)")
                    return
                }
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDeleteNonExistentItem() {
        let deleteResult = secureEnclaveStore.delete(forKey: "NonExistentKey")
        XCTAssertTrue(deleteResult, "Deleting a non-existent item should return true.")
    }

    func testSaveAndRetrieveWithBiometricOnly() {
        mockLAContext.canEvaluatePolicyReturnValue = true  // Simulate successful biometric authentication

        do {
            try secureEnclaveStore.save(data: testData, forKey: testKey, biometric: true, hasPasscodeFallback: false)
            let retrievedData = try secureEnclaveStore.retrieve(forKey: testKey, biometric: true, hasPasscodeFallback: false)
            XCTAssertNotNil(retrievedData, "Retrieved data should not be nil.")
            XCTAssertEqual(retrievedData, testData, "Retrieved data should match saved data.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSaveFailsWithBiometricDisabled() {
        mockLAContext.canEvaluatePolicyReturnValue = true  // Simulate policy can be evaluated, but biometric is disabled

        do {
            try secureEnclaveStore.save(data: testData, forKey: testKey, biometric: false, hasPasscodeFallback: false)
            let retrievedData = try secureEnclaveStore.retrieve(forKey: testKey, biometric: false, hasPasscodeFallback: false)
            XCTAssertNotNil(retrievedData, "Retrieved data should not be nil.")
            XCTAssertEqual(retrievedData, testData, "Retrieved data should match saved data.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

