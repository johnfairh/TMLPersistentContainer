//
//  SimpleModel.swift
//  TMLPersistentContainer
//
//  Created by John Fairhurst on 06/01/2017.
//  Copyright © 2017 Too Many Ladybirds. All rights reserved.
//

import Foundation
import CoreData

/// This file contains helpers for working with the Simple test model.
/// It hides some core data uglies.
/// More importantly, it lets us write code that addresses multiple versions of a model in the
/// same program -- we have core data generate different class names for the entity in its
/// different versions.
///
/// Real programs do not have this problem but because our purpose is to set up and exercise
/// migrations between different versions, we do.
final class SimpleModel {
    
    /// Name of the entity in the model
    static let entityName = "SimpleItem"

    /// Number of physical versions of the model that exist
    static let totalVersions = 3 + 2 + 1
    static let totalUniqueVersions = 3
    
    /// Simple query to get all objects.
    private static func getAllObjects(context: NSManagedObjectContext) -> [NSManagedObject] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: SimpleModel.entityName)
        var results: [NSManagedObject] = []
        
        doAlways("Fetch all \(SimpleModel.entityName)") {
            try results = context.fetch(fetchRequest)
        }
        
        return results
    }
    
    /// Get all objects from a V1 model
    static func getAllObjectsV1(context: NSManagedObjectContext) -> [SimpleItem_1] {
        guard let results = getAllObjects(context: context) as? [SimpleItem_1] else {
            fatalError("Can't cast query results to SimpleItem_1 -- wrong model version loaded")
        }
        return results
    }

    /// Get all objects from a V2 model
    static func getAllObjectsV2(context: NSManagedObjectContext) -> [SimpleItem_2] {
        guard let results = getAllObjects(context: context) as? [SimpleItem_2] else {
            fatalError("Can't cast query results to SimpleItem_2 -- wrong model version loaded")
        }
        return results
    }

    /// Get all objects from a V3 model
    static func getAllObjectsV3(context: NSManagedObjectContext) -> [SimpleItem_3] {
        guard let results = getAllObjects(context: context) as? [SimpleItem_3] else {
            fatalError("Can't cast query results to SimpleItem_3 -- wrong model version loaded")
        }
        return results
    }
    
    /// Find the number of objects in a store
    static func getObjectCount(context: NSManagedObjectContext) -> Int {
        return getAllObjects(context: context).count
    }
    
    // Object insertion.
    //
    // Caller is responsible for knowing what version of the model they are working with
    // and so using the right createVX function.
    //
    private static func create(context: NSManagedObjectContext) -> NSManagedObject {
        return NSEntityDescription.insertNewObject(forEntityName: SimpleModel.entityName, into: context)
    }
    
    /// Create a new object using the Simple_1 model
    static func createV1(id: String, context: NSManagedObjectContext) -> SimpleItem_1 {
        guard let v1 = create(context: context) as? SimpleItem_1 else {
            fatalError("Cannot cast object to SimpleItem_1 -- wrong model loaded")
        }
        
        v1.id = id
        return v1
    }

    /// Create a new object using the Simple_2 model
    static func createV2(id: Int32, context: NSManagedObjectContext) -> SimpleItem_2 {
        guard let v2 = create(context: context) as? SimpleItem_2 else {
            fatalError("Cannot cast object to SimpleItem_2 -- wrong model loaded")
        }
        
        v2.id = Int32(id)
        return v2
    }
    
    /// Create a new object using the Simple_3 model
    static func createV3(id: Int32, count: Int32, context: NSManagedObjectContext) -> SimpleItem_3 {
        guard let v3 = create(context: context) as? SimpleItem_3 else {
            fatalError("Cannot cast object to SimpleItem_3 -- wrong model loaded")
        }
        
        v3.id = id
        v3.count = id
        return v3
    }
}
