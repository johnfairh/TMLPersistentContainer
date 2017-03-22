//
//  TestSimpleMigrate.swift
//  TMLPersistentContainer
//
//  Distributed under the ISC license, see LICENSE.
//

import XCTest
import CoreData
@testable import TMLPersistentContainer

///
/// Basic tests for store migration.
///
/// Use the SimpleModel, which has three versions such that:
///   V1->V2 requires and has a mapping model
///   V2->V3 can be auto-migrated and has no mapping model
///
/// So we test here that these two steps can be made invididually, and then finally that
/// TMLPersistentContainer is able to infer the steps required to perform V1->V3.
///

///
/// Migration policy for V1->V2.
/// Turn the 'id' property from a string into an Int32.
///
class SimpleItemMigrationPolicy1to2: NSEntityMigrationPolicy {
    override func createDestinationInstances(forSource sInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)
        
        let dInstances = manager.destinationInstances(forEntityMappingName: mapping.name, sourceInstances: [sInstance])
        guard dInstances.count > 0 else {
            fatalError("Confused, can't find destination instance")
        }
        let dInstance = dInstances[0]
        
        guard let v1id = sInstance.value(forKey: #keyPath(SimpleItem_1.id)) as? String else {
            fatalError("Can't read V1 id string from \(sInstance)")
        }
            
        let v2id = Int32(v1id)!
        
        dInstance.setValue(NSNumber(value: v2id), forKey: #keyPath(SimpleItem_2.id))
    }
}

class TestSimpleMigrate: TestCase {
    
    /// Arbitrary constants for these testcases
    struct Constants {
        static let OBJ1_V1_ID = "28"
        static let OBJ1_V2_ID = Int32(OBJ1_V1_ID)!
        static let OBJ1_V3_COUNT = Int32(0)
        
        static let OBJ2_V1_ID = "1445"
        static let OBJ2_V2_ID = Int32(OBJ2_V1_ID)!
        static let OBJ2_V3_COUNT = Int32(0)
        
        static let OBJ_COUNT = 2
    }
    
    /// Helper - populate the store at V1
    private func populateStoreV1(storeType: String = NSSQLiteStoreType) {
        let container = createAndLoadStore(using: .TestModel_Simple_1, makeEmpty: true, storeType: storeType)
        _ = SimpleModel.createV1(id: Constants.OBJ1_V1_ID, context: container.viewContext)
        _ = SimpleModel.createV1(id: Constants.OBJ2_V1_ID, context: container.viewContext)
        saveChanges(container: container)
    }
    
    /// Helper - populate the store at V2
    private func populateStoreV2(storeType: String) -> PersistentContainer {
        let container = createAndLoadStore(using: .TestModel_Simple_2, makeEmpty: true, storeType: storeType)
        _ = SimpleModel.createV2(id: Constants.OBJ1_V2_ID, context: container.viewContext)
        _ = SimpleModel.createV2(id: Constants.OBJ2_V2_ID, context: container.viewContext)
        saveChanges(container: container)
        return container
    }

    private func populateStoreV2() {
        _ = populateStoreV2(storeType: NSSQLiteStoreType)
    }

    /// Helper - verify the store at V2
    private func verifyStoreV2(container: PersistentContainer) {
        let objects = SimpleModel.getAllObjectsV2(context: container.viewContext).sorted { $0.id < $1.id }
        
        XCTAssertEqual(objects.count, Constants.OBJ_COUNT, "Bad number of objects in V2 store")

        XCTAssertEqual(objects[0].id, Constants.OBJ1_V2_ID, "Object 1 has bad ID in V2 store")
        XCTAssertEqual(objects[1].id, Constants.OBJ2_V2_ID, "Object 2 has bad ID in V2 store")
    }
    
    /// Helper - verify the store at V3
    private func verifyStoreV3(container: PersistentContainer) {
        let objects = SimpleModel.getAllObjectsV3(context: container.viewContext).sorted { $0.id < $1.id }
        
        XCTAssertEqual(objects.count, Constants.OBJ_COUNT, "Bad number of objects in V3 store")

        XCTAssertEqual(objects[0].id, Constants.OBJ1_V2_ID, "Object 1 has bad ID in V3 store")
        XCTAssertEqual(objects[0].count, Constants.OBJ1_V3_COUNT, "Object 1 has bad count")
        
        XCTAssertEqual(objects[1].id, Constants.OBJ2_V2_ID, "Object 2 has bad ID in V3 store")
        XCTAssertEqual(objects[1].count, Constants.OBJ2_V3_COUNT, "Object 2 has bad count")
    }
   
    
    func testCanMigrateV1toV2usingMappingModel() {
        populateStoreV1()
        
        let v2container = createAndLoadStore(using: .TestModel_Simple_2)
        
        verifyStoreV2(container: v2container)
    }
    
    func testCanMigrateV2toV3automatically() {
        populateStoreV2()
        
        let v3container = createAndLoadStore(using: .TestModel_Simple_3)
        
        verifyStoreV3(container: v3container)
    }

    func testCanMigrateV2toV3automaticallyNativeCoreData() {
        populateStoreV2()

        let v3container = createNsPersistentContainer(using: .TestModel_Simple_3)

        let doneExpectation = expectation(description: "Store loaded")

        v3container.loadPersistentStores { description, error in
            if let error = error {
                XCTFail("Error loading store: \(error)")
            }
            doneExpectation.fulfill()
        }

        waitForExpectations(timeout: 1000) // sure
    }

