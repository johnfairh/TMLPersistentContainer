//
//  ContainerMigration.swift
//  TMLPersistentContainer
//
//  Created by John Fairhurst on 10/01/2017.
//  Copyright © 2017 Too Many Ladybirds. All rights reserved.
//

import Foundation
import CoreData

/// A store that has been migrated -- its description and the file URL of its temporary location
@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
struct MigratedStore
{
    let description: NSPersistentStoreDescription
    let tempURL: URL
}

/// This file contains the top-level store migration code.
///
/// It's fairly painful to read given the number of objects that have
/// to be juggled, the length of their names and the length of the names
/// of the routines that deal with them, on top of the overall structural
/// requirements.
///
/// The entrypoint is `migrateStores(descriptions:errorCallback)`, invoked on either background
/// queue or the main queue, depending on the user setting in the `NSPersistentStoreDescription`s.
/// The routine attempts to migrate all of the stores.
/// If any store migrate fails then `errorCallback` is made for all stores.
/// The routine is successful if it does not make any calls to `errorCallback`.
///
/// There are three phases to the migration algorithm:
///
///  1. Check out each store, decide whether it needs migrating.  If so,
///     migrate it up to the right version in a temporary file.
///
///  2. If no errors were encountered, replace the live stores with the migrated
///     versions.  If no stores required migration or there were errors in phase 1
///     then nothing happens in this phase.
///
///  3. Clean up temporary files and issue any co-req errors.
///
/// Co-req errors are to do with multi-store migration atomicity.  Our policy is that if one
/// store of a multi-store container does not migrate then all the stores are left at the
/// original level.  The co-req error is invented to flag these stores that migrated fine.
///
/// We break this policy in the case that all phase-1 activity works but a `replacePersistentStore`
/// API call fails.  In that case we end up with one migrated store marked co-req and one unmigrated
/// store marked with a filesystem error from `replacePersistentStore`.  When the user fixes their
/// filesystem and retries this, everything should be fine.
@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
extension PersistentContainer {

