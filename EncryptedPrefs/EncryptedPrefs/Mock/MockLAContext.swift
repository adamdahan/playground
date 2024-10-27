//
//  MockLAContext.swift
//  EncryptedPrefs
//
//  Created by Adam Dahan on 2024-10-27.
//

import LocalAuthentication

class MockLAContext: LAContextProtocol {
    var canEvaluatePolicyReturnValue = true
    var evaluatePolicyCompletionHandler : ((Bool, Error?) -> Void)?

    func canEvaluatePolicy(_ policy: LAPolicy, error _: NSErrorPointer) -> Bool {
        return canEvaluatePolicyReturnValue
    }

    func evaluatePolicy(_ policy: LAPolicy, localizedReason _: String, reply:@escaping (Bool, Error?) -> Void) {
        if let handler = evaluatePolicyCompletionHandler {
            handler(true, nil) // Default to success; you can customize this in tests.
        } else {
            reply(true, nil)
        }
    }
}
