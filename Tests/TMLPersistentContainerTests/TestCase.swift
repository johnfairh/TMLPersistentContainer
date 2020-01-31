//
//  TestCase.swift
//  TMLPersistentContainer
//
//  Distributed under the ISC license, see LICENSE.
//

import Foundation
import CoreData
import XCTest
@testable import TMLPersistentContainer

/// Common base class for container tests holding utilities.
open class TestCase: XCTestCase {
    
    /// This gunk lets individual tests immediately fail when they
    /// hit an assertion failure, but let other tests in the TestCase run.
    /// (aka "do it like JUnit...")
    override open func invokeTest() {
        continueAfterFailure = false
        loggingWatcher = nil
        persistentStoreDescriptionEditCallback = nil
        super.invokeTest()
        continueAfterFailure = true
    }
    
    /// Name of the stores on disk

    private static let persistentStoreNames = ["TestStore1", "TestStore2"]
    private static let persistentStore1Name = persistentStoreNames[0]
    private static let persistentStore2Name = persistentStoreNames[1]

    var persistentStoreDescriptionEditCallback: ((NSPersistentStoreDescription) -> Void)?

    /// Create a persistent container from a particular MOM level
    func createPersistentContainer(using file: ModelName,
                                   bundles: [Bundle] = Bundle.allBundles,
                                   order: ModelVersionOrder = .compare,
                                   configuration: String? = nil,
                                   storeType: String = NSSQLiteStoreType,
                                   addAsync: Bool = true) -> PersistentContainer {
        let managedObjectModel = loadManagedObjectModel(file)
        let container = PersistentContainer(name: TestCase.persistentStore1Name,
                                            managedObjectModel: managedObjectModel,
                                            bundles: bundles,
                                            modelVersionOrder: order,
                                            logMessageHandler: loggingCallback)
        container.persistentStoreDescriptions[0].configuration = configuration
        container.persistentStoreDescriptions[0].type = storeType
        container.persistentStoreDescriptions[0].shouldAddStoreAsynchronously = addAsync

        if let callback = persistentStoreDescriptionEditCallback {
            callback(container.persistentStoreDescriptions[0])
        }
        return container
    }


    /// Create a regular core data persistent container
    func createNsPersistentContainer(using file: ModelName) -> NSPersistentContainer {
        let managedObjectModel = loadManagedObjectModel(file)
        let container = NSPersistentContainer(name: TestCase.persistentStore1Name,
                                              managedObjectModel: managedObjectModel)
        return container
    }

    /// Add a second store cloned from the first
    func addSecondStoreToContainer(_ container: NSPersistentContainer, configuration: String? = nil) {
        let newDesc = container.persistentStoreDescriptions[0].copy() as! NSPersistentStoreDescription
        newDesc.configuration = configuration
        newDesc.url?.deleteLastPathComponent()
        newDesc.url?.appendPathComponent(TestCase.persistentStore2Name + ".sqlite")
        container.persistentStoreDescriptions.append(newDesc)
    }

    /// Delete the on-disk store for a container
    func destroyStore(for container: PersistentContainer) {
        doAlways("Destroy store") {
            try container.destroyStores()
        }
    }
    
