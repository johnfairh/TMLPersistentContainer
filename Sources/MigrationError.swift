//
//  MigrationError.swift
//  TMLPersistentContainer
//
//  Created by John Fairhurst on 22/02/2017.
//  Copyright © 2017 Too Many Ladybirds. All rights reserved.
//

import Foundation
import CoreData

/// Errors that can occur preventing persistent store loading, passed into the callback given to
/// `PersistentContainer.loadPersistentStores`.
///
/// When any of these unusual conditions occurs, the persistent container provides a lot of
/// human-readable (-ish) information to the logging interface.  The first step to debugging
/// one of these errors is to read that text and try to make sense of it.
///
public enum MigrationError: Error {

    /// The persistent store has not been loaded because another store associated with the persistent
    /// container required migration but there was an error attempting to migrate it.  To avoid leaving
    /// the application with stores having a mixture of versions all store loading is prevented.
    case coreqMigrationFailed(NSPersistentStoreDescription)

    /// Migration cannot precede because the `ModelVersionOrder` for the store is invalid.
    /// This could mean:
    ///
    ///  * `.patternMatchCompare` - not a valid regular expression (according to `NSRegularExpression`);
    ///  * `.list` - empty list, or list contains repeated elements;
    ///  * `.pairList` - there is a cycle in the list of migrations.
    case badModelVersionOrder(NSPersistentStoreDescription, ModelVersionOrder)

    /// Migration cannot proceed because the persistent container cannot find a managed object model
    /// that is compatible with the persistent store's metadata in the bundles passed to
    /// `PersistentContainer.init`.
    /// The enum parameters are the particular store with the problem and the metadata of that
    /// store that cannot be matched to a model.
    case cannotFindSourceModel(NSPersistentStoreDescription, PersistentStoreMetadata)

    /// Migration cannot proceed because the persistent container cannot find a managed object model
    /// that matches the `NSManagedObjectModel` passed to `PersistentContainer.init(name:managedObjectModel:bundles:modelVersionOrder)`
    /// in the list of bundles.
    /// This means either a bundle is missing from the list or the `NSManagedObjectModel` has been
    /// created by merging several models -- this second use case is not currently supported by this library. Sorry.
    case cannotFindDestinationModel(NSPersistentStoreDescription, NSManagedObjectModel)

    /// Migration cannot proceed because the persistent container cannot find a migration path
    /// from the source model version (first string parameter) to the destination model version (second string
    /// parameter) using mapping models from the bundles passed to `PersistentContainer.init` combined
    /// with inferred mappings if enabled.  Possible reasons include:
    ///
    ///  * The `ModelVersionOrder` given to the container is too strict/incorrect;
    ///  * Intermediate data model versions have been incorrectly deleted from the app's bundles;
    ///  * Inferred mappings are required but have been disabled via `NSPersistentStoreDescription.shouldInferMappingModelAutomatically`;
    ///  * Mapping models have been incorrectly deleted from the app's bundles;
    ///  * The bundles given to the persistent container to search are wrong.
    case noRouteBetweenModels(String, String)

    /// Migration cannot proceed because the persistent container has got confused: after examining
    /// all the model versions and mapping models it has not been able to understand the fastest way
    /// of migrating between the two model versions named in the string parameters.
    /// This probably means there are cycles in the persistent container's `ModelVersionOrder`.
    case cyclicRoute1(String, String)

    /// Migration cannot proceed because the persistent container is confused: after examining all
    /// the model versions and mapping models it has not been able to understand the fastest way
    /// of migrating between the two model versions named in the string parameters.
    /// This also probably means there are cycles in the persistent container's `ModelVersionOrder`.
    case cyclicRoute2(String, String)

    /// Migration cannot proceed because the persistent container is confused: after examining all
    /// the model versions and mapping models it has found a path involving a mapping model that leads
    /// from the store's current model version back to itself.
    /// This ALSO probably means there are cycles in the persistent container's `ModelVersionOrder`.
    case cyclicRoute3(String, String)

    /// Migration has failed due to what seems to be a bug in the library code or, less likely, its
    /// dependencies.  Sorry about that.  A bug report including as full a log output as possible would
    /// be welcome.  The string parameter is a brief explanation of the problem.
    case logicFailure(String)
}

extension MigrationError: CustomStringConvertible {
    /// A human-readable description of the error
    public var description: String {
        switch self {
        case .coreqMigrationFailed:
            return "MigrationError.coreqMigrationFailed"
        case .badModelVersionOrder(let description, let order):
            return "MigrationError.badModelVersionOrder store at \(description.fileURL), order \(order)"
        case .cannotFindSourceModel(let description, let metadata):
            return "MigrationError.cannotFindSourceModel store at \(description.fileURL), metadata \(metadata)"
        case .cannotFindDestinationModel(let description, let model):
            return "MigrationError.cannotFindDestinationModel store at \(description.fileURL), model metadata \(model.entityVersionHashesByName)"
        case .noRouteBetweenModels(let source, let destination):
            return "MigrationError.noRouteBetweenModels source=\(source) destination=\(destination)"
        case .cyclicRoute1(let source, let destination):
            return "MigrationError.cyclicRoute1 source=\(source) destination=\(destination)"
        case .cyclicRoute2(let source, let destination):
            return "MigrationError.cyclicRoute1 source=\(source) destination=\(destination)"
        case .cyclicRoute3(let source, let destination):
            return "MigrationError.cyclicRoute1 source=\(source) destination=\(destination)"
        case .logicFailure(let description):
            return "MigrationError.logicFailure \(description)"
        }
    }
}
