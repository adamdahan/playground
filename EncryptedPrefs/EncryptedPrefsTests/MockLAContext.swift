//
//  MockLAContext.swift
//  EncryptedPrefsTests
//
//  Created by Adam Dahan on 2024-10-21.
//

import LocalAuthentication

class MockLAContext: LAContext {
    var shouldSucceed = true

    override func evaluatePolicy(
        _ policy: LAPolicy,
        localizedReason: String,
        reply: @escaping (Bool, Error?) -> Void
    ) {
        if shouldSucceed {
            reply(true, nil)
        } else {
            reply(false, LAError(.authenticationFailed))
        }
    }
}
