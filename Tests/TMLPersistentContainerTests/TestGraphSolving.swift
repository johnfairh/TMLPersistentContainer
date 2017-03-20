//
//  TestGraphSolving.swift
//  TMLPersistentContainer
//
//  Created by John Fairhurst on 24/01/2017.
//  Copyright © 2017 Too Many Ladybirds. All rights reserved.
//

import XCTest
@testable import TMLPersistentContainer

//
// Exercise the graph path-finding algorithm.
//
class TestGraphSolving: TestCase {

    // An edge in our test model graph
    struct Edge: GraphEdge {
        let source: String
        let destination: String
        let isInferred: Bool

        init(_ source: String, _ destination: String, _ isInferred: Bool) {
            self.source = source
            self.destination = destination
            self.isInferred = isInferred
        }
    }

    // Some node names, standard start/end + intermediate node names
    let SOURCE = "Source"
    let TARGET = "Target"
    let INTER1 = "Inter1"
    let INTER2 = "Inter2"
    let INTER3 = "Inter3"
    let INTER4 = "Inter4"
    let INTER5 = "Inter5"
    let INTER6 = "Inter6"

    // Represent a test-case --- the graph + the expected results
    struct GraphTest {
        let nodeCount: Int
        let edges: [Edge]
        let path: [String]

        init(_ nodeCount: Int, _ edges: [Edge], _ path: [String]) {
            self.nodeCount = nodeCount
            self.edges = edges
            self.path = path
        }
    }

    // Execute a testcase -- build a graph + solve it, check the results
    func tryExecuteTest(_ test: GraphTest, source: String = "Source", target: String = "Target") throws {
        let graph = Graph(nodeCount: test.nodeCount, edges: test.edges, logMessageHandler: loggingCallback)

        let edgePath = try graph.findPath(source: source, destination: target)
        let nodePath = edgePath.map { $0.source } + [target]
        XCTAssertEqual(nodePath, test.path)
    }

    func executeTest(_ test: GraphTest, source: String = "Source", target: String = "Target") {
        do {
            try tryExecuteTest(test, source: source, target: target)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    // Notes for future self!
    // - because of the way we construct edges in the product, we cannot have both an I and an E
    //   edge between the same pair.  So the structures etc. do not deal with that -- do not
    //   construct them here.

    func testCanFindTrivialPath() {
        executeTest(GraphTest(1, [], [SOURCE]), target: SOURCE)
    }

    func testCanFindInferredPath() {
        executeTest(GraphTest(2, [Edge(SOURCE, TARGET, true)], [SOURCE, TARGET]))
    }

    func testCanFindExplicitPath() {
        executeTest(GraphTest(2, [Edge(SOURCE, TARGET, false)], [SOURCE, TARGET]))
    }

    func testCanPreferShortInferredToLongInferred() {
        executeTest(GraphTest(3, [Edge(SOURCE, INTER1, true),
                                  Edge(INTER1, TARGET, true),
                                  Edge(SOURCE, TARGET, true)],
                              [SOURCE, TARGET]))
    }

    func testCanPreferShortExplicitToLongExplicit() {
        executeTest(GraphTest(3, [Edge(SOURCE, INTER1, false),
                                  Edge(INTER1, TARGET, false),
                                  Edge(SOURCE, TARGET, false)],
                              [SOURCE, TARGET]))
    }

    func testCanPreferExplicitToInferred() {
        executeTest(GraphTest(3, [Edge(SOURCE, INTER1, true),
                                  Edge(INTER1, TARGET, false),
                                  Edge(SOURCE, TARGET, true)],
                              [SOURCE, INTER1, TARGET]))
    }

    func testCanReportNoPath() {
        do {
            try tryExecuteTest(GraphTest(2, [], []))
            XCTFail("Unexpected path found!")
        } catch MigrationError.noRouteBetweenModels(let source, let target) {
            print("No route from \(source) to \(target)")
        } catch {
            XCTFail("Unexpected error caught \(error)")
        }
    }

    // I'm too stupid to create a Type1Cycle OR prove it is impossible

    func testCanReportType2Cycle() {
        do {
            try tryExecuteTest(GraphTest(3, [Edge(SOURCE, INTER1, true),
                                             Edge(INTER1, TARGET, true),
                                             Edge(TARGET, INTER1, false)],
                                         []))
            XCTFail("Unexpected path found!")
        } catch MigrationError.cyclicRoute2(let source, let target) {
            print("Cyclic route detected between \(source) and \(target)")
        } catch {
            XCTFail("Unexpected error caught \(error)")
        }
    }

    func testCanReportType3Cycle() {
        do {
            try tryExecuteTest(GraphTest(3, [Edge(SOURCE, TARGET, true),
                                             Edge(SOURCE, INTER1, true),
                                             Edge(TARGET, SOURCE, false)],
                                         []))
            XCTFail("Unexpected path found!")
        } catch MigrationError.cyclicRoute3(let source, let target) {
            print("Cyclic route detected between \(source) and \(target)")
        } catch {
            XCTFail("Unexpected error caught \(error)")
        }
    }

    var largerGraphEdges: [Edge] { return [Edge(SOURCE, INTER1, true),
                                           Edge(INTER1, INTER2, false),
                                           Edge(SOURCE, INTER2, true),
                                           Edge(INTER2, TARGET, false),
                                           Edge(SOURCE, TARGET, true),
                                           Edge(INTER1, INTER3, true),
                                           Edge(INTER3, INTER4, true),
                                           Edge(INTER4, INTER5, true),
                                           Edge(INTER5, TARGET, false),
                                           Edge(INTER4, TARGET, true)] }

    let largerGraphNodeCount = 7

    func testCanDoLargerGraphs() {
        executeTest(GraphTest(largerGraphNodeCount, largerGraphEdges,
                              [SOURCE, INTER1, INTER3, INTER4, INTER5, TARGET]))
    }

    func testCanDoLargerGraphsIntermediate() {
        executeTest(GraphTest(largerGraphNodeCount, largerGraphEdges,
                              [INTER3, INTER4, INTER5, TARGET]),
                    source: INTER3)

        executeTest(GraphTest(largerGraphNodeCount, largerGraphEdges,
                              [INTER2, TARGET]),
                    source: INTER2)
    }
}
