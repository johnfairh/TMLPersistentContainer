<!--
TMLPersistentContainer
README.md
Distributed under the ISC license, see LICENSE.
-->

## TMLPersistentContainer

<!--
Badge thingies to get working:
* travis -- https://docs.travis-ci.com/user/status-images/
* coverage -- 
![CocoaPod](https://cocoapod-badges.herokuapp.com/v/TMLPersistentContainer/badge.png)
![Platforms](https://cocoapod-badges.herokuapp.com/p/TMLPersistentContainer/badge.png)
![License](https://cocoapod-badges.herokuapp.com/l/TMLPersistentContainer/badge.png)
-->

Automatic shortest-path Core Data migrations.

<!-- pic -->

A Swift extension to Core Data's `NSPersistentContainer` that automatically
detects and performs multi-step store migration using the shortest valid
sequence of migrations.  The library supports both light-weight and
heavy-weight migrations, multiple stores, progress reporting, and configurable
logging.

## Example

Minimally replace the call to `NSPersistentContainer.init`.  The library is
API compatible:

    container = PersistentContainer(name: "MyStore",
                                    managedObjectModel: model)

Additional parameters optionally enable more features:

    container =
        PersistentContainer(name: "MyStore",
                            managedObjectModel: model,
                            bundles: [Bundle.main, myResBundle],
                            modelVersionOrder: .list("ModelV1", "ModelV2", "ModelV6"),
                            logMessageHandler: myLogHandler)
    container.migrationDelegate = self

All migrations happen as part of `NSPersistentContainer.loadPersistentStores`.

## Documentation

 * To figure out a URL!
 * Full docs in the docs/ folder.
 * User guide in SourceDocs/Usage.md

## Requirements

Swift 3.  Because the library is based on `NSPersistentContainer` it requires
a minimum deployment target of iOS 10.0, macOS 10.12, tvOS 10.0, or watchOS
3.0.

## Installation

CocoaPods:

Swift package manager:

## Limitations

 * No support for merged models.
 * Untested with custom stores.
 * Testing on tvOS and watchOS has been simulator only!

## Contributions

Contributions and feedback welcome - open an issue or <twitter> / email

## License

Distributed under the ISC license.
