//
//  TestMultiConfigMigrate.swift
//  TMLPersistentContainer
//
//  Created by John Fairhurst on 11/03/2017.
//  Copyright © 2017 Too Many Ladybirds. All rights reserved.
//

import XCTest
import CoreData
import TMLPersistentContainer

/// Tests for a model with multiple configurations used in multiple stores
///
/// ## Observations on Managed Object Model Configurations
///
///  1. The `configuration` value passed in when creating an SQLite3 store appears to be ignored.
///     The DB ends up with metadata for all entities, *not* filtered by configuration.
///     This decision is made by the `NSPersistentStore` layer and appears to be in line with
///     the scant guidance in the *Incremental Store Programming Guide*.
///
///  2. The configuration is policed when saving a managed object context, so no entities counter
///     to the configuration can appear in the store -- but the table is there in the DB and the
///     store metadata contains entity hash versions for all entities.
///
///  3. Further, the configuration is used for routing managed object context save's so that given
///     multiple stores having discrete configurations, objects get saved to their right home.
///     This is not strongly policed -- multiple stores sharing a configured entity do not cause an
///     error, creating an object saves it to the first store only.
///
///  4. The routine `NSManagedObjectModel.isConfiguration(withName:compatibleWithStoreMetadata:)`
///     appears to ignore the `withName` part.  It requires only that the entity version hashes for
///     *all* entities in the model match those in the store, and vice versa.  This behaviour seems
///     to *require* that stores act as in #1.
///
///  5. Further, passing an non-existent configuration name to the routine has no effect - it still
///     returns either `true` or `false` dependent solely on a 100% match of all entity version
///     hashes.
///
///  6. Points #4 and #5 here are contrary to the API docs.
///
///  7. The implication for the user is that configurations are *only* useful for restricting the
///     entities that can be saved to a particular store.  You cannot delete entities without
///     expecting a migration step even if the entities are ruled out of your store by the model
///     configuration you know is in use.  You must not delete entities from models that are used
///     by existing stores even when those entities are ruled out by the configuration.
///
///  8. Speculation ... from the docs it was supposed to work differently at some point.  Now it
///     is too late to change.  Because configurations themselves are not accounted for in the Core
///     Data model versioning scheme it is unworkable safely.  In addition there is no mention of
///     configurations in the `NSMappingModel` API.  Most likely is that the isConfigCompatible API
///     was forgotten about + should have had its configuration parameter removed.  Would love to know
///     what use cases the 'configurations' feature (a) was supposed to satisfy and (b) is satisfying
///     today.
///
/// ## Observations on Mapping Models
///
///  1. A mapping model really is 'just' a collection of entity mappings.  Although you provide xcode
///     with two data models to create a mapping model, these data models are used solely in the editor
///     to seed the initial list of entity mappings and let it be editted.  The compiled mapping model
///     file itself does not contain any reference to those data models.
///
///  2. A compiled mapping model is a .cdm file and appears to be just an `NSCoder`ed `NSMappingModel`.
///
///  3. The `NSMappingModel(from:forSourceModel:destinationModel)` routine appears to search for .cdm
///     files and load the first one found that contains at least one entity mapping matching the two
///     data models.  The routine does not appear to do any merging of mapping models as hinted at by
///     the API documentation.
///
///  4. Have not yet done the test of a mapping model containing mappings for a superset of entities
///     in the models.
///
///  5. Passing `nil` as either (or both) model parameters to `NSMappingModel(from:forSourceModel:destinationModel)`
///     seems to have no useful effect, routine seems to always return `nil`.
///
class TestMultiConfigMigrate: TestCase {

    struct Constants {
        static let Entity1_V1_ID = "104"
        static let Entity2_V1_ID = "8362"

        static let Entity1_V2_ID = Int32(104)
        static let Entity2_V2_ID = Int32(8362)

        static let ObjectCount = 1
    }

    func testCanUseNonDefaultConfig() {
        let container = createAndLoadStore(using: .TestModel_MultiConfig_1,
                                           makeEmpty: true,
                                           configuration: MultiConfigModel.config1Name)

        let _ = MultiConfigModel.createItem1V1(id: Constants.Entity1_V1_ID, context: container.viewContext)

        saveChanges(container: container)

        let _ = MultiConfigModel.createItem2V1(id: Constants.Entity2_V1_ID, context: container.viewContext)
        saveChanges(container: container, shouldSucceed: false) // check config policing is still there...
    }

