//
//  PersistentContainer.swift
//  TMLPersistentContainer
//
//  Distributed under the ISC license, see LICENSE.
//

import Foundation
import CoreData

/// A container for a Core Data stack that provides automatic multi-step shortest-path
/// persistent store migration, capable of managing both CloudKit-backed and non-cloud stores.
///
/// This is a drop-in replacement for `NSPersistentCloudKitContainer` that
/// automatically detects and performs multi-step store migration as part of the
/// `loadPersistentStores(...)` method.
///
/// The container searches for models and mapping models, then constructs the
/// best sequence in which to migrate stores. It prefers to use explicit mapping models
/// over inferred mapping models when there is a choice. Progress and status can be
/// reported back to the client code.
///
/// See [the user guide](https://johnfairh.github.io/TMLPersistentContainer/usage.html) for more details.
///
/// See `PersistentContainer` for a version that does not support CloudKit-backed stores.
///
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
open class PersistentCloudKitContainer: NSPersistentCloudKitContainer, PersistentContainerMigratable, PersistentContainerProtocol, LogMessageEmitter {

    /// Background queue for running store operations.
    let dispatchQueue = DispatchQueue(label: "CloudKitPersistentContainer", qos: .utility)

    /// User's model version order.
    let modelVersionOrder: ModelVersionOrder

    /// List of bundles to search for Core Data models.
    let bundles: [Bundle]

    /// Core Data model version graph discovered from the bundles.
    var modelVersionGraph: ModelVersionGraph?

    /// Optional delegate to receive migration progress notifications.
    public weak var migrationDelegate: MigrationDelegate?

    /// Log message handler
    let logMessageHandler: LogMessage.Handler?

    /// Initializes a persistent container from a named model.
    ///
    /// - Parameters:
    ///   - name: The name of the managed object model to use with the container.
    ///           This name is used as the default name for the first persistent store.
    ///
    ///   - bundles: An array of bundles to search for the container's model. By default
    ///              only the app's main bundle. If the model exists in multiple bundles then
    ///              the first one in the array is used. If the model exists more than once
    ///              in the same bundle then it is undefined which is used. These bundles are
    ///              also used to search for data and mapping models during automatic multi-step
    ///              store migration.
    ///
    ///   - modelVersionOrder: The ordering algorithm of model versions used to guide automatic
    ///                        multi-step store migration. The default is a numeric string
    ///                        comparison, meaning that `MyModel1` precedes `MyModel2` precedes
    ///                        `MyModel10`.
    ///
    ///   - logMessageHandler: A callback to receive log messages from the library suitable for
    ///                        helping debug applications. Calls can occur on any queue.
    ///                        The default performs no logging.
    public convenience init(name: String,
                            bundles: [Bundle] = [Bundle.main],
                            modelVersionOrder: ModelVersionOrder = .compare,
                            logMessageHandler: LogMessage.Handler? = nil) {
        let firstModelFromBundles = bundles.managedObjectModels(with: name).first
        
        if firstModelFromBundles == nil {
            logMessageHandler?(LogMessage(.error, "Found no models matching \(name), using empty NSManagedObjectModel."))
        } else {
            logMessageHandler?(LogMessage(.info, "Using \(firstModelFromBundles.debugDescription) for model \(name)."))
        }
        
        let model = firstModelFromBundles ?? NSManagedObjectModel()
        
        self.init(name: name,
                  managedObjectModel: model,
                  bundles: bundles,
                  modelVersionOrder: modelVersionOrder,
                  logMessageHandler: logMessageHandler)
    }

    /// Initializes a persistent container using a managed object model.
    ///
    /// - Parameters:
    ///   - name: The defaut name for the first persistent store.
    ///
    ///   - model: The managed object model to be used by the persistent container.
    ///
    ///   - bundles: An array of bundles used to search for data models and mapping models
    ///              during automatic multi-step store migration.
    ///
    ///   - modelVersionOrder: The ordering algorithm of model versions used to guide automatic
    ///                        multi-step store migration. The default is a numeric string
    ///                        comparison, meaning that `MyModel1` precedes `MyModel2` precedes
    ///                        `MyModel10`.
    ///
    ///   - logMessageHandler: A callback to receive log messages from the library suitable for
    ///                        helping debug applications. Calls can occur on any queue.
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
    
    /// Begin loading and migrating the persistent stores mentioned in `persistentStoreDescriptions` that have
    /// not already been loaded. The completion handler is called once for each such store on the main queue
    /// indicating whether the store has been loaded successfully.
    ///
    /// If the store description has `shouldMigrateStoreAutomatically` set then the container automatically
    /// attempts multi-step migration.  If the store description also has `shouldInferMappingModelAutomatically`
    /// set then the multi-step migration can include the use of inferred mapping models and light-weight
    /// migration.  Once any multi-step migration is complete, Core Data is invoked to load the store and set
    /// up the stack for use.
    ///
    /// These flags are both on by default.
    ///
    /// If *any* of the store descriptions have `shouldAddStoreAsynchronously` set then this routine returns
    /// immediately and *all* migrations occur on a background queue.  This flag is off by default.
    ///
    /// If the container has multiple stores then the container tries very hard to ensure either all stores
    /// are migrated successfully or none are.
    ///
    /// - Parameter block: Callback made on the main queue for each store when it has either been loaded successfully
    ///                    or failed to load.  The `Error` here can be anything provided by
    ///                    `NSPersistentContainer.loadPersistentStores` as well as anything from `MigrationError`
    ///                    in this package.
    ///
    open override func loadPersistentStores(completionHandler block: @escaping (NSPersistentStoreDescription, Error?) -> ()) {
        let invokeCoreDataClosure = { block in
            super.loadPersistentStores(completionHandler: block)
        }
        
        loadPersistentStoresHelper(invokeCoreDataClosure: invokeCoreDataClosure, completionHandler: block)
    }
}
