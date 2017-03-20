//
//  TestModelDiscovery.swift
//  TMLPersistentContainer
//
//  Created by John Fairhurst on 15/01/2017.
//  Copyright © 2017 Too Many Ladybirds. All rights reserved.
//

import XCTest
import CoreData
@testable import TMLPersistentContainer

/// Tests for model graph discovery.
/// These are unit tests of framework internals
///
class TestModelDiscovery: TestCase {

    func testCanDiscoverModelVersionsPiecemeal() {

        let nodes = ModelVersionNodes(logMessageHandler: loggingCallback)

        let candidateVersions = nodes.discoverCandidates(from: Bundle.allBundles)

        XCTAssertEqual(candidateVersions.count, SimpleModel.totalVersions + MultiConfigModel.totalVersions)

        let versions = nodes.uniquifyCandidateNodes(candidateVersions)

        XCTAssertEqual(versions.count, SimpleModel.totalUniqueVersions + MultiConfigModel.totalUniqueVersions)

        versions.forEach { version in
            if ModelName(rawValue: version.name) == nil {
                XCTFail("Can't make model name out of \(version.name)")
            }
        }
    }

    func testCanDiscoverModelVersionsCompound() {
        let nodes = ModelVersionNodes(logMessageHandler: loggingCallback)
        nodes.discover(from: Bundle.allBundles)

        XCTAssertEqual(nodes.nodes.count, SimpleModel.totalUniqueVersions + MultiConfigModel.totalUniqueVersions)

        nodes.nodes.forEach { version in
            if ModelName(rawValue: version.name) == nil {
                XCTFail("Can't make model name out of \(version.name)")
            }
        }
    }

    func testCanDiscoverExplicitMapping() {
        let nodes = ModelVersionNodes(logMessageHandler: loggingCallback)
        nodes.discover(from: Bundle.allBundles)

        guard let simpleV1 = nodes[ModelName.TestModel_Simple_1.rawValue],
              let simpleV2 = nodes[ModelName.TestModel_Simple_2.rawValue] else {
            XCTFail("Can't find nodes")
            return
        }

        let edges = ModelVersionEdges(logMessageHandler: loggingCallback)
        let edge = edges.discoverEdge(source: simpleV1, destination: simpleV2, from: Bundle.allBundles)

        if let edge = edge {
            XCTAssertEqual(edge.source, ModelName.TestModel_Simple_1.rawValue, "Bad source value")
            XCTAssertEqual(edge.destination, ModelName.TestModel_Simple_2.rawValue, "Bad target value")
            XCTAssertFalse(edge.isInferred, "Bad inferred value")
        } else {
            XCTAssertNotNil(edge, "Can't discover edge")
        }
    }

    func testCanDiscoverInferredMapping() {
        let nodes = ModelVersionNodes(logMessageHandler: loggingCallback)
        nodes.discover(from: Bundle.allBundles)

        guard let simpleV2 = nodes[ModelName.TestModel_Simple_2.rawValue],
              let simpleV3 = nodes[ModelName.TestModel_Simple_3.rawValue] else {
            XCTFail("Can't find nodes")
            return
        }

        let edges = ModelVersionEdges(logMessageHandler: loggingCallback)
        let edge = edges.discoverEdge(source: simpleV2, destination: simpleV3, from: Bundle.allBundles)

        if let edge = edge {
            XCTAssertEqual(edge.source, ModelName.TestModel_Simple_2.rawValue, "Bad source value")
            XCTAssertEqual(edge.destination, ModelName.TestModel_Simple_3.rawValue, "Bad target value")
            XCTAssertTrue(edge.isInferred, "Bad inferred value")
        } else {
            XCTAssertNotNil(edge, "Can't discover edge")
        }
    }

