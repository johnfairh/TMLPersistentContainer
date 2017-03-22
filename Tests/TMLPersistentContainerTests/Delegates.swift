//
//  Delegates.swift
//  TMLPersistentContainer
//
//  Distributed under the ISC license, see LICENSE.
//

import XCTest
import CoreData
import Foundation
import TMLPersistentContainer

//
// Test scaffold to set expectations for delegate call-sequences.
//

enum DelegateCall {
    case willConsider
    case willMigrate(String, String, Int)
    case willNotMigrate(Bool)
    case willSingleMigrate(String, String, Bool, Int, Int)
    case didMigrate
    case didFailToMigrate
}

extension DelegateCall: Equatable {
    public static func ==(lhs: DelegateCall, rhs: DelegateCall) -> Bool {
        switch(lhs, rhs) {
        case (.willConsider, .willConsider):
            return true

        case (let .willMigrate(lhsFrom, lhsTo, lhsTotal), let .willMigrate(rhsFrom, rhsTo, rhsTotal)):
            return lhsFrom == rhsFrom && lhsTo == rhsTo && lhsTotal == rhsTotal

        case (let .willNotMigrate(lhsExists), let .willNotMigrate(rhsExists)):
            return lhsExists == rhsExists

        case (let .willSingleMigrate(lhsFrom, lhsTo, lhsInferred, lhsRemaining, lhsTotal),
              let .willSingleMigrate(rhsFrom, rhsTo, rhsInferred, rhsRemaining, rhsTotal)):
            return lhsFrom == rhsFrom &&
                lhsTo == rhsTo &&
                lhsInferred == rhsInferred &&
                lhsRemaining == rhsRemaining &&
                lhsTotal == rhsTotal

        case (.didMigrate, .didMigrate):
            return true

        case (.didFailToMigrate, .didFailToMigrate):
            // hmm Error is not equatable...
            return true

        default:
            return false
        }
    }
}

class Delegate: MigrationDelegate {

    private var expectedCalls: [DelegateCall] = []

    func resetExpectedCalls() {
        expectedCalls = []
    }

    func expectCall(_ call: DelegateCall) {
        expectedCalls.append(call)
    }

    func expectCalls(_ calls: [DelegateCall]) {
        expectedCalls = calls
    }

    func verify() {
        XCTAssertEqual(expectedCalls.count, 0)
    }

    private func checkCall(_ call: DelegateCall) {
        if expectedCalls.count == 0 {
            XCTFail("Got \(call) but not expecting anything")
        } else if expectedCalls[0] != call {
            XCTFail("Got \(call) but expected \(expectedCalls[0])")
        } else {
            expectedCalls = Array(expectedCalls.dropFirst(1))
        }
    }

    func persistentContainer(_ container: PersistentContainer,
                             willConsiderStore: NSPersistentStoreDescription) {
        checkCall(.willConsider)
    }

    func persistentContainer(_ container: PersistentContainer,
                             willMigrateStore: NSPersistentStoreDescription,
                             sourceModelVersion: String,
                             destinationModelVersion: String,
                             totalSteps: Int) {
        checkCall(.willMigrate(sourceModelVersion, destinationModelVersion, totalSteps))
    }

    func persistentContainer(_ container: PersistentContainer,
                             willNotMigrateStore: NSPersistentStoreDescription,
                             storeExists: Bool) {
        checkCall(.willNotMigrate(storeExists))
    }

    func persistentContainer(_ container: PersistentContainer,
                             willSingleMigrateStore: NSPersistentStoreDescription,
                             sourceModelVersion: String,
                             destinationModelVersion: String,
                             usingInferredMapping: Bool,
                             withMigrationManager: NSMigrationManager,
                             toTemporaryLocation: URL,
                             stepsRemaining: Int,
                             totalSteps: Int) {
        checkCall(.willSingleMigrate(sourceModelVersion, destinationModelVersion, usingInferredMapping, stepsRemaining, totalSteps))
    }

    func persistentContainer(_ container: PersistentContainer,
                             didMigrateStore: NSPersistentStoreDescription) {
        checkCall(.didMigrate)
    }

    func persistentContainer(_ container: PersistentContainer,
                             didFailToMigrateStore: NSPersistentStoreDescription,
                             error: Error) {
        checkCall(.didFailToMigrate)
    }
}
