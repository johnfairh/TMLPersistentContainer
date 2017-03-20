//
//  ModelVersionNode.swift
//  TMLPersistentContainer
//
//  Created by John Fairhurst on 15/01/2017.
//  Copyright © 2017 Too Many Ladybirds. All rights reserved.
//

import Foundation
import CoreData

//
// This file deals with modelling and managing the 'nodes' in the version graph.
// Each node corresponds to a version of a managed object model that has been found in
// a bundle somewhere.
//
// Discovery of model versions is somewhat reverse-engineered although that may be
// more due to my failings in locating the documentation than lack of such.
//
// - Each xcdatamodeld from a project is compiled into a .momd directory in the target.
// - Each .momd contains a .mom for each model version in the xcdatamodeld and a single
//   VersionInfo.plist.  (There is no Info.plist, this is not a formal bundle)
// - The VersionInfo.plist is roughly [String:[String:[String:Data]]] where
//   - The outer key is singular and constant [assume for future changes to the plist]
//   - The middle key is the model version [NOT the optional Model Version Identifier]
//   - The inner key is the entity name and its value the hash used for model/store
//     compatibility checking.
//
// Discovery is simple then once the datatypes are understood - load them all up, and
// then process duplicates.
//

typealias EntityVersions = [String:Data]
typealias ModelEntityVersions = [String:EntityVersions]

/// We wrap a protocol around the node in order to unit-test some horrid corner cases
/// of discovery, see TestNodeUniqueness.swift.

protocol NamedEntityVersion {
    var name: String { get }
    var entityVersionDescription: String { get }
}

/// A node in the core data version graph
struct ModelVersionNode: NamedEntityVersion, Equatable, CustomStringConvertible {
    let name: String
    let model: NSManagedObjectModel

    init(name: String, model: NSManagedObjectModel) {
        self.name  = name
        self.model = model
    }

    static func ==(lhs: ModelVersionNode, rhs: ModelVersionNode) -> Bool {
        return lhs.name == rhs.name &&
               lhs.model.entityVersionHashesByName == rhs.model.entityVersionHashesByName
    }

    /// Is this version compatible with a particular persistent store under a particular configuration?
    /// (the `configuration` parameter is ignored by the Core Data API right now)
    func matchesStoreMetadata(_ storeMetadata: PersistentStoreMetadata, configuration: String?) -> Bool {
        return model.isConfiguration(withName: configuration, compatibleWithStoreMetadata: storeMetadata)
    }

    /// Is this version the 'same' as the one supplied by the user?
    /// We only care about the entity version matching because this is purely about migration.
    func matchesObjectModel(_ objectModel: NSManagedObjectModel) -> Bool {
        return objectModel.entityVersionHashesByName == model.entityVersionHashesByName
    }

    public var description: String {
        return name
    }

    var entityVersionDescription: String {
        return model.entityHashDescription
    }
}

/// The container for the core data model versions.
final class ModelVersionNodes: LogMessageEmitter {

    private var nodesByName: [String:ModelVersionNode]

    var nodes: [ModelVersionNode] {
        return Array(nodesByName.values)
    }

    let logMessageHandler: LogMessage.Handler?

    init(nodesByName: [String:ModelVersionNode] = [:], logMessageHandler: LogMessage.Handler?) {
        self.nodesByName = nodesByName
        self.logMessageHandler = logMessageHandler
    }

    subscript(nodeName: String) -> ModelVersionNode? {
        return nodesByName[nodeName]
    }

    /// Constants used for node discovery
    struct Constants {
        static let modelDirExtension   = "momd"
        static let modelExtension      = "mom"
        static let versionInfoFilename = "VersionInfo.plist"
        static let modelVersionsKey    = "NSManagedObjectModel_VersionHashes"
    }

    /// Search the provided bundles for managed object model version information
    func discoverCandidates(from bundles: [Bundle]) -> [ModelVersionNode] {

        // Find all .momd directories
        // Slightly concerned about recursive search, leave as default for now and
        // can turn into opt-in later if necessary.
        let modelDirURLs = bundles.map {
            $0.urlsRecursively(forResourcesWithExtension: Constants.modelDirExtension)
        }.joined()

        log(.info, "Found model directories: \(modelDirURLs)")

        // Load + deserialize the important part of their version plist
        let modelEntityVersions = modelDirURLs.flatMap { modelDirURL -> (URL, ModelEntityVersions)? in
            let infoURL = modelDirURL.appendingPathComponent(Constants.versionInfoFilename, isDirectory: false)

            guard let versions = NSDictionary(contentsOf: infoURL)?[Constants.modelVersionsKey] as? ModelEntityVersions else {
                log(.warning, "Could not load model version info from \(infoURL)")
                return nil
            }

            return (modelDirURL, versions)
        }

        var modelVersionNodes: [ModelVersionNode] = []

        modelEntityVersions.forEach { modelDirURL, modelEntityVersions in

            let modelDirNodes = modelEntityVersions.flatMap { versionName, entityVersions -> ModelVersionNode? in
                let modelURL = modelDirURL.appendingPathComponent(versionName + "." + Constants.modelExtension)
                guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
                    log(.warning, "Could not load \(modelURL) as NSManagedObjectModel.")
                    return nil
                }
                log(.info, "Found model \(versionName) from \(modelURL)")
                return ModelVersionNode(name: versionName, model: model)
            }

            modelVersionNodes.append(contentsOf: modelDirNodes)
        }

