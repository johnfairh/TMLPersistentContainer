//
//  TestLogging.swift
//  TMLPersistentContainer
//
//  Distributed under the ISC license, see LICENSE.
//

import XCTest
import CoreData
@testable import TMLPersistentContainer

// Tests that various log/print-related methods 'work' as in do not crash.
// Not testing the contents are sensible.

class TestLogging: TestCase {

    func testCanDescribeMigrationErrors() {
        let description = NSPersistentStoreDescription()
        let managedObjectModel = NSManagedObjectModel()
        let order = ModelVersionOrder.compare
        let source = "SOURCE"
        let destination = "DESTINATION"

        let e1 = MigrationError.coreqMigrationFailed(description)
        let e2 = MigrationError.badModelVersionOrder(description, order)
        let e3 = MigrationError.cannotFindSourceModel(description, [:])
        let e4 = MigrationError.cannotFindDestinationModel(description, managedObjectModel)
        let e5 = MigrationError.noRouteBetweenModels(source, destination)
        let e6 = MigrationError.cyclicRoute1(source, destination)
        let e7 = MigrationError.cyclicRoute2(source, destination)
        let e8 = MigrationError.cyclicRoute3(source, destination)
        let e9 = MigrationError.logicFailure(source)

        print("\(e1) \(e2) \(e3) \(e4) \(e5) \(e6) \(e7) \(e8), \(e9)")
    }

    func testCanUseDefaultLoggingHandler() {
        let _ = PersistentContainer(name: "Not a real model")
    }

    func testCanLogNodeDB() {
        let nodes = ModelVersionNodes(logMessageHandler: loggingCallback)
        nodes.discover(from: Bundle.allBundles)

        nodes.logMetadata(.error)
    }

    func testCanLogModelConfigWithMultipleEntities() {
        let container = createPersistentContainer(using: .TestModel_MultiConfig_1)
        print("\(container.managedObjectModel.entityHashDescription(forConfigurationName: nil))")
    }
}

