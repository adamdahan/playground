//
//  MockLAContext.swift
//  EncryptedPrefs
//
//  Created by Adam Dahan on 2024-10-27.
//

import LocalAuthentication

class MockLAContext: LAContextProtocol {
    var canEvaluatePolicyReturnValue: Bool = false
    var evaluatePolicyReply: (success: Bool, error: Error?) = (false, nil)

    func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool {
        return canEvaluatePolicyReturnValue
    }

    func evaluatePolicy(_ policy: LAPolicy, localizedReason: String, reply: @escaping (Bool, Error?) -> Void) {
        reply(evaluatePolicyReply.success, evaluatePolicyReply.error)
    }

    var localizedFallbackTitle: String?
    var evaluatedPolicyDomainState: Data? {
        return nil
    }
}
