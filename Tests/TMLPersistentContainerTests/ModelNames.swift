//
//  Helpers.swift
//  TMLPersistentContainer
//
//  Created by John Fairhurst on 05/01/2017.
//  Copyright © 2017 Too Many Ladybirds. All rights reserved.
//

import Foundation
import CoreData

/// List of model files available for testing, containing different sets of model versions
/// These have to match the filenames on disk so we eschew the swift standard of leading lower-case!
enum ModelName: String {
    
    /// The Simple model contains a SimpleItem entity
    /// Version 1 - {id: String}
    /// Version 2 - {id: Int32}
    /// Version 3 - {id: Int32, count: Int32}
    
    /// Unversioned model containing version 1 of the SimpleItem entity
    case TestModel_Simple_1
    
    /// Versioned model containing version 1 + 2 of the SimpleItem entity
    case TestModel_Simple_2
    
    /// Versioned model containing versions 1 + 2 + 3 of the SimpleItem entity
    case TestModel_Simple_3

    /// A non-existent model
    case NonExistentModel

    /// A model that exists but cannot be loaded
    case TestModel_NotA

    /// The MultiConfig model contains two entities and two non-default configs
    /// Config1
    ///   Entity MultiItem1
    ///      Version 1 - {id1: String}
    ///      Version 2 - {id1: Int, counter1: Int}
    /// Config2
    ///   Entity MultiItem2
    ///      Version 1 - {id2: String}
    ///      Version 2 - {id2: Int, counter2: Int}

    /// Base version containing version 1 of both entities
    case TestModel_MultiConfig_1

    /// Versioned model containing versions 1 + 1 of both entities
    case TestModel_MultiConfig_2
}

