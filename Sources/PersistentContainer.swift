//
//  PersistentContainer.swift
//  TMLPersistentContainer
//
//  Created by John Fairhurst on 05/01/2017.
//  Copyright © 2017 Too Many Ladybirds. All rights reserved.
//

import Foundation
import CoreData

/// User callback for persistent store load completion, made on the main queue.
//@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
//typealias StoreLoadCompletion = (NSPersistentStoreDescription, Error?) -> Void


/// A container for a Core Data stack that provides automatic multi-step persistent store migration.
///
/// This is a drop-in replacement for `NSPersistentContainer` that automatically detects
/// and performs multi-step store migration as part of the `loadPersistentStores` method.
///
/// The container searches for models and mapping models, and constructs the
/// best sequence in which to migrate stores.  It prefers to use explicit mapping models over
/// inferred mapping models when there is a choice.  Progress and status can be reported
/// back to the client code.
///
/// See [the user guide](https://some/url) for more details.
///
@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
open class PersistentContainer: NSPersistentContainer, LogMessageEmitter {

    /// Background queue for running store operations
    private let dispatchQueue = DispatchQueue(label: "PersistentContainer", qos: .utility)

    /// User's model version order
    let modelVersionOrder: ModelVersionOrder

    /// List of bundles to search for Core Data models
    let bundles: [Bundle]

    /// Core Data model version graph discovered from the bundles
    var modelVersionGraph: ModelVersionGraph?

    /// Optional delegate to receive migration progress notifications
    public weak var migrationDelegate: MigrationDelegate?

    /// Log message handler
    let logMessageHandler: LogMessage.Handler?

    /// Initializes a persistent container from a named model.
    ///
    /// - Parameters:
    ///   - name: The name of the managed object model to use with the container.
    ///           This name is the default name for the first persistent store.
    ///
    ///   - bundles: An array of bundles to search for the model, by default only the app's
    ///              main bundle. If the model exists in multiple bundles then the first one
    ///              in the array is used. If the model exists more than once in the same bundle
    ///              then it is undefined which is used. These bundles are also used to search for
    ///              data and mapping models during automatic multi-step store migration.
    ///
    ///   - modelVersionOrder: The ordering algorithm of data model versions used to guide
    ///                        automatic multi-step store migration. The default is a numeric string
    ///                        comparison, meaning that `MyModel1` precedes `MyModel2` precedes `MyModel10`.
    ///
    ///   - logMessageHandler: A callback to receive log messages from the library suitable for
    ///                        helping debug applications.  Calls can occur on any queue.
    ///                        The default performs no logging.
    public convenience init(name: String,
                            bundles: [Bundle] = [Bundle.main],
                            modelVersionOrder: ModelVersionOrder = .compare,
                            logMessageHandler: LogMessage.Handler? = nil) {

        // This is all pretty messy, don't want to be doing this stuff in initializer but
        // can't see how to avoid.  No self so logging ugly too :(

        for bundle in bundles {
            if let url = bundle.url(forResource: name, withExtension: "momd") {
                if let model = NSManagedObjectModel(contentsOf: url) {
                    logMessageHandler?(LogMessage(.info, "Using \(url) for model \(name)."))
                    self.init(name: name,
                              managedObjectModel: model,
                              bundles: bundles,
                              modelVersionOrder: modelVersionOrder,
                              logMessageHandler: logMessageHandler)
                    return                                    /* EXIT FUNCTION */
                } else {
                    logMessageHandler?(LogMessage(.warning, "Found \(url) but cannot load it as NSManagedObjectModel."))
                }
            }
        }

        // well...
        logMessageHandler?(LogMessage(.error, "Found no models matching \(name), using empty NSManagedObjectModel."))

        self.init(name: name,
                  managedObjectModel: NSManagedObjectModel(),
                  bundles: bundles,
                  modelVersionOrder: modelVersionOrder,
                  logMessageHandler: logMessageHandler)
    }

    /// Initializes a persistent container using a managed object model
    ///
    /// - Parameters:
    ///   - name: The defaut name for the first persistent store
    ///
    ///   - model: The managed object model to be used by the persistent container
    ///
    ///   - bundles: An array of bundles used to search for data models and mapping models
    ///              as part of automatic multi-step store migration.
    ///
    ///   - modelVersionOrder: The ordering algorithm of data model versions used to guide
    ///                        automatic multi-step store migration.  The default is a numeric string
    ///                        comparison, meaning that `MyModel1` precedes `MyModel2` precedes `MyModel10`.
    ///
    ///   - logMessageHandler: A callback to receive log messages from the library suitable for
    ///                        helping debug applications.  Calls can occur on any queue.
    ///                        The default performs no logging.
    public init(name: String,
                managedObjectModel model: NSManagedObjectModel,
                bundles: [Bundle] = [Bundle.main],
                modelVersionOrder: ModelVersionOrder = .compare,
                logMessageHandler: LogMessage.Handler?) {
        self.bundles = bundles
        self.modelVersionOrder = modelVersionOrder
        self.logMessageHandler = logMessageHandler
        super.init(name: name, managedObjectModel: model)
    }

