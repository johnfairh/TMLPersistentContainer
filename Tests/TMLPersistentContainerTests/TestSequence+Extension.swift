//
//  TestSequence+Extension.swift
//  
//
//  Created by Jonas Reichert on 25.01.20.
//

import Foundation
import XCTest
@testable import TMLPersistentContainer

class TestSequenceExtension: XCTestCase {
    
    func testManagedObjectModelsWithNameEmpty() {
        XCTAssertEqual([Bundle]().managedObjectModels(with: ModelName.TestModel_Simple_1.rawValue), [])
    }
    
    func testManagedObjectModelsWithNameNoMomds() {
        let bundle = MockBundle(mockedURLs: [:])
        XCTAssertEqual([bundle].managedObjectModels(with: ModelName.TestModel_Simple_1.rawValue), [])
    }
    
    func testManagedObjectModelsWithNameNoMomdsWithName() {
        let name = "NoMomdLikeThat.momd"
        guard let url = URL(string: name) else {
            XCTFail("can't create URL for \(name) for some reason")
            return
        }
        
        let bundle = MockBundle(mockedURLs: [name: url])
        XCTAssertEqual([bundle].managedObjectModels(with: name), [])
    }
    
    func testManagedObjectModelsWithNameExtensionEdgeCase() {
        let name = "momd.notAMomd"
        
        guard let url = URL(string: name) else {
            XCTFail("can't create URL for \(name) for some reason")
            return
        }
        
        let bundle = MockBundle(mockedURLs: [name: url])
        XCTAssertEqual([bundle].managedObjectModels(with: ModelName.TestModel_Simple_1.rawValue), [])
    }
    
    func testManagedObjectModelsWithNameHappy() {
        guard let url1 = url(for: ModelName.TestModel_Simple_1.rawValue), let url2 = url(for: ModelName.TestModel_MultiConfig_1.rawValue) else {
            XCTFail("can't create URL for \(name) for some reason")
            return
        }
        
        let bundle = MockBundle(mockedURLs: [ModelName.TestModel_Simple_1.rawValue: url1])
        let bundle2 = MockBundle(mockedURLs: [ModelName.TestModel_MultiConfig_1.rawValue: url2])
        let result = [bundle, bundle2].managedObjectModels(with: ModelName.TestModel_Simple_1.rawValue)
        XCTAssertEqual(result, [loadManagedObjectModel(ModelName.TestModel_Simple_1)])
    }
    
    func testManagedObjectModelsWithNameHappy2() {
        guard let url1 = url(for: ModelName.TestModel_Simple_1.rawValue), let url2 = url(for: ModelName.TestModel_MultiConfig_1.rawValue) else {
            XCTFail("can't create URL for \(name) for some reason")
            return
        }
        
        let bundle = MockBundle(mockedURLs: [ModelName.TestModel_Simple_1.rawValue: url1])
        let bundle2 = MockBundle(mockedURLs: [ModelName.TestModel_MultiConfig_1.rawValue: url2])
        
        let result = [bundle, bundle2].managedObjectModels(with: ModelName.TestModel_MultiConfig_1.rawValue)
        XCTAssertEqual(result, [loadManagedObjectModel(ModelName.TestModel_MultiConfig_1)])
    }
}

struct MockBundle: BundleProtocol, Equatable {
    var mockedURLs = [String: URL]()
    
    init(mockedURLs: [String: URL]) {
        self.mockedURLs = mockedURLs
    }
    
    func url(forResource name: String?, withExtension ext: String?) -> URL? {
        guard let name = name else {
            return nil
        }
        
        return mockedURLs[name]
    }
}