    /// Migrate all the stores as necessary.  Must call `errorCallback` for all or none of the stores.
    func migrateStores(descriptions: [NSPersistentStoreDescription],
                       errorCallback: (NSPersistentStoreDescription,Error) -> Void) {
        precondition(descriptions.count > 0)
        
        log(.debug, "Processing \(descriptions.count) stores.")

        // Track stores that have had no error callback + whether any error callback has happened
        var successfulDescriptions: Set<NSPersistentStoreDescription> = []
        var allSuccessful = true

        // Track stores that have been fully migrated but still need their replace phase.
        var migratedStores: [MigratedStore] = []

        // Use a single temp directory for files used during migration
        let tempDirectory = TemporaryDirectory()

        // PHASE 1 - MIGRATION

        // Do each store and perform any migration required.  One by one.
        
        descriptions.forEach { description in
            log(.info, "START work for store \(description.fileURL)")
            do {
                migrationDelegate?.persistentContainer(self, willConsiderStore: description)

                guard let storeMetadata = try description.loadStoreMetadata() else {
                    log(.info, "Store does not exist, no migration required.")
                    migrationDelegate?.persistentContainer(self, willNotMigrateStore: description, storeExists: false)

                    successfulDescriptions.insert(description)
                    return
                }

                log(.debug, "Got store metadata \(storeMetadata)")
                log(.debug, "Model total metadata \(self.managedObjectModel.entityHashDescription)")
                if description.configuration != nil {
                    log(.debug, "Model metadata for config \(description.configuration) \(self.managedObjectModel.entityHashDescription(forConfigurationName: description.configuration))")
                }

                // First check for awful special case - see comment on describesDestroyedStore()...
                if describesDestroyedStore(metadata: storeMetadata) {
                    log(.info, "Store was previously 'destroyed', no migration required.")
                    migrationDelegate?.persistentContainer(self, willNotMigrateStore: description, storeExists: false)

                    try description.destroyStore(coordinator: persistentStoreCoordinator)
                }
                else if managedObjectModel.isConfiguration(withName: description.configuration, compatibleWithStoreMetadata: storeMetadata) {
                    // migration not required!

                    log(.info, "Store is at latest model version, no migration required.")
                    migrationDelegate?.persistentContainer(self, willNotMigrateStore: description, storeExists: true)
                } else {
                    // go go migration
                    let migratedStore = try migrateStore(description: description,
                                                         storeMetadata: storeMetadata,
                                                         tempDirectory: tempDirectory)
                    migratedStores.append(migratedStore)
                }

                successfulDescriptions.insert(description)
            } catch {
                log(.error, "Store \(description.fileURL) migration failed - error \(error)")
                migrationDelegate?.persistentContainer(self, didFailToMigrateStore: description, error: error)

                errorCallback(description, error)
                allSuccessful = false
            }
            log(.info, "END work for store \(description.fileURL)")
        }

        log(.info, "All stores processed for migration.")

        // Release the graph details
        modelVersionGraph = nil

        // PHASE 2 - REPLACEMENT

        // If we migrated any stores, and all migrations went OK, move everything into
        // the right location.  Anything fails -> nothing ends up migrated.

        if allSuccessful && migratedStores.count > 0 {
            log(.info, "All migrations successful.  Moving stores back to correct locations.")
            migratedStores.forEach { store in
                let description = store.description
                log(.info, "Moving migrated store from \(store.tempURL) back to \(description.fileURL)")

                do {
                    try description.replaceStore(with: store.tempURL, coordinator: persistentStoreCoordinator)
                    migrationDelegate?.persistentContainer(self, didMigrateStore: description)
                } catch {
                    // failed at the last hurdle :(
                    log(.error, "Store \(description.fileURL) migration failed during replacement - error \(error)")
                    migrationDelegate?.persistentContainer(self, didFailToMigrateStore: description, error: error)

                    errorCallback(description, error)
                    successfulDescriptions.remove(description)
                    allSuccessful = false
                }
            }
        }

        // PHASE 3 - CLEANUP

        // Finally we know if all went well.
        // If it didn't then spot stores that need to get failed because of their peers.
        if !allSuccessful {
            successfulDescriptions.forEach { description in
                log(.error, "Sending coreqMigrationFailed for \(description.fileURL)")
                errorCallback(description, MigrationError.coreqMigrationFailed(description))
            }
        }

        // Clean up any temporary info
        if tempDirectory.exists {
            log(.info, "Deleting temp files from \(tempDirectory.directoryURL)")
            tempDirectory.deleteAll()
        }
    }

    /// Migration of a single store.  Attempt to migrate the store described by 'description' that
    /// currently has metadata 'storeMetadata' up to a model version compatible with the
    /// 'managedObjectModel' property of the container.
    func migrateStore(description: NSPersistentStoreDescription,
                      storeMetadata: PersistentStoreMetadata,
                      tempDirectory: TemporaryDirectory) throws -> MigratedStore {
        log(.info, "Store requires migration.")

        let graph = try graphForStoreMigration(description: description)

        let migrationSteps = try migrationStepsForStoreMigration(description: description,
                                                                 storeMetadata: storeMetadata,
                                                                 graph: graph)

        let totalSteps = migrationSteps.count

        log(.info, "Migration path found with \(totalSteps) steps.")
        migrationDelegate?
            .persistentContainer(self,
                                 willMigrateStore: description,
                                 sourceModelVersion: migrationSteps[0].source,
                                 destinationModelVersion: migrationSteps[totalSteps-1].destination,
                                 totalSteps: totalSteps)

        var currentStoreURL = description.fileURL
        var stepsRemaining  = totalSteps

        try migrationSteps.forEach { edge in
            let newStoreURL      = try tempDirectory.createNewFile()
            let migrationManager = edge.createMigrationManager()

            log(.info, "Starting migration of store at from version \(edge.source) to version \(edge.destination)")
            log(.info, "From store \(currentStoreURL)")
            log(.info, "To temp store \(newStoreURL)")

            migrationDelegate?
                .persistentContainer(self,
                                     willSingleMigrateStore: description,
                                     sourceModelVersion: edge.source,
                                     destinationModelVersion: edge.destination,
                                     usingInferredMapping: edge.isInferred,
                                     withMigrationManager: migrationManager,
                                     toTemporaryLocation: newStoreURL,
                                     stepsRemaining: stepsRemaining,
                                     totalSteps: totalSteps)

            try migrationManager.migrateStore(from: currentStoreURL,
                                              sourceType: description.type,
                                              options: description.options,
                                              with: edge.mappingModel,
                                              toDestinationURL: newStoreURL,
                                              destinationType: description.type,
                                              destinationOptions: description.options)
            // Update for next migration
            currentStoreURL = newStoreURL
            stepsRemaining -= 1
        }

        // Now we leave the migrated store in its temp location until all other stores have
        // been done as well -- then we will copy them up.
        let migratedStore = MigratedStore(description: description, tempURL: currentStoreURL)

        // sanity check
        try checkCompatibility(ofStore: migratedStore)

        log(.info, "All migrations steps complete.")

        return migratedStore
    }

