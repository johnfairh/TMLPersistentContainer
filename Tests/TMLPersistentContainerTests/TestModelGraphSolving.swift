//
//  TestModelGraphSolving.swift
//  TMLPersistentContainer
//
//  Distributed under the ISC license, see LICENSE.
//

import Foundation
import CoreData
import XCTest
@testable import TMLPersistentContainer

/// Tests for model graph solving.
/// These are unit tests of framework internals
///
class TestModelGraphSolving: TestCase {

    static var graph: ModelVersionGraph!

    override class func setUp() {
        super.setUp()

        let uniGraph = ModelVersionGraph(logMessageHandler: loggingCallback)
        uniGraph.discover(from: Bundle.allBundles)

        guard let simpleOrder = ModelVersionOrder.patternMatchCompare(".*Simple.*").prepare(for: NSPersistentStoreDescription()) else {
            fatalError("Can't compile pattern...")
        }

        graph = uniGraph.filtered(order: simpleOrder, allowInferredMappings: true)
    }

    struct TestSpec {
        let source: ModelName
        let destination: ModelName
        let path: [ModelName]
    }

    func testCanFindOnlyAvailablePaths() {

        let testv1v2 = TestSpec(source: .TestModel_Simple_1, destination: .TestModel_Simple_2,
                                path: [.TestModel_Simple_1, .TestModel_Simple_2])
        let testv2v3 = TestSpec(source: .TestModel_Simple_2, destination: .TestModel_Simple_3,
                                path: [.TestModel_Simple_2, .TestModel_Simple_3])
        let testv1v3 = TestSpec(source: .TestModel_Simple_1, destination: .TestModel_Simple_3,
                                path: [.TestModel_Simple_1, .TestModel_Simple_2, .TestModel_Simple_3])

        let tests = [testv1v2, testv2v3, testv1v3]

        tests.forEach(executePathTest)
    }

    func testCanFindNoPathAfterFiltering() {

        let testv3v2 = TestSpec(source: .TestModel_Simple_3, destination: .TestModel_Simple_2,
                                path: [.TestModel_Simple_3, .TestModel_Simple_2])

        let filteredGraph = TestModelGraphSolving.graph.filtered(order: .compare, allowInferredMappings: true)

        executePathTest(spec: testv3v2, graph: filteredGraph, expectSuccess: false)
    }

    func testCanFilterOutInferredMappings() {

        let testv2v3 = TestSpec(source: .TestModel_Simple_2, destination: .TestModel_Simple_3,
                                path: [.TestModel_Simple_2, .TestModel_Simple_3])

        let filteredGraph = TestModelGraphSolving.graph.filtered(order: .compare, allowInferredMappings: false)

        executePathTest(spec: testv2v3, graph: filteredGraph, expectSuccess: false)
    }

    func testCanFilterOutInferredMappingsAndKeepExplicit() {

        let testv1v2 = TestSpec(source: .TestModel_Simple_1, destination: .TestModel_Simple_2,
                                path: [.TestModel_Simple_1, .TestModel_Simple_2])

        let filteredGraph = TestModelGraphSolving.graph.filtered(order: .compare, allowInferredMappings: false)

        executePathTest(spec: testv1v2, graph: filteredGraph, expectSuccess: true)
    }

    func testCanFindNoPath() {

        let testv2v1 = TestSpec(source: .TestModel_Simple_2, destination: .TestModel_Simple_1,
                                path: [.TestModel_Simple_2, .TestModel_Simple_1])

        executeNoPathTest(spec: testv2v1)
    }

    // Utility to execute tests against the global (unfiltered) graph and check the results
    func executePathTest(spec: TestSpec) {
        executePathTest(spec: spec, graph: TestModelGraphSolving.graph!, expectSuccess: true)
    }

    func executeNoPathTest(spec: TestSpec) {
        executePathTest(spec: spec, graph: TestModelGraphSolving.graph!, expectSuccess: false)
    }

    // Utility to execute a test against a specific graph
    func executePathTest(spec: TestSpec, graph: ModelVersionGraph, expectSuccess: Bool) {
        guard let source = graph.nodes[spec.source.rawValue] else {
            fatalError("Can't find graph node for \(spec.source)")
        }

        guard let destination = graph.nodes[spec.destination.rawValue] else {
            fatalError("Can't find graph node for \(spec.destination)")
        }

        do {
            let pathEdges = try graph.findPath(source: source, destination: destination)
            let pathNodes = pathEdges.map { $0.source } + [destination.name]

            if !expectSuccess {
                XCTFail("Unexpected success")
            }

            XCTAssertEqual(pathNodes.count, spec.path.count)

            zip(pathNodes, spec.path).forEach { (actual, expected) in
                XCTAssertEqual(actual, expected.rawValue)
            }
        } catch {
            if expectSuccess {
                XCTFail("Unexpected \(error)")
            }
        }
    }
}