    // Helper - set up fresh twin stores with some data at V1
    private func populateStoresV1() {
        let container = createAndLoadMultiStores(using: .TestModel_MultiConfig_1,
                                                 configuration1: MultiConfigModel.config1Name,
                                                 configuration2: MultiConfigModel.config2Name,
                                                 makeEmpty: true)

        let _ = MultiConfigModel.createItem1V1(id: Constants.Entity1_V1_ID, context: container.viewContext)
        let _ = MultiConfigModel.createItem2V1(id: Constants.Entity2_V1_ID, context: container.viewContext)
        saveChanges(container: container)
    }

    /// Helper - verify the store contents at V2
    private func verifyStoresV2(container: PersistentContainer) {
        let object1s = MultiConfigModel.getAllItem1sV2(context: container.viewContext)

        XCTAssertEqual(object1s.count, Constants.ObjectCount, "Bad number of Item1 objects in V2 store")
        XCTAssertEqual(object1s[0].id1, Constants.Entity1_V2_ID, "Object type 1 has bad ID in V2 store")

        let object2s = MultiConfigModel.getAllItem2sV2(context: container.viewContext)

        XCTAssertEqual(object2s.count, Constants.ObjectCount, "Bad number of Item2 objects in V2 store")
        XCTAssertEqual(object2s[0].id2, Constants.Entity2_V2_ID, "Object type 2 has bad ID in V2 store")
    }

    func testCanCreateMultipleStores() {
        populateStoresV1()
    }

    func testCanMigrateV1toV2() {
        populateStoresV1()

        let container = createAndLoadMultiStores(using: .TestModel_MultiConfig_2,
                                                 configuration1: MultiConfigModel.config1Name,
                                                 configuration2: MultiConfigModel.config2Name)

        verifyStoresV2(container: container)
    }

    func testCanHandlePartialFailures() {
        populateStoresV1()

        do {
            // now overwrite the first store with a SimpleModel store
            let cnr1 = createAndLoadStore(using: .TestModel_Simple_1, makeEmpty: true)
            _ = SimpleModel.createV1(id: "123", context: cnr1.viewContext)
            saveChanges(container: cnr1)
        }

        // now try to open both with multi-v1, having filtered out all the simple models.
        // (otherwise it will 'infer' a mapping consisting of deleting ALL the simple stuff
        // and replacing with multi!

        let migDelegate = Delegate()
        migDelegate.expectCalls([.willConsider,
                                 .didFailToMigrate,
                                 .willConsider,
                                 .willNotMigrate(true)])

        let order = ModelVersionOrder.patternMatchCompare("TestModel_MultiConfig.*")
        let container = createPersistentContainer(using: .TestModel_MultiConfig_1,
                                                  order: order,
                                                  configuration: MultiConfigModel.config1Name)
        container.migrationDelegate = migDelegate
        addSecondStoreToContainer(container, configuration: MultiConfigModel.config2Name)

        do {
            try loadStores(for: container, shouldFirstSucceed: false, shouldSecondSucceed: false)
            XCTFail("Stores loaded - should have failed")
        } catch MigrationError.coreqMigrationFailed(_) {
            // OK
        } catch MigrationError.cannotFindSourceModel(_, _) {
            // OK
        } catch {
            XCTFail("Unexpected error - \(error)")
        }
    }
}

//
// Entity migration policies....
//
class MultiItemXMigrationPolicy1to2: NSEntityMigrationPolicy {
    private let v1StringIdKeyPath: String
    private let v2Int32IdKeyPath: String

    init(v1StringIdKeyPath: String, v2Int32IdKeyPath: String) {
        self.v1StringIdKeyPath = v1StringIdKeyPath
        self.v2Int32IdKeyPath  = v2Int32IdKeyPath
    }

    override func createDestinationInstances(forSource sInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)

        let dInstances = manager.destinationInstances(forEntityMappingName: mapping.name, sourceInstances: [sInstance])
        guard dInstances.count > 0 else {
            fatalError("Confused, can't find destination instance")
        }
        let dInstance = dInstances[0]

        guard let v1id = sInstance.value(forKey: v1StringIdKeyPath) as? String else {
            fatalError("Can't read V1 id string from \(sInstance)")
        }

        let v2id = Int32(v1id)!

        dInstance.setValue(NSNumber(value: v2id), forKey: v2Int32IdKeyPath)
    }
}

class MultiItem1MigrationPolicy1to2: MultiItemXMigrationPolicy1to2 {
    init() {
        super.init(v1StringIdKeyPath: #keyPath(MultiItem1_1.id1),
                   v2Int32IdKeyPath: #keyPath(MultiItem1_2.id1))
    }
}

class MultiItem2MigrationPolicy1to2: MultiItemXMigrationPolicy1to2 {
    init() {
        super.init(v1StringIdKeyPath: #keyPath(MultiItem2_1.id2),
                   v2Int32IdKeyPath: #keyPath(MultiItem2_2.id2))
    }
}