    /// Load the stores, block until done, return any error
    func loadStores(for container: NSPersistentContainer,
                    shouldSucceed: Bool = true,
                    shouldFirstSucceed: Bool = true,
                    shouldSecondSucceed: Bool = true) throws {
        let doneExpectation = expectation(description: "Stores loaded")

        var storesToLoad = container.persistentStoreDescriptions.count
        var storeErrors: [Error?] = [nil, nil]
        
        container.loadPersistentStores { description, error in
            let storeName = description.url?.lastPathComponent
            if storeName == TestCase.persistentStore1Name + ".sqlite" {
                storeErrors[0] = error
            } else {
                storeErrors[1] = error
            }

            storesToLoad -= 1
            if storesToLoad == 0 {
                doneExpectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 1000) // sure

        var expectNoErrors = [shouldSucceed ? shouldFirstSucceed : false, shouldSecondSucceed]

        if container.persistentStoreDescriptions.count == 1 {
            expectNoErrors.remove(at: 1)
            storeErrors.remove(at: 1)
        }

        zip(storeErrors, expectNoErrors).forEach { err, expectNoError in
            if let err = err {
                if expectNoError {
                    XCTFail("Store load failed unexpectedly, \(err)")
                }
            } else if !expectNoError {
                XCTFail("Store loaded OK but should have failed")
            }
        }

        try storeErrors.forEach {
            if $0 != nil { throw $0! }
        }
    }
    
    /// Initialise a PersistentContainer, optionally nuking the store first
    func createAndLoadStore(using model: ModelName,
                            makeEmpty: Bool = false,
                            bundles: [Bundle] = Bundle.allBundles,
                            delegate: MigrationDelegate? = nil,
                            configuration: String? = nil,
                            storeType: String = NSSQLiteStoreType,
                            addAsync: Bool = true) -> PersistentContainer {
        let container = createPersistentContainer(using: model,
                                                  bundles: bundles,
                                                  configuration: configuration,
                                                  storeType: storeType,
                                                  addAsync: addAsync)
        container.migrationDelegate = delegate
        
        if makeEmpty {
            destroyStore(for: container)
        }
        
        _ = try! loadStores(for: container)
        
        return container
    }

    /// Initialise a PersistentContainer with two stores, optionally nuking them first
    func createAndLoadMultiStores(using model: ModelName,
                                  configuration1: String,
                                  configuration2: String,
                                  makeEmpty: Bool = false,
                                  bundles: [Bundle] = Bundle.allBundles,
                                  delegate: MigrationDelegate? = nil) -> PersistentContainer {
        let container = createPersistentContainer(using: model, configuration: configuration1)
        container.migrationDelegate = delegate
        addSecondStoreToContainer(container, configuration: configuration2)

        if makeEmpty {
            destroyStore(for: container)
        }

        _ = try! loadStores(for: container)

        return container
    }

    /// Helper to delete files associated with a store.  Different to PSC.destroy().
    func deleteFilesForStore(name: String? = nil) {
        let directoryURL = NSPersistentContainer.defaultDirectoryURL()

        let storeFileName = name ?? TestCase.persistentStore1Name

        try! FileManager.default.contentsOfDirectory(atPath: directoryURL.path)
            .filter {$0.hasPrefix(storeFileName)}
            .map(directoryURL.appendingPathComponent)
            .forEach(FileManager.default.removeItem)
    }

    /// Save any outstanding changes to the container's view context
    func saveChanges(container: NSPersistentContainer, shouldSucceed: Bool = true) {
        do {
            try container.viewContext.save()
            if !shouldSucceed {
                XCTFail("Context save unexpectedly worked!")
            }
        } catch {
            if shouldSucceed {
                XCTFail("Context save unexpectedly failed, \(error)")
            }
        }
    }
}

func doAlways(_ what: String, throwing: () throws -> Void) {
    do {
        try throwing()
    } catch {
        fatalError("\(what) - unexpected \(error)")
    }
}

var loggingWatcher: ((String) -> () )? = nil

func loggingCallback(msg: LogMessage) {
    print("LOG: \(msg)")
    if let loggingWatcher = loggingWatcher {
        loggingWatcher(msg.body())
    }
}

extension XCTestCase {
    func url(for fileName: String) -> URL? {
        // Our models are stored in the test bundle so we cannot use Bundle.main to find it, either
        // directly or indirectly via the 1-arg init version of [NS]PersistentContainer.
        // This locates the test bundle via the location of this current class's binary.
        let unitTestBundle = Bundle(for: type(of: self))
        return unitTestBundle.url(forResource: fileName, withExtension: "momd")
    }
    /// Load an NSManagedObjectModel for a particular model[set]
    func loadManagedObjectModel(_ file: ModelName) -> NSManagedObjectModel {

        guard let modelURL = url(for: file.rawValue) else {
            fatalError("Couldn't find \(file.rawValue).momd in the bundle")
        }
        
        guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("\(file.rawValue).momd doesn't seem to be a managed object model")
        }
        
        return managedObjectModel
    }
}