        return modelVersionNodes
    }

    /// Deduplicate and santize the list of discovered models.
    ///
    /// We need to end up with a list of models having unique names *and* unique entity
    /// versions (EVs).  The EV matching is painful so we rather rely on not having too many models
    /// discovered here (dozens OK, hundreds might be noticeable) and do exhaustive searching.
    ///
    /// The EV is important because it is fundamental to all core data model matching.
    /// The name is important because we use it to determine migration ordering via
    /// `ModelVersionOrder`.
    ///
    /// To do Our Thing, we rely on being able to unambiguously biject between Name and EV.
    ///
    /// Cases:
    ///  * Same name + same EV => duplicate file, silently discard one
    ///  * Same name + diff EV => discard all with this name
    ///  * Diff name + same EV => discard all with this EV
    ///  * Diff name + diff EV => ok
    ///
    func uniquifyCandidateNodes<Node>(_ candidateNodes: [Node]) -> [Node] where Node: NamedEntityVersion {
        var blackListedNodeNames:      Set<String> = []
        var blackListedEntityVersions: Set<String> = []

        var uniqueNodes: [Node] = []

        candidateNodes.forEach { candidate in
            if blackListedNodeNames.contains(candidate.name) {
                // candidate's name is already bad -- propagate badness to its EV
                blackListedEntityVersions.insert(candidate.entityVersionDescription)
                uniqueNodes = uniqueNodes.filter { $0.entityVersionDescription != candidate.entityVersionDescription }
            } else if blackListedEntityVersions.contains(candidate.entityVersionDescription) {
                // candidate's EV is already bad -- propagate badness to its name
                blackListedNodeNames.insert(candidate.name)
                uniqueNodes = uniqueNodes.filter { $0.name != candidate.name }
            } else {
                // candidate not known to be bad.  check it against each known-good.
                var canAdd = true
                var newUniqueNodes: [Node] = []

                for unique in uniqueNodes {
                    let sameName          = candidate.name == unique.name
                    let sameEntityVersion = candidate.entityVersionDescription == unique.entityVersionDescription

                    if sameName && sameEntityVersion {
                        // straight dup, don't add it but keep existing
                        canAdd = false
                        newUniqueNodes.append(unique)
                    } else if !sameName && !sameEntityVersion {
                        // completely different, add it + keep existing
                        newUniqueNodes.append(unique)
                    } else {
                        // overlap - blacklist everything including `unique` + `candidate`
                        canAdd = false
                        blackListedNodeNames.insert(candidate.name)
                        blackListedNodeNames.insert(unique.name)
                        blackListedEntityVersions.insert(candidate.entityVersionDescription)
                        blackListedEntityVersions.insert(unique.entityVersionDescription)
                    }
                }

                uniqueNodes = newUniqueNodes
                if canAdd {
                    uniqueNodes.append(candidate)
                }
            }
        }

        return uniqueNodes
    }

    /// Entrypoint to run all discovery phases and populate our dictionary
    func discover(from bundles: [Bundle]) {
        let candidateNodes = discoverCandidates(from: bundles)
        let uniqueNodes    = uniquifyCandidateNodes(candidateNodes)
        uniqueNodes.forEach { self.nodesByName[$0.name] = $0 }
    }

    /// Return the node that matches store metadata under the configuration
    func nodeForStoreMetadata(_ storeMetadata: PersistentStoreMetadata, configuration: String?) -> ModelVersionNode? {
        return nodes.filter { node in
            node.matchesStoreMetadata(storeMetadata, configuration: configuration)
        }.first
    }

    /// Return the node that totally matches an object model, or nil if none such
    func nodeForObjectModel(_ objectModel: NSManagedObjectModel) -> ModelVersionNode? {
        return nodes.filter { node in
            node.matchesObjectModel(objectModel)
        }.first
    }

    /// Return a new set of nodes that match the order
    func filtered(order: ModelVersionOrder) -> ModelVersionNodes {
        return ModelVersionNodes(nodesByName: nodesByName.filtered { name, _ in
            order.valid(version: name)
        }, logMessageHandler: logMessageHandler)
    }

    /// Dump discovered node metadata -- for debug when something is wrong
    func logMetadata(_ level: LogLevel) {
        let nodes = self.nodes
        log(level, "Discovered \(nodes.count) models")
        for i in 0..<nodes.count {
            log(level, "Model \(i) name=\(nodes[i].name) " +
                "managedObjectModel.entityVersionHashesByName=\(nodes[i].entityVersionDescription)")
        }
    }
}
