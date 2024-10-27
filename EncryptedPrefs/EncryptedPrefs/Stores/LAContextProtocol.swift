//
//  LAContextProtocol.swift
//  EncryptedPrefs
//
//  Created by Adam Dahan on 2024-10-27.
//

import LocalAuthentication

/// Protocol for LAContext to enable mocking.
protocol LAContextProtocol {
    func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool
    func evaluatePolicy(_ policy: LAPolicy, localizedReason: String, reply: @escaping (Bool, Error?) -> Void)
}

/// Default implementation of LAContextProtocol using LAContext.
class LAContextWrapper: LAContextProtocol {
    private let context = LAContext()

    func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool {
        return context.canEvaluatePolicy(policy, error: error)
    }

    func evaluatePolicy(_ policy: LAPolicy, localizedReason: String, reply:@escaping (Bool, Error?) -> Void) {
        context.evaluatePolicy(policy, localizedReason: localizedReason, reply: reply)
    }
}

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
