//
//  TMLPersistentContainerTests.swift
//  TMLPersistentContainerTests
//
//  Created by John Fairhurst on 05/01/2017.
//  Copyright © 2017 Too Many Ladybirds. All rights reserved.
//

import Foundation
import CoreData
import XCTest
import TMLPersistentContainer

/// These are tests of the test environment helpers and PersistentContainer.destroyStore().
/// No migrations here.
class TestCreateDelete: TestCase {
    
    /// Arbitrary constants for these tests
    struct Constants {
        static let V2_ID = Int32(23)
        static let ModelVersion = ModelName.TestModel_Simple_2
        static let EntityCount = 1
    }

    /// Helper: put something in the on-disk store
    private func makeStoreNonEmpty() {
        let container = createAndLoadStore(using: Constants.ModelVersion, makeEmpty: true)
        
        _ = SimpleModel.createV2(id: Constants.V2_ID, context: container.viewContext)
        saveChanges(container: container)
    }
    
    /// Helper: Check the number of objects that exist
    private func checkObjectCount(in container: PersistentContainer, expected: Int) {
        let actual = SimpleModel.getObjectCount(context: container.viewContext)
        XCTAssertEqual(actual, expected, "Store contains \(actual) objects expected \(expected)")
    }

    func testCanCreateStoreAsync() {
        deleteFilesForStore()

        let migDelegate = Delegate()
        migDelegate.expectCalls([.willConsider, .willNotMigrate(false)])

        let container = createAndLoadStore(using: Constants.ModelVersion, delegate: migDelegate)
        checkObjectCount(in: container, expected: 0)
    }

    func testCanCreateStoreSync() {
        deleteFilesForStore()

        let migDelegate = Delegate()
        migDelegate.expectCalls([.willConsider, .willNotMigrate(false)])

        let container = createAndLoadStore(using: Constants.ModelVersion, delegate: migDelegate, addAsync: false)
        checkObjectCount(in: container, expected: 0)
    }

    func testCanLoadEmptyStore() {
        let migDelegate = Delegate()
        migDelegate.expectCalls([.willConsider, .willNotMigrate(false)])

        let container = createAndLoadStore(using: Constants.ModelVersion, makeEmpty: true, delegate: migDelegate)
        checkObjectCount(in: container, expected: 0)
        migDelegate.verify()
    }
    
    func testCanLoadNonEmptyStore() {
        makeStoreNonEmpty()

        let migDelegate = Delegate()
        migDelegate.expectCalls([.willConsider, .willNotMigrate(true)])

        let container = createAndLoadStore(using: Constants.ModelVersion, delegate: migDelegate)
        checkObjectCount(in: container, expected: 1)
        migDelegate.verify()
    }
    
    func testCanMakeStoreEmpty() {
        makeStoreNonEmpty()
        
        let container = createAndLoadStore(using: Constants.ModelVersion, makeEmpty: true)
        checkObjectCount(in: container, expected: 0)
    }

    func testCannotFindModel() {
        let container = PersistentContainer(name: ModelName.NonExistentModel.rawValue,
                                            logMessageHandler: { msg in print("LOG: \(msg)") })

        let mom = container.managedObjectModel

        XCTAssertEqual(mom.entities.count, 0)
    }

    func testCanAutomaticallyFindModel() {
        deleteFilesForStore(name: Constants.ModelVersion.rawValue)

        let container = PersistentContainer(name: Constants.ModelVersion.rawValue,
                                            bundles: Bundle.allBundles,
                                            logMessageHandler: { msg in print("LOG: \(msg)") })

        XCTAssertEqual(Constants.EntityCount, container.managedObjectModel.entities.count)

        do {
            try loadStores(for: container)
        } catch {
            XCTFail("Unexpected error loading store \(error)")
        }
    }

    func testCanSurviveCorruptModel() {
        let container = PersistentContainer(name: ModelName.TestModel_NotA.rawValue,
                                            bundles: Bundle.allBundles,
                                            logMessageHandler: { msg in print("LOG: \(msg)") })

        XCTAssertEqual(container.managedObjectModel.entities.count, 0)
    }

    func testCanHandleNoStoresToLoad() {
        let container = createAndLoadStore(using: Constants.ModelVersion, makeEmpty: true)

        let doneExpectation = expectation(description: "Store loaded")

        container.loadPersistentStores { _, error in
            if error == nil {
                // expect core data to get upset about adding a store twice here.
                XCTFail("Should not have worked")
            }
            doneExpectation.fulfill()
        }

        waitForExpectations(timeout: 1000) // sure
    }
}
