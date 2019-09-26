<!--
TMLPersistentContainer
README.md
Distributed under the ISC license, see LICENSE.
-->

# TMLPersistentContainer

[![CI](https://travis-ci.org/johnfairh/TMLPersistentContainer.svg?branch=master)](https://travis-ci.org/johnfairh/TMLPersistentContainer)
[![codecov](https://codecov.io/gh/johnfairh/TMLPersistentContainer/branch/master/graph/badge.svg)](https://codecov.io/gh/johnfairh/TMLPersistentContainer)
![Pod](https://cocoapod-badges.herokuapp.com/v/TMLPersistentContainer/badge.png)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
![Platforms](https://cocoapod-badges.herokuapp.com/p/TMLPersistentContainer/badge.png)
![License](https://cocoapod-badges.herokuapp.com/l/TMLPersistentContainer/badge.png)

Automatic shortest-path multi-step Core Data migrations in Swift.

![logo](SourceDocs/logo.png)

A Swift extension to Core Data's `NSPersistentContainer` that automatically
detects and performs multi-step store migration using the shortest valid
sequence of migrations. The library supports both light-weight and
heavy-weight migrations, multiple stores, progress reporting, and configurable
logging.

## Example

Minimally replace the call to `NSPersistentContainer.init`:

```swift
container = PersistentContainer(name: "MyStore",
                                managedObjectModel: model)
```

Additional parameters optionally enable more features:

```swift
container = PersistentContainer(name: "MyStore",
                                managedObjectModel: model,
                                bundles: [Bundle.main, myResBundle],
                                modelVersionOrder: .list("V_One", "V_Two", "V_Six"),
                                logMessageHandler: myLogHandler)
container.migrationDelegate = self
```

All migrations happen as part of `NSPersistentContainer.loadPersistentStores`.

## Documentation

* [User guide](https://johnfairh.github.io/TMLPersistentContainer/usage.html) and
[API documentation](https://johnfairh.github.io/TMLPersistentContainer/) online.
* Or in the docs/ folder of a local copy of the project.
* Docset for Dash etc. at [docs/docsets/TMLPersistentContainer.tgz](https://johnfairh.github.io/TMLPersistentContainer/docsets/TMLPersistentContainer.tgz)
* Read `TestSimpleMigrate.testCanMigrateV1toV3inTwoSteps` for an end-to-end
  example.


## Requirements

Swift 5 or later, Xcode 10.2 or later.
* See the *swift31* branch for a Swift 31 version.
* See the *swift4* branch for a Swift 4 version.
* See the *swift41* branch for a Swift 4.1 version.

The library is based on `NSPersistentContainer` so requires a minimum
deployment target of iOS 10.0, macOS 10.12, tvOS 10.0, or watchOS 3.0.

No additional software dependencies.

## Installation

CocoaPods:

    pod 'TMLPersistentContainer'

Swift package manager:

    .Package(url: "https://github.com/johnfairh/TMLPersistentContainer/", majorVersion: 3)

Carthage:

    github "johnfairh/TMLPersistentContainer"

## Contributions

Contributions and feedback welcome: open an issue / johnfairh@gmail.com / twitter @johnfairh

## License

Distributed under the ISC license.
