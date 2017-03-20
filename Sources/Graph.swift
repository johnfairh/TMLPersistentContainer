//
//  Graph.swift
//  TMLPersistentContainer
//
//  Created by John Fairhurst on 24/01/2017.
//  Copyright © 2017 Too Many Ladybirds. All rights reserved.
//

import Foundation

// Routines for finding the correct route through the graph.
//
// We model this as a shortest-path problem and solve using Bellman-Ford
// because of negative weights[1].
//
// Requirement is loosely to never to skip explicit mapping models.
// More precisely:
// - always prefer a path with mapping models over one with inferred edges,
//   even if inferred path has fewer edges
// - given two paths both with mapping models, choose the one with fewer
//   edges.
//
// Path 'distance' is modelled by the Distance struct that describes how many
// of each type of edge it contains.  The < relation on it implements the
// requirements above.
//
// [1] ie. 'things can get better' - if we have a path (e:0 i:3) and discover
//     a new path of (e:0 i:4) we cannot prune that search (as in Dijkstra)
//     because we may discover a further path of (e:1 i:4) which is "shorter"
//     than (e:0 i:3)
//
// This code is factored out from the core-data depenent classes for easier
// testing.
//
// (not a generically useful graph library!)

/// Edge in the graph.  Implemented concretely in product by ModelVersionEdge.
protocol GraphEdge {
    var source: String { get }
    var destination: String { get }
    var isInferred: Bool { get }
}

/// Used during finding of shortest path to model path progress
fileprivate struct Distance: CustomStringConvertible {
    let inferredEdges: Int
    let explicitEdges: Int

    // (can't bring myself to use operator + for completely different types!)
    func addEdge(_ edge: GraphEdge) -> Distance {
        return Distance(inferredEdges: inferredEdges + (edge.isInferred ? 1 : 0),
                        explicitEdges: explicitEdges + (edge.isInferred ? 0 : 1))
    }

    static func <(lhs: Distance, rhs: Distance) -> Bool {
        if lhs.explicitEdges == rhs.explicitEdges {
            // Same number of explicit steps: prefer one with fewer inferred
            return lhs.inferredEdges < rhs.inferredEdges
        } else if lhs.explicitEdges == 0 {
            // Prefer some explicit to none
            return false
        } else if rhs.explicitEdges == 0 {
            // Prefer some explicit to none
            return true
        } else {
            // Prefer fewer (but not zero) explicit steps to more
            return lhs.explicitEdges < rhs.explicitEdges
        }
    }

    public var description: String {
        return "(e:\(explicitEdges) i:\(inferredEdges))"
    }
}

/// Wrapper structure for shortest-path algorithm

// First, workspace for Bellman-Ford.  Swift is Great so we can't nest this inside Graph yet ;)
fileprivate struct NodeState<Edge> where Edge: GraphEdge {
    let distance: Distance
    let viaEdge: Edge?

    init(distance: Distance, viaEdge: Edge? = nil) {
        self.distance = distance
        self.viaEdge = viaEdge
    }
}

struct Graph<Edge>: LogMessageEmitter where Edge: GraphEdge {
    private let nodeCount: Int
    private let edges: [Edge]
            let logMessageHandler: LogMessage.Handler?

    init(nodeCount: Int, edges: [Edge], logMessageHandler: LogMessage.Handler?) {
        self.nodeCount = nodeCount
        self.edges = edges
        self.logMessageHandler = logMessageHandler
    }

    /// Returns the shortest path from source to destination.
    /// - Complexity: O(number of edges * number of nodes)
    func findPath(source: String, destination: String) throws -> [Edge] {
        log(.info, "Looking for path from \(source) to \(destination)")
        guard source != destination else {
            log(.warning, "Found trivial path.")
            return []
        }

        var nodeStates: [String:NodeState<Edge>] = [:]

        // Solve

        nodeStates[source] = NodeState(distance: Distance(inferredEdges: 0, explicitEdges: 0))

        for _ in 1..<nodeCount {
            var changed = false
            log(.debug, "Starting new b-f iteration")

            try edges.forEach { edge in
                log(.debug, " Consider \(edge)")
                guard let edgeSourceState = nodeStates[edge.source] else {
                    log(.debug, "  No route to source, skipping.")
                    return
                }

                let distanceToDestinationViaSource = edgeSourceState.distance.addEdge(edge)
                var better = false

                log(.debug, "  Distance to \(edge.destination) via edge is \(distanceToDestinationViaSource)")

                if let edgeDestinationState = nodeStates[edge.destination] {
                    if distanceToDestinationViaSource < edgeDestinationState.distance {
                        log(.debug, "  Better than current distance \(edgeDestinationState.distance), keeping.")
                        better = true
                    } else {
                        log(.debug, "  Not better than current distance \(edgeDestinationState.distance)")
                    }
                } else {
                    log(.debug, "  First route to \(edge.destination), keeping.")
                    better = true
                }

                if better {
                    guard edge.destination != source else {
                        // unfortunately we have found a lower-cost path to where we already
                        // are than not moving.  This probably means there are backwards edges
                        // in the graph forming 'negative' cycles with the E flag.  This should
                        // be filtered out via the ModelVersionOrder.
                        log(.error, "Graph problem, found low-cost route to \(source) via \(edge)")
                        throw MigrationError.cyclicRoute3(edge.source, source)
                    }
                    nodeStates[edge.destination] = NodeState(distance: distanceToDestinationViaSource,
                                                             viaEdge: edge)
                    changed = true
                }
            }

            // get out if nothing changed this iteration
            if !changed {
                log(.debug, "No changes this iteration, stopping early.")
                break
            }
        }

        log(.debug, "All b-f iterations complete.")

        // Negacycle check (should not be possible but belt+braces...)

        try edges.forEach { edge in
            if let edgeSourceState = nodeStates[edge.source],
                let edgeDestinationState = nodeStates[edge.destination],
                edgeSourceState.distance.addEdge(edge) < edgeDestinationState.distance {
                log(.error, "Graph problem, cheaper to take \(edge) from \(edgeSourceState.distance) than \(edgeDestinationState.distance)")
                throw MigrationError.cyclicRoute1(source, destination)
            }
        }

        log(.debug, "No negative cycles detected, forming path.")

        // Build the path - from target back to source, then reverse it

        var path: [Edge]           = []
        var nextNodeName           = destination
        var nodesUsed: Set<String> = [destination]

        while nextNodeName != source {
            log(.debug, "Looking for edge leading to \(nextNodeName)")
            guard let nextEdge = nodeStates[nextNodeName]?.viaEdge else {
                log(.error, "No path exists from \(source) to \(destination), cannot find edge to \(nextNodeName)")
                throw MigrationError.noRouteBetweenModels(source, destination)
            }
            guard !nodesUsed.contains(nextEdge.source) else { // this guarantees loop termination
                log(.error, "No path exists from \(source) to \(destination), cycle involving \(nextEdge.source)")
                throw MigrationError.cyclicRoute2(source, destination)
            }
            log(.debug, "Found \(nextEdge)")
            nodesUsed.insert(nextEdge.source)
            nextNodeName = nextEdge.source
            path.append(nextEdge)
        }

        let actualPath = Array(path.reversed())
        log(.info, "Found path \(actualPath)")
        return actualPath
    }
}
