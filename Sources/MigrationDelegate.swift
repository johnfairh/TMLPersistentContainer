//
//  MigrationDelegate.swift
//  TMLPersistentContainer
//
//  Distributed under the ISC license, see LICENSE.
//

import Foundation
import CoreData

/// A delegate that can be provided to `PersistentContainer` to receive events describing the
/// progress of migrations. These events can be used to update a user interface or for app
/// internal logging.
///
/// All methods are called while `PersistentContainer.loadPersistentStores` is active.
/// If *any* of the `NSPersistentStoreDescription`s have the `shouldAddStoreAsynchronously` flag
/// set to `true` then all methods are called on a private background queue. If all of the store
/// descriptions have the flag set to `false` then the methods are called on the same queue on which
/// `PersistentContainer.loadPersistentStores` was called.
///
/// The stores in `PersistentContainer.persistentStoreDescriptions` are processed sequentially.
/// Stores that are not migratable (not on disk) are ignored and do not represent in this delegate.
///
/// A store that does not require migration (the normal case!) sees the sequence:
///
///  1. willConsiderStore
///  2. willNotMigrateStore
///
/// A store requiring a 2-step migration sees the sequence:
///
///  1. willConsiderStore
///  2. willMigrateStore - totalSteps=2
///  3. willSingleMigrateStore - stepsRemaining=2
///  4. willSingleMigrateStore - stepsRemaining=1
///  5. didMigrateStore
///
/// Errors can occur at any point following `willConsiderStore` for example:
///
///  1. willConsiderStore
///  2. willMigrateStore - totalSteps=8
///  3. didFailToMigrateStore
///
@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
public protocol MigrationDelegate: class {

    /// Called for each store that might need to be migrated, before deciding whether to
    /// migrate it.
    ///
    /// - Parameters:
    ///   - container: The `PersistentContainer` asked to load the store.
    ///   - willConsiderStore: The store that may be migrated.
    func persistentContainer(_ container: NSPersistentContainer,
                             willConsiderStore: NSPersistentStoreDescription)

    /// Called for each store that will be migrated, before any migrations start for the store.
    ///
    /// - Parameters:
    ///   - container: The `PersistentContainer` asked to load the store.
    ///   - willMigrateStore: The store that will be migrated.
    ///   - sourceModelVersion: The model version that the store currently has.
    ///   - destinationModelVersion: The model version that the store will have after all migrations.
    ///   - totalSteps: The number of separate migration steps that will be executed on the store.
    func persistentContainer(_ container: NSPersistentContainer,
                             willMigrateStore: NSPersistentStoreDescription,
                             sourceModelVersion: String,
                             destinationModelVersion: String,
                             totalSteps: Int)

    /// Called for each store that will *not* be migrated either because it does not exist or
    /// because it is already at the latest version.
    ///
    /// - Parameters:
    ///   - container: The `PersistentContainer` asked to load the store.
    ///   - willNotMigrateStore: The store that will not be migrated.
    ///   - storeExists: `true` if the store exists on disk at the right version.
    func persistentContainer(_ container: NSPersistentContainer,
                             willNotMigrateStore: NSPersistentStoreDescription,
                             storeExists: Bool)

    /// Called before each migration step.
    ///
    /// - Parameters:
    ///   - container: The `PersistentContainer` asked to load the store.
    ///   - willSingleMigrateStore: The store that will be migrated.
    ///   - sourceModelVersion: The model version this step will be from.
    ///   - destinationModelVersion: The model version this step will be to.
    ///   - usingInferredMapping: `true` if the mapping model for the step has been inferred.
    ///   - withMigrationManager: The `NSMigrationManager` that will be used.
    ///   - toTemporaryLocation: The location on disk of the migrated version of the store.
    ///   - stepsRemaining: The number of migration steps remaining for the store, **including** this step!
    ///   - totalSteps: The total number of migration steps for this store.
    func persistentContainer(_ container: NSPersistentContainer,
                             willSingleMigrateStore: NSPersistentStoreDescription,
                             sourceModelVersion: String,
                             destinationModelVersion: String,
                             usingInferredMapping: Bool,
                             withMigrationManager: NSMigrationManager,
                             toTemporaryLocation: URL,
                             stepsRemaining: Int,
                             totalSteps: Int)

    /// Called after a successful store migration.
    ///
    /// - Parameters:
    ///   - container: The `PersistentContainer` asked to load the store.
    ///   - didMigrateStore: The store that has been migrated.
    func persistentContainer(_ container: NSPersistentContainer,
                             didMigrateStore: NSPersistentStoreDescription)

    /// Called after an error has occurred during or before migrating a store.
    /// The `PersistentContainer.loadPersistentStores` error callback will be made later.
    ///
    /// - Parameters:
    ///   - container: The `PersistentContainer` asked to load the store.
    ///   - didFailToMigrateStore: The store that could not be migrated.
    ///   - error: The reason the store could not be migrated, could be from `MigrationError`.
    func persistentContainer(_ container: NSPersistentContainer,
                             didFailToMigrateStore: NSPersistentStoreDescription,
                             error: Error)
}

/// Do nothing.
@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
public extension MigrationDelegate {
    /// Do nothing.
    func persistentContainer(_ container: NSPersistentContainer,
                             willConsiderStore: NSPersistentStoreDescription) {
    }

    /// Do nothing.
    func persistentContainer(_ container: NSPersistentContainer,
                             willMigrateStore: NSPersistentStoreDescription,
                             sourceModelVersion: String,
                             destinationModelVersion: String,
                             totalSteps: Int) {
    }

    /// Do nothing.
    func persistentContainer(_ container: NSPersistentContainer,
                             willNotMigrateStore: NSPersistentStoreDescription,
                             storeExists: Bool) {
    }

    /// Do nothing.
    func persistentContainer(_ container: NSPersistentContainer,
                             willSingleMigrateStore: NSPersistentStoreDescription,
                             sourceModelVersion: String,
                             destinationModelVersion: String,
                             usingInferredMapping: Bool,
                             withMigrationManager: NSMigrationManager,
                             toTemporaryLocation: URL,
                             stepsRemaining: Int,
                             totalSteps: Int) {
    }

    /// Do nothing.
    func persistentContainer(_ container: NSPersistentContainer,
                             didMigrateStore: NSPersistentStoreDescription) {
    }

    /// Do nothing.
    func persistentContainer(_ container: NSPersistentContainer,
                             didFailToMigrateStore: NSPersistentStoreDescription,
                             error: Error) {
    }
}
