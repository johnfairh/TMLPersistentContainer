//
//  NSPersistentStoreDescription+Metadata.swift
//  TMLPersistentContainer
//
//  Distributed under the ISC license, see LICENSE.
//

import Foundation
import CoreData

/// The metadata of a Core Data persistent store.
///
/// Keys include `NSStoreTypeKey`, `NSStoreModelVersionHashesKey`, and `NSStoreModelVersionIdentifiersKey`.
internal typealias PersistentStoreMetadata = [String:Any]

/// Helpers to save typing and better locate function to do with stores/store descriptions.
@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
extension NSPersistentStoreDescription {

    /// The URL of the store's backing file
    var fileURL: URL {
        precondition(url != nil && url!.isFileURL)
        return url!
    }

    /// Read the metadata for the described store.
    ///
    /// - Returns: The `PersistentStoreMetadata` for the store, or `nil` if the store does not exist.
    /// - Throws: Filesystem access errors
    func loadStoreMetadata() throws -> PersistentStoreMetadata? {
        // Strict 'exists' check - permissions -> error thrown.
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        return try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: type, at: fileURL, options: options)
    }

    /// Safely destroy the described store - as long as it is backed by some file.
    ///
    /// - Parameter coordinator: An `NSPersistentStoreCoordinator` of some kind
    /// - Throws: Any filesystem access errors
    func destroyStore(coordinator: NSPersistentStoreCoordinator) throws {
        if let url = self.url, url.isFileURL {
            try coordinator.destroyPersistentStore(at: url, ofType: type, options: options)
        }
    }

    /// Replace the described store with another store.
    ///
    /// - Parameters:
    ///   - fromURL: Location of the store that will replace this one, must have all the same settings
    ///   - coordinator: An `NSPersistentCoordinator` of some kind
    /// - Throws: Any filesystem access errors
    func replaceStore(with fromURL: URL, coordinator: NSPersistentStoreCoordinator) throws {
        precondition(fromURL.isFileURL)

        // What a mess - the PSC.replacePersStore API appears to only work for SQLite3.
        // Testing against binary store shows that it 'works' if the source URL is missing,
        // leaving the dest URL unreplaced.  Not dug any deeper into filesystem errors.

        if type == NSSQLiteStoreType {
            try coordinator.replacePersistentStore(at: fileURL,
                                                   destinationOptions: options,
                                                   withPersistentStoreFrom: fromURL,
                                                   sourceOptions: options,
                                                   ofType: type)
        } else {
            try FileManager.default.replaceItem(at: fileURL,
                                                withItemAt: fromURL,
                                                backupItemName: nil,
                                                options: [.usingNewMetadataOnly],
                                                resultingItemURL: nil)
        }
    }

    /// Return a new object having the same settings as this one.
    func clone() -> NSPersistentStoreDescription {
        return copy() as! NSPersistentStoreDescription
    }
}
