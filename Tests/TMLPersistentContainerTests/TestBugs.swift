//
//  TestBugs.swift
//  TMLPersistentContainer
//
//  Created by John Fairhurst on 11/01/2017.
//  Copyright © 2017 Too Many Ladybirds. All rights reserved.
//

import XCTest
import CoreData

///
/// Test cases that demonstrate bugs in core data or other apple frameworks.
/// If any of these start failing then this probably means that APL have fixed
/// something and workarounds can be removed in the main code.
///
/// These tests use the library APIs directly and should be minimal examples of
/// the (believed) buggy behaviour.
///
class TestBugs: XCTestCase {
    
    func testDestroyContainerBreaksMetadataForPersistentStore() {

        // Load model + set up persistent container as normal
        
        let modelFileName = "TestModel_Simple_1" // must have at least one entity
        let storeFileName = "TestBugs_1_Store"
        
        let unitTestBundle = Bundle(for: type(of: self))
            
        guard let modelURL = unitTestBundle.url(forResource: modelFileName, withExtension: "momd") else {
            XCTFail("Couldn't find \(modelFileName).momd in the bundle")
            return
        }
        
        guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            XCTFail("\(modelFileName).momd doesn't seem to be a managed object model")
            return
        }

        let persistentContainer = NSPersistentContainer(name: storeFileName, managedObjectModel: managedObjectModel)
        
        // Destroy the model on disk to start off in a clean state.
        //
        // For an SQLite store this does not erase the files but instead replaces them with files
        // making up an empty database.
        //
        let storeDescription = persistentContainer.persistentStoreDescriptions[0]
        
        do {
            try persistentContainer.persistentStoreCoordinator.destroyPersistentStore(at: storeDescription.url!,
                                                                                      ofType: storeDescription.type,
                                                                                      options: storeDescription.options)
        } catch {
            XCTFail("Unexpected destroy error: \(error)")
        }
        
        // Load the metadata of the store.
        // ?buggy behaviour observed is that this CREATES a stub metadata table in the empty database
        // created by 'destroy' that has NSPersistentFrameworkVersion, NSStoreType, NSStoreUUID, _NSAutoVacuumLevel
        // but no NSStoreVersionHashes/NSStoreModelVersionIdentifiers/NSStoreModelHashesVersion keys
        // (let alone contents, which would be impossible given we haven't given it a model)
        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: storeDescription.type,
                                                                                       at: storeDescription.url!,
                                                                                       options: storeDescription.options)

            // These keys are important because we use them in the workaround to detect that bad state.
            XCTAssertTrue(metadata[NSStoreModelVersionHashesKey] == nil)
            XCTAssertTrue(metadata[NSStoreModelVersionIdentifiersKey] == nil)
        } catch {
            XCTFail("Unexpected metadataForPersistentStore error: \(error)")
        }

        // Finally try to load the store.  This fails with an error complaining that the metadata table
        // in the database is rubbish because it does not mention any of the entities in the model.
        //
        let doneExpectation = expectation(description: "Load store done")
        
        persistentContainer.loadPersistentStores { description, error in
            if error == nil {
                XCTFail("Persistent store unexpectedly loaded!")
            } else {
                print("Got error on store-load: \(error)")
            }
            doneExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1000)
    }
}