    func testCanMigrateV1toV3inTwoSteps() {
        populateStoreV1()

        let migDelegate = Delegate()
        migDelegate.expectCalls([.willConsider,
                                 .willMigrate(ModelName.TestModel_Simple_1.rawValue, ModelName.TestModel_Simple_3.rawValue, 2),
                                 .willSingleMigrate(ModelName.TestModel_Simple_1.rawValue, ModelName.TestModel_Simple_2.rawValue, false, 2, 2),
                                 .willSingleMigrate(ModelName.TestModel_Simple_2.rawValue, ModelName.TestModel_Simple_3.rawValue, true, 1, 2),
                                 .didMigrate])
        
        let v3container = createAndLoadStore(using: .TestModel_Simple_3, delegate: migDelegate)
        
        verifyStoreV3(container: v3container)
        migDelegate.verify()
    }

    func testCanHonorDoNotMigrateAutomatically() {
        populateStoreV2()

        let v3container = createPersistentContainer(using: .TestModel_Simple_3)
        v3container.persistentStoreDescriptions[0].shouldMigrateStoreAutomatically = false

        do {
            try loadStores(for: v3container, shouldSucceed: false)
            XCTFail("Should not have been able to load this")
        } catch {
            print("\(error)")
        }
    }

    func testCanDetectMissingSourceVersion() {
        populateStoreV1()

        let v2container = createPersistentContainer(using: .TestModel_Simple_2, bundles: [])

        let migDelegate = Delegate()
        migDelegate.expectCalls([.willConsider,
                                 .didFailToMigrate])
        v2container.migrationDelegate = migDelegate

        do {
            try loadStores(for: v2container, shouldSucceed: false)
            XCTFail("No error! Should have failed")
        } catch MigrationError.cannotFindSourceModel(_, _) {
            // OK
            migDelegate.verify()
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testCanDetectMissingDestinationVersion() {
        populateStoreV1()

        let order           = ModelVersionOrder.patternMatchCompare("TestModel_Simple_.*")
        let vMultiContainer = createPersistentContainer(using: .TestModel_MultiConfig_1, order: order)

        do {
            try loadStores(for: vMultiContainer, shouldSucceed: false)
            XCTFail("No error! Should have failed")
        } catch MigrationError.cannotFindDestinationModel(_, _) {
            // OK
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testCanDetectInvalidModelVersionOrderAsync() {
        populateStoreV1()

        let v2container = createPersistentContainer(using: .TestModel_Simple_2, order: .list([]))

        do {
            try loadStores(for: v2container, shouldSucceed: false)
            XCTFail("No error! Should have failed")
        } catch MigrationError.badModelVersionOrder(_, _) {
            // OK
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testCanDetectInvalidModelVersionOrderSync() {
        populateStoreV1()

        let v2container = createPersistentContainer(using: .TestModel_Simple_2, order: .list([]), addAsync: false)

        do {
            try loadStores(for: v2container, shouldSucceed: false)
            XCTFail("No error! Should have failed")
        } catch MigrationError.badModelVersionOrder(_, _) {
            // OK
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func do_testCanReportFailedStoreReplace(storeType: String) {
        populateStoreV1(storeType: storeType)

        // Apologize for this one.
        // Have a path reachable only if a filesystem operation fails - instead of inventing a programmably
        // bad filesystem layer am snooping the log....
        // But it was worth it -- spotted that NSPSC.replacePersStore is highly fishy outside of SQLite3.
        let regex = try! NSRegularExpression(pattern: "Moving migrated store from file://(.*) back to")

        loggingWatcher = { msg in
            if let newUrl = regex.matchesString(msg) {
                try! FileManager.default.removeItem(atPath: newUrl)
            }
        }

        do {
            let v2container = createPersistentContainer(using: .TestModel_Simple_2, storeType: storeType)

            let migDelegate = Delegate()
            migDelegate.expectCalls([.willConsider,
                                     .willMigrate(ModelName.TestModel_Simple_1.rawValue, ModelName.TestModel_Simple_2.rawValue, 1),
                                     .willSingleMigrate(ModelName.TestModel_Simple_1.rawValue, ModelName.TestModel_Simple_2.rawValue, false, 1, 1),
                                     .didFailToMigrate])
            v2container.migrationDelegate = migDelegate

            try loadStores(for: v2container, shouldSucceed: false)
            XCTFail("No error! Should have failed")
        } catch {
        }
        
        loggingWatcher = nil
    }

    func testCanReportFailedStoreReplaceWithSQLite() {
        do_testCanReportFailedStoreReplace(storeType: NSSQLiteStoreType)
    }

    func testCanReportFailedStoreReplaceWithBinaryStore() {
        do_testCanReportFailedStoreReplace(storeType: NSBinaryStoreType)
    }

    func testCanSurviveInMemoryStore() {
        let container = populateStoreV2(storeType: NSInMemoryStoreType)
        verifyStoreV2(container: container)
    }

    func testCanSurviveInMemoryStoreWithNoUrl() {
        persistentStoreDescriptionEditCallback = { desc in
            desc.url = nil
        }
        let container = populateStoreV2(storeType: NSInMemoryStoreType)
        verifyStoreV2(container: container)
    }

    func testCanSurviveInMemoryStoreWithWeirdUrl() {
        persistentStoreDescriptionEditCallback = { desc in
            desc.url = URL(string: "http://www.google.com/")
        }
        let container = populateStoreV2(storeType: NSInMemoryStoreType)
        verifyStoreV2(container: container)
    }

    func testCanGenerateLogicErrorAfterMigrate() {
        let container = createAndLoadStore(using: .TestModel_Simple_1, makeEmpty: true)

        let migratedStore = MigratedStore(description: container.persistentStoreDescriptions[0],
                                          tempURL: container.persistentStoreDescriptions[0].fileURL)

        let container2 = createPersistentContainer(using: .TestModel_Simple_3)

        do {
            try container2.checkCompatibility(ofStore: migratedStore)
            XCTFail("Ought to have failed")
        } catch MigrationError.logicFailure {
            // OK
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}
