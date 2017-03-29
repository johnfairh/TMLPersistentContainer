<!--
TMLPersistentContainer
README.md
Distributed under the ISC license, see LICENSE.
-->

# TMLPersistentContainer

<!--
Badge thingies to get working:
* travis -- https://docs.travis-ci.com/user/status-images/
* coverage -- 
![CocoaPod](https://cocoapod-badges.herokuapp.com/v/TMLPersistentContainer/badge.png)
![Platforms](https://cocoapod-badges.herokuapp.com/p/TMLPersistentContainer/badge.png)
![License](https://cocoapod-badges.herokuapp.com/l/TMLPersistentContainer/badge.png)
-->

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

* [User guide](???) and [API documentation](???) online.
* Or in the docs/ folder of a local copy of the project.
* Docset for Dash etc. at docs/docsets/TMLPersistentContainer.tgz
* Read `TestSimpleMigrate.testCanMigrateV1toV3inTwoSteps` for an end-to-end
  example.


## Requirements

Swift 3.

The library is based on `NSPersistentContainer` so requires a minimum
deployment target of iOS 10.0, macOS 10.12, tvOS 10.0, or watchOS 3.0.

No additional software dependencies.

## Installation

CocoaPods:

Swift package manager:

    .Package(url: "https://github.com/johnfairh/TMLPersistentContainer/", majorVersion: 0)

## Contributions

Contributions and feedback welcome - open an issue / johnfairh@gmail.com

## License

Distributed under the ISC license.