    func testCanDiscoverEdges() {

        let graph = ModelVersionGraph(logMessageHandler: loggingCallback)
        graph.discover(from: Bundle.allBundles)

        struct ExpectedEdge {
            let source: ModelName
            let destination: ModelName
            let isInferred: Bool
        }

        let expectedEdges = [ExpectedEdge(source: .TestModel_Simple_1, destination: .TestModel_Simple_2, isInferred: false),
                             ExpectedEdge(source: .TestModel_Simple_2, destination: .TestModel_Simple_3, isInferred: true),
                             ExpectedEdge(source: .TestModel_Simple_3, destination: .TestModel_Simple_2, isInferred: true),
                             ExpectedEdge(source: .TestModel_MultiConfig_1, destination: .TestModel_Simple_1, isInferred: true),
                             ExpectedEdge(source: .TestModel_MultiConfig_1, destination: .TestModel_Simple_2, isInferred: true),
                             ExpectedEdge(source: .TestModel_MultiConfig_1, destination: .TestModel_Simple_3, isInferred: true),
                             ExpectedEdge(source: .TestModel_Simple_1, destination: .TestModel_MultiConfig_1, isInferred: true),
                             ExpectedEdge(source: .TestModel_Simple_2, destination: .TestModel_MultiConfig_1, isInferred: true),
                             ExpectedEdge(source: .TestModel_Simple_3, destination: .TestModel_MultiConfig_1, isInferred: true),
                             ExpectedEdge(source: .TestModel_MultiConfig_2, destination: .TestModel_Simple_1, isInferred: true),
                             ExpectedEdge(source: .TestModel_MultiConfig_2, destination: .TestModel_Simple_2, isInferred: true),
                             ExpectedEdge(source: .TestModel_MultiConfig_2, destination: .TestModel_Simple_3, isInferred: true),
                             ExpectedEdge(source: .TestModel_Simple_1, destination: .TestModel_MultiConfig_2, isInferred: true),
                             ExpectedEdge(source: .TestModel_Simple_2, destination: .TestModel_MultiConfig_2, isInferred: true),
                             ExpectedEdge(source: .TestModel_Simple_3, destination: .TestModel_MultiConfig_2, isInferred: true),
                             ExpectedEdge(source: .TestModel_MultiConfig_1, destination: .TestModel_MultiConfig_2, isInferred: false)]

        XCTAssertEqual(graph.edges.edges.count, expectedEdges.count, "Bad number of edges discovered")

        expectedEdges.forEach { expectedEdge in
            let matchCount = graph.edges.edges.reduce(0) { soFar, edge in
                if edge.source == expectedEdge.source.rawValue &&
                   edge.destination == expectedEdge.destination.rawValue &&
                    edge.isInferred == expectedEdge.isInferred {
                    return soFar + 1
                } else {
                    return soFar
                }
            }
            XCTAssertEqual(matchCount, 1, "Found wrong number of matches for \(expectedEdge)")
        }
    }

    func testCanMapStoreToNode() {
        let container = createAndLoadStore(using: .TestModel_Simple_1, makeEmpty: true)

        _ = SimpleModel.createV1(id: "100", context: container.viewContext)
        saveChanges(container: container)

        let storeDescription = container.persistentStoreDescriptions[0]
        let storeMetadata = try! storeDescription.loadStoreMetadata()!

        let graph = ModelVersionGraph(logMessageHandler: loggingCallback)
        graph.discover(from: Bundle.allBundles)

        let node = graph.nodeForStoreMetadata(storeMetadata, configuration: nil)

        XCTAssertNotNil(node, "Couldn't find node for store")
        XCTAssertEqual(node!.name, ModelName.TestModel_Simple_1.rawValue, "Found wrong node! \(node)")

        // -ve test
        var badVersions = storeMetadata[NSStoreModelVersionHashesKey] as! EntityVersions
        badVersions["NotAnEntity"] = Data()
        var badStoreMetadata = storeMetadata
        badStoreMetadata[NSStoreModelVersionHashesKey] = badVersions

        let node2 = graph.nodeForStoreMetadata(badStoreMetadata, configuration: nil)

        XCTAssertNil(node2, "Managed to find a node for imaginary entity")
    }

    func testCanMapModelToNode() {
        let container = createAndLoadStore(using: .TestModel_Simple_1, makeEmpty: true)

        let graph = ModelVersionGraph(logMessageHandler: loggingCallback)
        graph.discover(from: Bundle.allBundles)

        let node = graph.nodeForObjectModel(container.managedObjectModel)

        XCTAssertNotNil(node, "Couldn't find node for model")
        XCTAssertEqual(node!.name, ModelName.TestModel_Simple_1.rawValue, "Found wrong node! \(node)")
    }
}