    /// Cleanly empty out all persistent stores described by `persistentStoreDescriptions`.
    /// Typically useful to reset the app to a fresh state before loading the stores.
    ///
    /// - Attention: May not remove files from disk.  In the case of SQLite3 stores, database files
    ///              making up an empty store are left behind.
    ///
    /// - Attention: Goodness knows what this will do with custom stores.  There does not appear to be
    ///              an API into the `NSPersistentStore` tree to implement this operation.
    ///
    /// - Attention: This is not atomic with respect to multiple stores.  The routine attempts to
    ///              destroy each store one by one; the first destroy operation to fail causes the
    ///              entire routine to fail.
    ///
    /// - Throws: Errors thrown by `NSPersistentStoreCoordinator.destroyPersistentStore(at:ofType:options:)` which
    ///           is undocumented -- assumed to be filesystem access errors that the app should probably consider as
    ///           fatal.  Does *not* throw an error if a persistent store does not currently exist.
    ///
    open func destroyStores() throws {
        try persistentStoreDescriptions.forEach { description in
            log(.info, "Destroying store \(description)")
            try description.destroyStore(coordinator: self.persistentStoreCoordinator)
        }
    }

    /// Begin loading and migrating the persistent stores mentioned in `persistentStoreDescriptions` that have
    /// not already been loaded.  The completion handler is called once for each such store on the main queue
    /// indicating whether the store has been loaded successfully or not.
    ///
    /// If the store description has `shouldMigrateStoreAutomatically` set then the container automatically
    /// attempts multi-step migration.  If the store description also has `shouldInferMappingModelAutomatically`
    /// set then the multi-step migration can include the use of inferred mapping models and light-weight
    /// migration.  Once any multi-step migration is complete, Core Data is invoked to load the store and set
    /// up the stack for use.
    ///
    /// These flags are both on by default.
    ///
    /// If the container has multiple stores then the container tries very hard to ensure either all stores
    /// are migrated successfully or none are -- leaving all stores at the original version.
    ///
    /// - Parameter block: Callback made on the main queue for each store when it has either been loaded successfully
    ///                    or failed to load.  The `Error` here can be anything provided by `NSPersistentContainer.loadPersistentStores`
    ///                    as well as anything from `MigrationError` in this package.
    ///
    open override func loadPersistentStores(completionHandler block: @escaping (NSPersistentStoreDescription, Error?) -> ()) {
        // Filter out the stores that need loading to replicate the superclass API
        // There are probably only a handful at most of these so no need to be terribly efficient
        let storeURLs = persistentStoreCoordinator.persistentStores.flatMap { $0.url }

        if storeURLs.count > 0 {
            log(.info, "Already have loaded stores associated with container: \(storeURLs)")
        }

        var storesToLoad: [NSPersistentStoreDescription] = []

        persistentStoreDescriptions.forEach { description in
            guard let storeURL = description.url else {
                log(.info, "Not migrating store \(description) because no URL present")
                return
            }
            if !storeURL.isFileURL {
                log(.info, "Not migrating store \(description) because not a file:// URL")
            } else if !description.shouldMigrateStoreAutomatically {
                log(.info, "Not migrating store \(storeURL) because shouldMigrateStoreAutomatically clear.")
            } else if storeURLs.contains(description.fileURL) {
                log(.info, "Not migrating store \(storeURL) because already loaded.")
            } else {
                storesToLoad.append(description)
            }
        }

        guard storesToLoad.count > 0 else {
            log(.warning, "Found no stores to load, invoking Core Data anyway.")
            super.loadPersistentStores(completionHandler: block)
            return
        }

        // Load stores asynchronously if ANY of the stores have the async flag set.
        let asyncMode = storesToLoad.reduce(false) { async, description in
            async || description.shouldAddStoreAsynchronously
        }

        // Helper to deal with the sync/async version....
        func doStoreMigration() {
            var failures = false

            migrateStores(descriptions: storesToLoad) { desc, error in
                failures = true
                self.log(.error, "Migration of store \(desc.fileURL) failed, sending user callback - \(error)")
                if asyncMode {
                    DispatchQueue.main.sync {
                        block(desc, error)
                    }
                } else {
                    block(desc, error)
                }
            }

            // If we didn't get any failure callbacks then it's OK to call Core Data.
            if !failures {
                self.log(.info, "All store migration successful, invoking Core Data.")
                if asyncMode {
                    DispatchQueue.main.async {
                        super.loadPersistentStores(completionHandler: block)
                    }
                } else {
                    super.loadPersistentStores(completionHandler: block)
                }
            }
        }

        if asyncMode {
            log(.info, "Found \(storesToLoad.count) to load, going to background.")

            dispatchQueue.async {
                self.log(.info, "In background, processing stores.")
                doStoreMigration()
                self.log(.debug, "Background thread ending.")
            }
        } else {
            log(.info, "Found \(storesToLoad.count) to load, doing synchronously.")
            doStoreMigration()
        }
    }
}
