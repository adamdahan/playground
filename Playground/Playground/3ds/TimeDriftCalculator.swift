//
//  TimeDriftCalculator.swift
//  Playground
//
//  Created by Adam Dahan on 2024-08-28.
//

import Foundation

class TimeDriftCalculator {

    private let serverTimeKey = "cachedServerTime"
    
    // Save server time to UserDefaults (or any other persistent storage)
    func cacheServerTime(_ serverTime: String) {
        UserDefaults.standard.set(serverTime, forKey: serverTimeKey)
    }

    // Retrieve cached server time
    func getCachedServerTime() -> Date? {
        guard let serverTimeString = UserDefaults.standard.string(forKey: serverTimeKey),
              let serverTime = ISO8601DateFormatter().date(from: serverTimeString) else {
            return nil
        }
        return serverTime
    }

    // Get the local device time
    func getLocalDeviceTime() -> Date {
        return Date()
    }

    // Calculate the drift between the local time and the cached server time
    func calculateDrift() -> TimeInterval? {
        guard let cachedServerTime = getCachedServerTime() else {
            print("No cached server time available")
            return nil
        }
        let localDeviceTime = getLocalDeviceTime()
        return localDeviceTime.timeIntervalSince(cachedServerTime)
    }

    // Compare the drift with the expiry time
    func isDriftWithinExpiry(expiryTime: Date) -> Bool {
        guard let drift = calculateDrift() else {
            return false
        }
        // Here, you should define the maximum allowed drift based on your requirements
        let maximumAllowedDrift: TimeInterval = 60 // Example: 60 seconds

        return abs(drift) <= maximumAllowedDrift && Date().addingTimeInterval(drift) <= expiryTime
    }
}

//// Usage
//let calculator = TimeDriftCalculator()
//
//// Step 1: Cache the server time (this would be done when receiving the API response)
//let serverTime = "2024-07-04T13:35:01.362-04:00" // Example server time
//calculator.cacheServerTime(serverTime)
//
//// Step 2: Calculate the drift
//if let drift = calculator.calculateDrift() {
//    print("Drift between local and server time: \(drift) seconds")
//}
//
//// Step 3: Check if drift is within the expiry time
//let expiryTime = ISO8601DateFormatter().date(from: "2024-07-04T14:00:00.000-04:00")! // Example expiry time
//if calculator.isDriftWithinExpiry(expiryTime: expiryTime) {
//    print("Drift is within the expiry time")
//} else {
//    print("Drift exceeds the expiry time")
//}
