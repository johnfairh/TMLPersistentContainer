//
//  Graph.swift
//  TMLPersistentContainer
//
//  Distributed under the ISC license, see LICENSE.
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
// - when comparing two paths, compare only the parts that differ: in practice
//   this means discarding any common prefix.
//
// Path 'distance' is modelled by the Distance struct that describes how many
// of each type of edge it contains.  The < relation on it implements the first
// two requirements above.  The third requirement is handled by `Path.isBetter(than:)`.
//
// [1] ie. 'things can get better' - if we have a path (e:0 i:3) and discover
//     a new path of (e:0 i:4) we cannot prune that search (as in Dijkstra)
//     because we may discover a further path of (e:1 i:4) which is "shorter"
//     than (e:0 i:3)
//
// This code is factored out from the core-data dependent classes for easier
// testing.

// TODO
// * Optimize path distance counters - bit tricky though.

/// Edge in the graph.  Implemented concretely in product by ModelVersionEdge.
protocol GraphEdge: Equatable {
    var source: String { get }
    var destination: String { get }
    var isInferred: Bool { get }
}

/// Summary of a migration path in terms of the number of explicit and inferred
/// migrations on it.  Knows how to compare two such.
fileprivate struct Distance: CustomStringConvertible {
    let inferredEdges: Int
    let explicitEdges: Int

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

/// A path -- ordered list of edges -- through a graph.
/// Used as per-node workspace during solving to track the current
/// shortest path to the node.
fileprivate struct Path<Edge: GraphEdge>: CustomStringConvertible {
    let edges: [Edge]

    init(edges: [Edge] = []) {
        self.edges = edges
    }

    private var distance: Distance {
        let inferred = edges.reduce(0) { result, edge in
            result + (edge.isInferred ? 1 : 0)
        }
        return Distance(inferredEdges: inferred, explicitEdges: edges.count - inferred)
    }

    /// Create a new path by appending `edge` to our path.
    func pathWith(edge: Edge) -> Path {
        var newEdges = edges
        newEdges.append(edge)
        return Path(edges: newEdges)
    }

    private func pathAfterPrefix(_ count: Int) -> Path {
        return Path(edges: Array(edges.suffix(from: count)))
    }

    /// A path is better if its distance is less, AFTER
    /// discarding any common shared path prefix.
    func isBetter(than: Path<Edge>) -> Bool {
        let prefix = edges.commonPrefix(with: than.edges)
        let uncommonSelfPath = pathAfterPrefix(prefix)
        let uncommonThanPath = than.pathAfterPrefix(prefix)
        return uncommonSelfPath.distance < uncommonThanPath.distance
    }

    var description: String {
        var desc = distance.description + "[" + edges.map { edge in
            "\(edge.source)|\(edge.isInferred ? "i" : "e")"
        }.joined(separator: ",")
        if let end = edges.last {
            desc += ",\(end.destination)"
        }
        return "\(desc)]"
    }
}

/// Wrapper structure for shortest-path algorithm

@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
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
    ///   Although probably more given updated path-comparison calculations
    func findPath(source: String, destination: String) throws -> [Edge] {
        log(.info, "Looking for path from \(source) to \(destination)")
        guard source != destination else {
            log(.warning, "Found trivial path.")
            return []
        }

        var nodePaths: [String:Path<Edge>] = [:]

        // Solve

        nodePaths[source] = Path()

        for _ in 1..<nodeCount {
            var changed = false
            log(.debug, "Starting new b-f iteration")

            try edges.forEach { edge in
                log(.debug, " Consider \(edge)")
                guard let edgeSourcePath = nodePaths[edge.source] else {
                    log(.debug, "  No path to source, skipping.")
                    return
                }

                let pathToDestinationViaSource = edgeSourcePath.pathWith(edge: edge)
                var better = false

                log(.debug, "  Path to \(edge.destination) via edge is \(pathToDestinationViaSource)")

                if let edgeDestinationState = nodePaths[edge.destination] {
                    if pathToDestinationViaSource.isBetter(than: edgeDestinationState) {
                        log(.debug, "  Better than current path \(edgeDestinationState), keeping.")
                        better = true
                    } else {
                        log(.debug, "  Not better than current path \(edgeDestinationState)")
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
                    nodePaths[edge.destination] = pathToDestinationViaSource
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

        // Negacycle check

        try edges.forEach { edge in
            if let edgeSourceState = nodePaths[edge.source],
                let edgeDestinationState = nodePaths[edge.destination],
                edgeSourceState.pathWith(edge: edge).isBetter(than: edgeDestinationState) {
                log(.error, "Graph problem, cheaper to take \(edge) than use existing path.")
                log(.error, " Source path \(edgeSourceState)")
                log(.error, " Dest path \(edgeDestinationState)")
                throw MigrationError.cyclicRoute1(source, destination)
            }
        }

        log(.debug, "No negative cycles detected, checking for path.")

        guard let path = nodePaths[destination] else {
            log(.error, "No path exists from \(source) to \(destination)")
            throw MigrationError.noRouteBetweenModels(source, destination)
        }

        // Sanity checks the path is valid -- in the absence of code bugs these are probably
        // not required.
        if let firstEdge = path.edges.first, let lastEdge = path.edges.last {
            guard firstEdge.source == source, lastEdge.destination == destination else {
                let errorMsg = "Unexpected path found between \(firstEdge.source) and \(lastEdge.destination)"
                log(.error, errorMsg)
                throw MigrationError.logicFailure(errorMsg)
            }
            if !path.edges.map({ $0.source }).hasUniqueElements {
                log(.error, "Path \(path) contains cycles")
                throw MigrationError.cyclicRoute2(source, destination)
            }
        }

        log(.info, "Found path \(path.edges)")
        return path.edges
    }
}
