//
//  ModelVersionOrder.swift
//  TMLPersistentContainer
//
//  Distributed under the ISC license, see LICENSE.
//

import Foundation
import CoreData

/// A rule for ordering model versions.  The persistent container performs automatic multi-step
/// migration in the direction defined by this rule, which operates on the names of the model
/// version.
/// Note that the *model version* here is the part of its filename before '.xcdatamodel' --
/// *not* the optional 'Model Version Identifier' that you can set in the model's properties panel.
@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
public enum ModelVersionOrder {

    /// Compare the model versions directly, but interpreting numbers like a human -- using
    /// the `NSString.CompareOptions.numeric` algorithm, meaning that for example `MyModel_v2`
    /// precedes `MyModel_v10` and `MyModel_A` precedes `MyModel_B`.
    case compare

    /// Match each model version against a regular expression pattern.  Then compare either the
    /// entire match or, if it exists, the first capture group, using the `compare` algorithm.
    case patternMatchCompare(String)

    /// Match each model version against a compiled regular expression.  Then compare either the
    /// entire match or, if it exists, the first capture group, using the `compare` algorithm.
    case regexMatchCompare(NSRegularExpression)

    /// Explicitly list all the model versions in order.  The first element in the array is the
    /// the earliest version and the last is the latest version.  Model versions not in the list are
    /// not considered for migration.
    case list([String])

    /// Explicitly list the entire set of migration pairs that are permitted.  This can be seen as
    /// a stricter form of `.list` in that `.list(A, B, C)` will permit A->C but `.pairList((A,B), (B,C))`
    /// will not allow A->C in a single migration step.  The library checks for cycles in the described
    /// migrations.
    case pairList([(String,String)])

    /// Use a different order for different stores under the same container.
    case perStore((NSPersistentStoreDescription) -> ModelVersionOrder)
}

@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
extension ModelVersionOrder {

    /// Check user parameters are valid.  Compile any regex.
    func prepare(for storeDescription: NSPersistentStoreDescription) -> ModelVersionOrder? {
        switch self {
        case .compare:
            return self

        case .patternMatchCompare(let pattern):
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return nil
            }
            return .regexMatchCompare(regex)

        case .regexMatchCompare:
            return self

        case .list(let versions):
            if versions.count > 0 && versions.hasUniqueElements {
                return self
            } else {
                return nil
            }

        case .pairList(let pairList):
            if hasCycles(pairList) {
                return nil
            } else {
                return self
            }

        case .perStore(let orderCallback):
            return orderCallback(storeDescription).prepare(for: storeDescription)
        }
    }

    /// Check whether a model version is comparable according to this order.  Filters discovered versions.
    func valid(version: String) -> Bool {
        switch self {
        case .compare:
            return true

        case .patternMatchCompare:
            return false // should have 'prepared' first -- return false rather than panicking

        case .regexMatchCompare(let regex):
            return regex.matchesString(version) != nil

        case .list(let versions):
            return versions.contains(version)

        case .pairList(let pairList):
            return pairList.reduce(false) { result, element in
                result || element.0 == version || element.1 == version
            }

        case .perStore:
            return false // should have 'prepared' first -- return false rather than panicking
        }
    }

    /// Check whether two model versions are ordered.  Filters discovered migration mappings.
    func precedes(_ lhs: String, _ rhs: String) -> Bool {
        switch self {
        case .compare:
            return lhs.precedesByNumericComparison(rhs)

        case .patternMatchCompare:
            return false // should have 'prepared' first -- return false rather than panicking

        case .regexMatchCompare(let regex):
            let lhsValue = regex.matchesString(lhs)!
            let rhsValue = regex.matchesString(rhs)!
            return lhsValue.precedesByNumericComparison(rhsValue)

        case .list(let versions):
            guard let lhsIndex = versions.index(of: lhs),
                  let rhsIndex = versions.index(of: rhs) else {
                return false // should have been filtered out by 'valid' -- return false rather than panicking
            }
            return lhsIndex < rhsIndex

        case .pairList(let versionPairs):
            let pair = (lhs, rhs)
            return versionPairs.contains { p in p == pair }

        case .perStore:
            return false // should have 'prepared' first -- return false rather than panicking
        }
    }
}

@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
extension ModelVersionOrder: CustomStringConvertible {
    /// A human-readable description of the order
    public var description: String {
        switch self {
        case .compare:
            return ".compare"
        case .patternMatchCompare(let pattern):
            return ".patternMatchCompare(\(pattern))"
        case .regexMatchCompare(let regex):
            return ".regexMatchCompare(\(regex.pattern))"
        case .list(let list):
            return ".list(\(list))"
        case .pairList(let pairList):
            return ".pairList(\(pairList))"
        case .perStore:
            return ".perStore"
        }
    }
}

/// Good grief.... turn into a graph and check it...
func hasCycles(_ pairList: [(String,String)]) -> Bool {

    // first build edge cache
    var edges: [String:Set<String>] = [:]
    pairList.forEach { from, to in
        var currentEdges = edges[from] ?? []
        currentEdges.insert(to)
        edges[from] = currentEdges
    }

    // where can paths legitimately start?
    let startingVertices = pairList.map { $0.0 }

    // check each in turn for cycles
    for start in startingVertices {
        // record where we've been
        var visited: Set<String> = []

        // use this recursively to explore, return nil if OK else cyclic path
        func visit(_ vertex: String) -> [String]? {
            guard !visited.contains(vertex) else {
                // cycle! start returning the cyclic path
                return [vertex]
            }
            visited.insert(vertex)
            guard let nextVertices = edges[vertex] else {
                // no way out, done
                return nil
            }
            for nextVertex in nextVertices {
                if let cyclicPath = visit(nextVertex) {
                    // cycle involving us
                    return [vertex] + cyclicPath
                }
            }

            // all edges check out OK
            return nil
        }

        if /*let cyclicPath = */ nil != visit(start) {
            // cyclic path at top level
            // oops I can't report it anywhere.  Oh well.
            //print("AHA cycle: \(cyclicPath)")
            return true                           /* EXIT FUNCTION */
        }
    }

    // guess no cycles then
    return false
}
