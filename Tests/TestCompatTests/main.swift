//
//  TestCompat - main.swift
//  TMLPersistentContainer
//
//  Distributed under the ISC license, see LICENSE.
//

import Foundation
import CoreData
import TMLPersistentContainer

// This is a test to verify that the special Bundle.main behaviour provided by NSPersistentContainer
// is simulated correctly by TMLPersistentContainer.
//
// Has to be a standalone program because tests running under XCTest have a Bundle.main that is
// not useful.  Rather hastily converted from an XCTestCase.
//
// Also usual horrors re. swiftCore.dylib getting a CLI application to link with a swift module --
// have poked in an -rpath reference to /Applications/XCode for now, as well as copying SPM's
// generation of apparently undocumented settings for SWIFT_FORCE_DYNAMIC_LINK_STDLIB.
//
class Constants {
    static let ObjectName  = "Object"
    static let StoreName   = ModelName.TestModel_Simple_1.rawValue
    static let EntityCount = 1
    static let ObjectCount = 1
}

func wipeStoreFiles() {
    let directoryURL = NSPersistentContainer.defaultDirectoryURL()

    try! FileManager.default.contentsOfDirectory(atPath: directoryURL.path)
        .filter {$0.hasPrefix(Constants.StoreName)}
        .map(directoryURL.appendingPathComponent)
        .forEach(FileManager.default.removeItem)
}

func saveChanges(container: NSPersistentContainer) {
    do {
        try container.viewContext.save()
    } catch {
        fatalError("Unexpected error saving context: \(error)")
    }
}

func createCoreDataStore() {
    let container = NSPersistentContainer(name: Constants.StoreName)

    precondition(Constants.EntityCount == container.managedObjectModel.entities.count)

    container.persistentStoreDescriptions[0].shouldAddStoreAsynchronously = false
    container.loadPersistentStores() { description, error in
        precondition(error == nil, "Store load should have worked")
    }
    _ = SimpleModel.createV1(id: Constants.ObjectName, context: container.viewContext)
    saveChanges(container: container)
}

func validateTMLStore() {
    let container = PersistentContainer(name: Constants.StoreName)

    precondition(Constants.EntityCount == container.managedObjectModel.entities.count)

    container.persistentStoreDescriptions[0].shouldAddStoreAsynchronously = false
    container.loadPersistentStores() { description, error in
        precondition(error == nil, "Store load should have worked")
    }

    let objects = SimpleModel.getAllObjectsV1(context: container.viewContext)
    precondition(objects.count == Constants.ObjectCount, "Wrong object count")
    precondition(objects[0].id1 == Constants.ObjectName, "Wrong object contents!")
}

wipeStoreFiles()
createCoreDataStore()
validateTMLStore()

print("TMLPersistentContainer-macOS TestCompat PASS")
