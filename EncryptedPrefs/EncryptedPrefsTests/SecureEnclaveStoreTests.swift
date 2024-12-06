import XCTest
import LocalAuthentication
@testable import EncryptedPrefs

final class SecureEnclaveStoreTests: XCTestCase {
    var store: SecureEnclaveStore!
    let testService = "com.example.secureenclave"
    
    override func setUp() {
        super.setUp()
        store = SecureEnclaveStore(service: testService)
    }

    override func tearDown() {
        _ = store.delete(forKey: "testKey")
        store = nil
        super.tearDown()
    }
    
    func testSaveAndRetrieveData() throws {
        let testData = "Hello Secure Enclave".data(using: .utf8)!
        let reason = "Test biometric authentication"

        // Save data
        XCTAssertNoThrow(try store.save(data: testData, forKey: "testKey", biometric: true, reason: reason))

        // Retrieve data
        let retrievedData = try store.retrieve(forKey: "testKey", biometric: true, reason: reason)
        XCTAssertEqual(retrievedData, testData, "Retrieved data should match the original data")
    }

    func testKeyExistsAfterSave() throws {
        let testData = "Secure Enclave Test".data(using: .utf8)!
        let reason = "Key existence check"

        // Save data
        XCTAssertNoThrow(try store.save(data: testData, forKey: "testKey", biometric: true, reason: reason))

        // Check if key exists
        XCTAssertTrue(store.keyExists(forKey: "testKey"), "Key should exist after saving data")
    }

    func testDeleteKey() throws {
        let testData = "Data to Delete".data(using: .utf8)!
        let reason = "Delete key test"

        // Save data
        XCTAssertNoThrow(try store.save(data: testData, forKey: "testKey", biometric: true, reason: reason))

        // Delete key
        XCTAssertTrue(store.delete(forKey: "testKey"), "Key should be deleted successfully")

        // Check if key still exists
        XCTAssertFalse(store.keyExists(forKey: "testKey"), "Key should not exist after deletion")
    }

    func testRetrieveNonExistentKey() {
        let reason = "Non-existent key test"

        XCTAssertThrowsError(try store.retrieve(forKey: "nonExistentKey", biometric: true, reason: reason)) { error in
            XCTAssertEqual(error as? SecureEnclaveError, .dataNotFound, "Retrieving a non-existent key should throw a dataNotFound error")
        }
    }
}

