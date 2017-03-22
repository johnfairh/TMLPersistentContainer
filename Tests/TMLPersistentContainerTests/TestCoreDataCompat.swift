//
//  TestCoreDataCompat.swift
//  TMLPersistentContainer
//
//  Distributed under the ISC license, see LICENSE.
//

import XCTest
import CoreData
import Foundation
import TMLPersistentContainer

/// Tests to verify compatibility between stock core data algorithms and TML ones.
class TestCoreDataCompat: TestCase {

    class Constants {
        static let ObjectName  = "Object"
        static let StoreName   = ModelName.TestModel_Simple_1.rawValue
        static let EntityCount = 1
        static let ObjectCount = 1
    }

    /// Test the 1-arg version of NSPersistentContainer.init() is compatible with the
    /// equivalent one in TML.
    ///
    /// ACKSHURLY this isn't possible right now because NSPC.init() looks in the main
    /// bundle which under XCTest is something crazy.  Need to write another target app
    /// I guess?
    func SKIP_testCanLocateObjectModel() {

        deleteFilesForStore(name: Constants.StoreName)

        setUpCoreDataStore()

        verifyTMLStore()
    }

    private func verifyTMLStore() {
        let container = PersistentContainer(name: Constants.StoreName)

        XCTAssertEqual(Constants.EntityCount, container.managedObjectModel.entities.count)

        do {
            try loadStores(for: container)
        } catch {
            XCTFail("Unexpected error loading store \(error)")
        }

        let objects = SimpleModel.getAllObjectsV1(context: container.viewContext)
        XCTAssertEqual(objects.count, Constants.ObjectCount)
        XCTAssertEqual(objects[0].id, Constants.ObjectName)
    }

    private func setUpCoreDataStore() {
        let cdContainer = NSPersistentContainer(name: Constants.StoreName)

        XCTAssertEqual(Constants.EntityCount, cdContainer.managedObjectModel.entities.count)

        do {
            try loadStores(for: cdContainer)
        } catch {
            XCTFail("Unexpected error loading store \(error)")
        }

        _ = SimpleModel.createV1(id: Constants.ObjectName, context: cdContainer.viewContext)
        saveChanges(container: cdContainer)
    }
}