    /// Find the version graph appropriate for this store + user options
    private func graphForStoreMigration(description: NSPersistentStoreDescription) throws -> ModelVersionGraph {
        let universalGraph: ModelVersionGraph

        universalGraph = modelVersionGraph ?? {
            let graph = ModelVersionGraph(logMessageHandler: logMessageHandler)
            graph.discover(from: bundles)
            modelVersionGraph = graph
            return graph
        }()

        guard let storeVersionOrder = modelVersionOrder.prepare(for: description) else {
            log(.error, "ModelVersionOrder \(self.modelVersionOrder) prepare failed for \(description.fileURL)")
            throw MigrationError.badModelVersionOrder(description, modelVersionOrder)
        }

        return universalGraph.filtered(order: storeVersionOrder,
                                       allowInferredMappings: description.shouldInferMappingModelAutomatically)
    }

    /// Calculate the individual migrations required to migrate a store up to the model's requirements.
    /// Throw an error if this is not possible.
    private func migrationStepsForStoreMigration(description: NSPersistentStoreDescription,
                                                 storeMetadata: PersistentStoreMetadata,
                                                 graph: ModelVersionGraph) throws -> [ModelVersionEdge] {

        guard let startNode = graph.nodeForStoreMetadata(storeMetadata, configuration: description.configuration) else {
            log(.error, "Can't find model for store metadata \(storeMetadata) with configuration \(description.configuration)")
            graph.logNodeMetadata(.error)
            throw MigrationError.cannotFindSourceModel(description, storeMetadata)
        }

        guard let endNode = graph.nodeForObjectModel(managedObjectModel) else {
            log(.error, "Can't find model for supplied model (!) with metadata \(self.managedObjectModel.entityHashDescription)")
            graph.logNodeMetadata(.error)
            throw MigrationError.cannotFindDestinationModel(description, managedObjectModel)
        }

        // Get list of migration steps to perform
        return try graph.findPath(source: startNode, destination: endNode)
    }

    // Helper - is the store at a url compatible with the model
    func checkCompatibility(ofStore store: MigratedStore) throws {
        let newStoreDescription = store.description.clone()
        newStoreDescription.url = store.tempURL

        let newStoreMetadata = try newStoreDescription.loadStoreMetadata()

        if newStoreMetadata == nil ||
            !managedObjectModel.isConfiguration(withName: newStoreDescription.configuration,
                                                compatibleWithStoreMetadata: newStoreMetadata!) {
            log(.error, "Completed all migrations but resulting store is not compatible with the model.")
            log(.error, "Model metadata is \(self.managedObjectModel.entityHashDescription)")
            log(.error, "Store metadata is \(newStoreMetadata)")
            throw MigrationError.logicFailure("Migrated store incompatible with MOM.")
        }
    }

    // An SQLite store that is destroyed using NSPersistentContainer.destroyPersistentStore() and then
    // queried via NSPSC.metadataForPerStore() ends up with some poison metadata that prevents all
    // attempts to load the store.  See TestBugs.testDestroyContainerBreaksMetadataForPersistentStore()
    //
    // Spot that case here - caller will work around by destroying the store again...
    //
    private func describesDestroyedStore(metadata: PersistentStoreMetadata) -> Bool {
        if let storeType = metadata[NSStoreTypeKey] as? String,
            storeType == NSSQLiteStoreType,
            metadata[NSStoreModelVersionHashesKey] == nil,
            metadata[NSStoreModelVersionIdentifiersKey] == nil {

            return true
        }
        return false
    }
}
