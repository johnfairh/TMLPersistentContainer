//
//  MultiConfigModel.swift
//  TMLPersistentContainer
//
//  Created by John Fairhurst on 11/03/2017.
//  Copyright © 2017 Too Many Ladybirds. All rights reserved.
//

import Foundation
import CoreData

/// This file contains helpers for working with the MultiConfig test model.
/// It hides some core data uglies.
/// More importantly, it lets us write code that addresses multiple versions of a model in the
/// same program -- we have core data generate different class names for the entity in its
/// different versions.
///
/// Real programs do not have this problem but because our purpose is to set up and exercise
/// migrations between different versions, we do.
final class MultiConfigModel {

    /// Name of the entities in the model
    static let entity1Name = "MultiItem1"
    static let entity2Name = "MultiItem2"

    /// Name of the configs in the model
    static let config1Name = "Config1"
    static let config2Name = "Config2"

    /// Number of physical versions of the model that exist
    static let totalVersions = 1 + 2
    static let totalUniqueVersions = 2

    /// Simple query to get all objects.
    private static func getAllObjects(context: NSManagedObjectContext, entityName: String) -> [NSManagedObject] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        var results: [NSManagedObject] = []

        doAlways("Fetch all \(entityName)") {
            try results = context.fetch(fetchRequest)
        }

        return results
    }

    /// Get all Item1s from a V1 model
    static func getAllItem1sV1(context: NSManagedObjectContext) -> [MultiItem1_1] {
        guard let results = getAllObjects(context: context, entityName: MultiConfigModel.entity1Name) as? [MultiItem1_1] else {
            fatalError("Can't cast query results to MultiItem1_1 -- wrong model version loaded")
        }
        return results
    }

    /// Get all Item2s from a V1 model
    static func getAllItem2sV1(context: NSManagedObjectContext) -> [MultiItem2_1] {
        guard let results = getAllObjects(context: context, entityName: MultiConfigModel.entity2Name) as? [MultiItem2_1] else {
            fatalError("Can't cast query results to MultiItem2_1 -- wrong model version loaded")
        }
        return results
    }

    /// Get all Item1s from a V2 model
    static func getAllItem1sV2(context: NSManagedObjectContext) -> [MultiItem1_2] {
        guard let results = getAllObjects(context: context, entityName: MultiConfigModel.entity1Name) as? [MultiItem1_2] else {
            fatalError("Can't cast query results to MultiItem1_2 -- wrong model version loaded")
        }
        return results
    }

    /// Get all Item2s from a V2 model
    static func getAllItem2sV2(context: NSManagedObjectContext) -> [MultiItem2_2] {
        guard let results = getAllObjects(context: context, entityName: MultiConfigModel.entity2Name) as? [MultiItem2_2] else {
            fatalError("Can't cast query results to MultiItem2_2 -- wrong model version loaded")
        }
        return results
    }

    /// Find the number of objects in a store
    static func getItem1Count(context: NSManagedObjectContext) -> Int {
        return getAllObjects(context: context, entityName: MultiConfigModel.entity1Name).count
    }

    static func getItem2Count(context: NSManagedObjectContext) -> Int {
        return getAllObjects(context: context, entityName: MultiConfigModel.entity2Name).count
    }

    // Object insertion.
    //
    // Caller is responsible for knowing what version of the model they are working with
    // and so using the right createVX function.
    //
    private static func create(context: NSManagedObjectContext, entityName: String) -> NSManagedObject {
        return NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
    }

    /// Create a new item1 object using the V1 model
    static func createItem1V1(id: String, context: NSManagedObjectContext) -> MultiItem1_1 {
        guard let v1 = create(context: context, entityName: MultiConfigModel.entity1Name) as? MultiItem1_1 else {
            fatalError("Cannot cast object to MultiItem1_1 -- wrong model loaded")
        }

        v1.id1 = id
        return v1
    }

    /// Create a new item2 object using the V1 model
    static func createItem2V1(id: String, context: NSManagedObjectContext) -> MultiItem2_1 {
        guard let v1 = create(context: context, entityName: MultiConfigModel.entity2Name) as? MultiItem2_1 else {
            fatalError("Cannot cast object to MultiItem2_1 -- wrong model loaded")
        }

        v1.id2 = id
        return v1
    }

    /// Create a new item1 object using the V2 model
    static func createItem1V1(id: Int, context: NSManagedObjectContext) -> MultiItem1_2 {
        guard let v2 = create(context: context, entityName: MultiConfigModel.entity1Name) as? MultiItem1_2 else {
            fatalError("Cannot cast object to MultiItem1_1 -- wrong model loaded")
        }

        v2.id1 = Int32(id)
        return v2
    }

    /// Create a new item2 object using the V2 model
    static func createItem2V1(id: Int, context: NSManagedObjectContext) -> MultiItem2_2 {
        guard let v2 = create(context: context, entityName: MultiConfigModel.entity2Name) as? MultiItem2_2 else {
            fatalError("Cannot cast object to MultiItem2_2 -- wrong model loaded")
        }

        v2.id2 = Int32(id)
        return v2
    }
}
