//
//  ModelVersionGraph.swift
//  TMLPersistentContainer
//
//  Created by John Fairhurst on 17/01/2017.
//  Copyright © 2017 Too Many Ladybirds. All rights reserved.
//

import Foundation
import CoreData

/// Manage the graph of model versions and generate routes through it.
/// Class is a container + facade onto the nodes + edges classes, and
/// does type-translation to the graph solver.
///
struct ModelVersionGraph: LogMessageEmitter {
    let logMessageHandler: LogMessage.Handler?
    
    let nodes: ModelVersionNodes
    let edges: ModelVersionEdges
}

extension ModelVersionGraph {

    /// Initialize a new, empty graph
    init(logMessageHandler: LogMessage.Handler?) {
        self.logMessageHandler = logMessageHandler
        nodes = ModelVersionNodes(logMessageHandler: logMessageHandler)
        edges = ModelVersionEdges(logMessageHandler: logMessageHandler)
    }

    /// Create a new graph
    func filtered(order: ModelVersionOrder, allowInferredMappings: Bool) -> ModelVersionGraph {
        let newGraph = ModelVersionGraph(logMessageHandler: logMessageHandler,
                                         nodes: nodes.filtered(order: order),
                                         edges: edges.filtered(order: order, allowInferredMappings: allowInferredMappings))

        newGraph.logAll(.info, "Filtered graph under order \(order) with allowInferredMappings \(allowInferredMappings):")
        return newGraph
    }

    /// Analyze the model and mapping model files and build the migration graph between them
    func discover(from bundles: [Bundle]) {
        log(.info, "Starting model discovery from bundles \(bundles)")
        nodes.discover(from: bundles)
        edges.discover(from: bundles, between: nodes.nodes)
        logAll(.info, "Model graph discovery complete:")
    }

    /// Log the summary contents of the graph
    func logAll(_ level: LogLevel, _ message: String) {
        log(level, message)
        log(level, "Model graph nodes: \(self.nodes.nodes)")
        log(level, "Model graph edges: \(self.edges.edges)")
    }

    /// Log the details of discovered node metadata
    func logNodeMetadata(_ level: LogLevel) {
        nodes.logMetadata(level)
    }

    /// Find the starting point in the graph
    func nodeForStoreMetadata(_ storeMetadata: PersistentStoreMetadata, configuration: String?) -> ModelVersionNode? {
        return nodes.nodeForStoreMetadata(storeMetadata, configuration: configuration)
    }

    /// Find the ending point in the graph
    func nodeForObjectModel(_ objectModel: NSManagedObjectModel) -> ModelVersionNode? {
        return nodes.nodeForObjectModel(objectModel)
    }

    /// Find the best path through the versions or throw if there is none
    func findPath(source: ModelVersionNode, destination: ModelVersionNode) throws -> [ModelVersionEdge] {
        precondition(source != destination, "Logic error - no migration required")

        let graph = Graph(nodeCount: nodes.nodes.count, edges: edges.edges, logMessageHandler: logMessageHandler)
        return try graph.findPath(source: source.name, destination: destination.name)
    }
}
