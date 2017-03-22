//
//  TestModelVersionOrder.swift
//  TMLPersistentContainer
//
//  Distributed under the ISC license, see LICENSE.
//

import XCTest
import CoreData
@testable import TMLPersistentContainer

/// Tests for the version ordering widget
///
class TestModelVersionOrder: TestCase {

    let dummyDescription = NSPersistentStoreDescription()

    // Helper -- check an order implements a total order...
    private func checkOrder(_ order: ModelVersionOrder, spec: [String]) {

        spec.forEach { XCTAssertTrue(order.valid(version: $0)) }

        for i in 0..<spec.count {
            let earlier = spec[0..<i]
            let this    = spec[i]
            let later   = spec[i+1..<spec.count]

            earlier.forEach {
                XCTAssertTrue(order.precedes($0, this))
                XCTAssertFalse(order.precedes(this, $0))
            }

            later.forEach {
                XCTAssertTrue(order.precedes(this, $0))
                XCTAssertFalse(order.precedes($0, this))
            }
        }
    }

    func testCanUseListOrder() {
        let versions = ["Ver3", "Ver1", "Ver2"]

        let order = ModelVersionOrder.list(versions)
        guard let preparedOrder = order.prepare(for: dummyDescription) else {
            XCTFail()
            return
        }

        XCTAssertFalse(order.valid(version:"Not a version"))

        checkOrder(preparedOrder, spec: versions)
    }

    func testCanDetectBadListOrder() {

        let badOrder1 = ModelVersionOrder.list([])
        XCTAssertNil(badOrder1.prepare(for: dummyDescription))

        let badOrder2 = ModelVersionOrder.list(["VER1", "VER2", "VER1"])
        XCTAssertNil(badOrder2.prepare(for: dummyDescription))
    }

    func testCanUseStringOrder() {
        let versions = ["Ver1", "Ver2", "Ver10", "Ver400", "Ver3000"]

        let order = ModelVersionOrder.compare
        guard let preparedOrder = order.prepare(for: dummyDescription) else {
            XCTFail()
            return
        }

        checkOrder(preparedOrder, spec: versions)
    }

    // Helper for regex-type orders
    private func prepareAndCheckNumericMatchOrder(_ order: ModelVersionOrder) {
        let versions = ["Bar1", "Foo20", "Baz1000"]

        guard let preparedOrder = order.prepare(for: dummyDescription) else {
            XCTFail()
            return
        }

        checkOrder(preparedOrder, spec: versions)
    }

    func testCanUsePatternOrderWithCaptureGroup() {
        let order = ModelVersionOrder.patternMatchCompare("(\\d+)")
        prepareAndCheckNumericMatchOrder(order)
    }

    func testCanUsePatternOrderWithoutCaptureGroup() {
        let order = ModelVersionOrder.patternMatchCompare("\\d+")
        prepareAndCheckNumericMatchOrder(order)
    }

    func testCanUseRegexOrder() {
        let order = ModelVersionOrder.regexMatchCompare(try! NSRegularExpression(pattern: "\\d+"))
        prepareAndCheckNumericMatchOrder(order)
    }

    func testCanUsePerStoreOrder() {
        func descriptionToOrder(description: NSPersistentStoreDescription) -> ModelVersionOrder {
            XCTAssertEqual(description, dummyDescription)
            return ModelVersionOrder.patternMatchCompare("\\d+")
        }

        let order = ModelVersionOrder.perStore(descriptionToOrder)
        prepareAndCheckNumericMatchOrder(order)
    }

    func testCanDetectBadRegex() {
        let order = ModelVersionOrder.patternMatchCompare("(")
        let preparedOrder = order.prepare(for: dummyDescription)

        XCTAssertNil(preparedOrder)
    }

    // Pair-list orders.
    func testCanUsePairList() {
        let order = ModelVersionOrder.pairList([("A", "B"), ("B", "C"), ("C", "D")])
        guard let preparedOrder = order.prepare(for: dummyDescription) else {
            XCTFail("Prepare failed")
            return
        }

        ["A", "B", "C", "D"].forEach {
            XCTAssertTrue(preparedOrder.valid(version: $0))
        }

        ["Z", ""].forEach {
            XCTAssertFalse(preparedOrder.valid(version: $0))
        }

        [("A", "B"), ("B", "C"), ("C", "D")].forEach { from, to in
            XCTAssertTrue(preparedOrder.precedes(from, to))
        }

        [("A", "C"), ("B", "A"), ("Q", "C"), ("C", "Q"), ("Q", "Z")].forEach { from, to in
            XCTAssertFalse(preparedOrder.precedes(from, to))
        }
    }

    func testCanDetectPairListCycle() {
        let order = ModelVersionOrder.pairList([("A", "B"), ("B", "C"), ("C", "A")])
        let preparedOrder = order.prepare(for: dummyDescription)
        XCTAssertNil(preparedOrder)
    }

    func testCanDetectBadPairListSelfCycle() {
        let order = ModelVersionOrder.pairList([("A", "A")])
        let preparedOrder = order.prepare(for: dummyDescription)
        XCTAssertNil(preparedOrder)
    }

    func testCanSafelyHandleApiMisuse() {
        let patternOrder = ModelVersionOrder.patternMatchCompare("Ab\\d+")
        XCTAssertFalse(patternOrder.valid(version: "AnyVersion"))
        XCTAssertFalse(patternOrder.valid(version: "Ab123"))
        XCTAssertFalse(patternOrder.precedes("Ab1", "Ab2"))
        XCTAssertFalse(patternOrder.precedes("Ab2", "Ab1"))

        let perStoreOrder = ModelVersionOrder.perStore( { _ in .compare } )
        XCTAssertFalse(perStoreOrder.valid(version: "AnyVersion"))
        XCTAssertFalse(perStoreOrder.valid(version: "Ab123"))
        XCTAssertFalse(perStoreOrder.precedes("Ab1", "Ab2"))
        XCTAssertFalse(perStoreOrder.precedes("Ab2", "Ab1"))

        let listOrder = ModelVersionOrder.list(["V1"])
        XCTAssertFalse(listOrder.precedes("V2", "V3"))
        XCTAssertFalse(listOrder.precedes("V1", "V2"))
        XCTAssertFalse(listOrder.precedes("V2", "V1"))
    }

    // this just tests the to-string routines do not crash....
    func testCanLogModelVersionOrders() {
        let o1 = ModelVersionOrder.compare
        let o2 = ModelVersionOrder.patternMatchCompare(".*")
        let o3 = ModelVersionOrder.regexMatchCompare(try! NSRegularExpression(pattern: ".*"))
        let o4 = ModelVersionOrder.list(["A", "B", "C"])
        let o5 = ModelVersionOrder.pairList([("A", "B"), ("C", "D")])
        let o6 = ModelVersionOrder.perStore({ _ in return ModelVersionOrder.compare})

        print("\(o1) \(o2) \(o3) \(o4) \(o5) \(o6)")
    }
}
