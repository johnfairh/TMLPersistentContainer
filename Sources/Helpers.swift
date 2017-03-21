//
//  Helpers.swift
//  TMLPersistentContainer
//
//  Created by John Fairhurst on 06/03/2017.
//  Copyright © 2017 Too Many Ladybirds. All rights reserved.
//

import Foundation
import CoreData

// MARK: Additions to Foundation.FileManager

@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
extension FileManager {

    /// Get a new temporary directory.  Caller must delete.
    func newTemporaryDirectoryURL() throws -> URL {
        let directoryURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try createDirectory(at: directoryURL, withIntermediateDirectories: false)
        return directoryURL
    }

    /// Get a new temporary file.  Caller must delete.
    func temporaryFileURL(inDirectory directory: URL? = nil) -> URL {
        let filename     = UUID().uuidString
        let directoryURL = directory ?? temporaryDirectory
        return directoryURL.appendingPathComponent(filename)
    }
}

/// More wrappers for temp file patterns
@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
class TemporaryDirectory {
    private(set) var directoryURL: URL?

    var exists: Bool {
        return directoryURL != nil
    }

    func createNewFile() throws -> URL {
        if directoryURL == nil {
            directoryURL = try FileManager.default.newTemporaryDirectoryURL()
        }
        return FileManager.default.temporaryFileURL(inDirectory: directoryURL)
    }

    func deleteAll() {
        if let directoryURL = directoryURL {
            try? FileManager.default.removeItem(at: directoryURL)
            self.directoryURL = nil
        }
    }
}

// MARK: Additions to Swift.String

extension String {

    /// Does the string precede `other` using `NSString.CompareOptions.numeric`?
    func precedesByNumericComparison(_ other: String) -> Bool {
        let selfNsString = self as NSString
        return selfNsString.compare(other, options: .numeric) == .orderedAscending
    }

    /// Return an NSRange corresponding to the entire string
    var nsRange: NSRange {
        return NSMakeRange(0, utf16.count)
    }

    /// Return the string corresponding to an NSRange, or empty if none
    subscript(nsRange: NSRange) -> String {
        let strLower = String.UTF16Index(nsRange.location)
        let strUpper = String.UTF16Index(nsRange.location + nsRange.length)

        return String(utf16[strLower..<strUpper]) ?? ""
    }
}

// MARK: Additions to Swift.Collection

extension Collection where Iterator.Element: Hashable {

    /// Does the collection consist of unique elements?
    /// - Complexity: O(n) with some squinting....
    var hasUniqueElements: Bool {
        var dict: [Iterator.Element:Bool] = [:]
        for s in self {
            if dict[s] != nil {
                return false
            }
            dict[s] = true
        }
        return true
    }
}

// MARK: Additions to Swift.Dictionary

extension Dictionary {

    /// Initialize a dictionary from a sequence of (Key,Value) tuples
    init<S>(_ seq: S) where S: Sequence, S.Iterator.Element == (Key, Value) {
        self.init()
        seq.forEach { self[$0.0] = $0.1 }
    }

    /// Return a new dictionary including just those (Key,Value) pairs incldued by the filter function
    func filtered(_ isIncluded: (Key, Value) throws -> Bool) rethrows -> Dictionary<Key, Value> {
        let filteredTuples: [(Key, Value)] = try filter(isIncluded)

        return Dictionary(filteredTuples)
    }
}

// MARK: Additions to Foundation.Bundle

extension Bundle {

    /// Return URLs for all files and directories optionally matching an extension within the bundle.
    func urlsRecursively(forResourcesWithExtension ext: String) -> [URL] {
        var urls: [URL] = []

        guard let enumerator = FileManager.default.enumerator(at: bundleURL, includingPropertiesForKeys: nil) else {
            // hmm
            return urls
        }

        for case let fileURL as URL in enumerator {
            let filename = fileURL.lastPathComponent
            if filename.hasSuffix(ext) {
                urls.append(fileURL)
            }
        }

        return urls
    }
}

// MARK: Additions to Foundation.NSRegularExpression

extension NSRegularExpression {

    /// Check if the pattern matches + return the matched string, either whole thing or 1st c.grp
    func matchesString(_ str: String) -> String? {
        let results = matches(in: str, range: str.nsRange)

        guard results.count == 1 else {
            return nil
        }

        let matchRange: NSRange

        if results[0].numberOfRanges == 1 {
            // entire match
            matchRange = results[0].rangeAt(0)
        } else {
            // first capture group
            matchRange = results[0].rangeAt(1)
        }

        return str[matchRange]
    }
}

// MARK: Additions to CoreData.NSManagedObjectModel

// NSData prints its bytes out, Data does not.  When debugging core data we want the bytes.
// See SR-2514.
extension NSManagedObjectModel {
    /// Return a string of the entity version hashes.
    var entityHashDescription: String {
        var str = ""
        var first = true
        entityVersionHashesByName.forEach { name, data in
            if !first { str = str + ", " }
            str = str + "(\(name): \(data as NSData))"
            first = false
        }
        return "[\(str)]"
    }

    /// Return a string of the entity version hashes for a particular config
    func entityHashDescription(forConfigurationName configuration: String?) -> String {
        var str = ""
        var first = true

        entities(forConfigurationName: configuration)?.forEach { ent in
            if !first { str = str + ", " }
            let entityName = ent.name ?? "(unnamed)" // gee thanks
            str = str + "(\(entityName): \(ent.versionHash as NSData))"
            first = false
        }
        return "[\(str)]"
    }
}
