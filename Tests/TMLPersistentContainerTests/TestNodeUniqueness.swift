//
//  TestNodeUniqueness.swift
//  TMLPersistentContainer
//
//  Created by John Fairhurst on 16/03/2017.
//  Copyright © 2017 Too Many Ladybirds. All rights reserved.
//

import XCTest
@testable import TMLPersistentContainer

//
// This file has tests for the unexpectedly disgusting 'spot duplicates and conflicts
// in the discovered core data models' code.  We abstract the data from the model node
// using a protocol so that we can unit-test here without having to mess around with
// hand-crafted core data models.
//

struct TestNode: NamedEntityVersion, Equatable {
    let name: String
    let entityVersionDescription: String

    init(_ name: String, _ version: String) {
        self.name = name
        self.entityVersionDescription = version
    }

    static func ==(lhs: TestNode, rhs: TestNode) -> Bool {
        return lhs.name == rhs.name &&
               lhs.entityVersionDescription == rhs.entityVersionDescription
    }
}


class TestNodeUniqueness: TestCase {

    let nodes = ModelVersionNodes(logMessageHandler: loggingCallback)

    let node1 = TestNode("N1", "V1")
    let node2 = TestNode("N2", "V2")
    let node3 = TestNode("N3", "V3")
    let node1_with_v2 = TestNode("N1", "V2")
    let node2_with_v1 = TestNode("N2", "V1")
    let node4_with_v1 = TestNode("N4", "V1")

    private func check(_ candidates: [TestNode], _ expected: [TestNode]) {
        let actual = nodes.uniquifyCandidateNodes(candidates)
        XCTAssertEqual(expected, actual)
    }

    func testNoNodes() {
        check([], [])
    }

    func testSingularNode() {
        check([node1], [node1])
    }

    func testNoDuplicates() {
        check([node1, node2], [node1, node2])
    }

    func testDuplicate() {
        check([node1, node2, node1], [node1, node2])
    }

    func testRepeatedNameWithDifferentVersion() {
        check([node1, node1_with_v2], [])
    }

    func testRepeatedNameWithDifferentVersionRepeatedAgain() {
        check([node1, node1_with_v2, node1], [])
    }

    func testRepeatedVersionWithDifferentName() {
        check([node1, node2, node2_with_v1], [])
    }

    func testRepeatedVersionWithDifferentNameRepeatedAgain() {
        check([node1, node2_with_v1, node3, node4_with_v1, node2, node1], [node3])
    }
}
