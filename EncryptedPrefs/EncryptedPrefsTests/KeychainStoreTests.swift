import XCTest
@testable import EncryptedPrefs

class KeychainStoreTests: XCTestCase {

    var keychainStore: KeychainStore!
    var mockLAContext: MockLAContext!
    
    let testService = "TestService"
    let testKey = "TestKey"
    let testData = "TestData".data(using: .utf8)!

    override func setUp() {
        super.setUp()
        
        mockLAContext = MockLAContext()
        keychainStore = KeychainStore(service: testService, laContext: mockLAContext) // Corrected line
        
        // Clean up any existing data before each test
        let _ = keychainStore.delete(forKey: testKey)
    }

   override func tearDown() {
       // Clean up any stored data after each test
       let _ = keychainStore.delete(forKey:testKey)
       keychainStore = nil
       mockLAContext = nil
       super.tearDown()
   }

   func testSaveDataSuccessfully() {
       mockLAContext.canEvaluatePolicyReturnValue = true  // Simulate successful evaluation

       let result = keychainStore.save(data:testData, forKey:testKey, biometric:false)
       XCTAssertTrue(result,"Data should be saved successfully.")

       // Verify that the data was saved correctly
       let retrievedData = keychainStore.retrieve(forKey:testKey, biometric:false)
       XCTAssertEqual(retrievedData,testData,"Retrieved data should match saved data.")
   }

   func testRetrieveNonExistentData() {
       let retrievedData = keychainStore.retrieve(forKey:"NonExistentKey", biometric:false)
       XCTAssertNil(retrievedData,"Retrieving non-existent data should return nil.")
   }

   func testDeleteDataSuccessfully() {
       // First save the data
       _ = keychainStore.save(data:testData, forKey:testKey, biometric:false)

       // Now delete it
       let deleteResult = keychainStore.delete(forKey:testKey)
       XCTAssertTrue(deleteResult,"Data should be deleted successfully.")

       // Verify that the data is no longer retrievable
       let retrievedDataAfterDelete = keychainStore.retrieve(forKey:testKey, biometric:false)
       XCTAssertNil(retrievedDataAfterDelete,"Retrieved data after deletion should be nil.")
   }

   func testSaveWithBiometricAccessControl() {
       mockLAContext.canEvaluatePolicyReturnValue = true  // Simulate successful evaluation

       let result = keychainStore.save(data:testData, forKey:testKey, biometric:true)
       XCTAssertTrue(result,"Data should be saved successfully with biometric access control.")

       // Verify that the data was saved correctly
       let retrievedData = keychainStore.retrieve(forKey:testKey, biometric:true)
       XCTAssertEqual(retrievedData,testData,"Retrieved data should match saved data.")
   }

   func testBiometricAuthenticationFailure() {
       mockLAContext.canEvaluatePolicyReturnValue = false  // Simulate failure in evaluating policy

       let result = keychainStore.save(data: testData, forKey:testKey, biometric: true)
       XCTAssertFalse(result,"Saving should fail when biometric evaluation fails.")
   }

   func testDeleteNonExistentItem() {
       // Attempt to delete a non-existent item
       let deleteResult = keychainStore.delete(forKey:"NonExistentKey")
       XCTAssertTrue(deleteResult,"Deleting a non-existent item should return true.")
   }
}
