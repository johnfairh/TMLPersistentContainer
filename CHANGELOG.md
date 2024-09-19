## 6.0.0

### Breaking

* Various interface updates for `Sendable` / Swift concurrency.
* Require Swift 6.
* Update macOS minimum deployment level to 10.14.6.  
  [John Fairhurst](https://github.com/johnfairh)

### Enhancements

* None.

### Bug Fixes

* None.

## 5.0.1

### Bug Fixes

* Don't generate empty targets list on Linux.  
  [John Fairhurst](https://github.com/johnfairh)
  [#16](https://github.com/johnfairh/TMLPersistentContainer/issues/11)

## 5.0.0

#### Breaking

* Add `NSPersistentCloudKitContainer`.
  This is breaking because the signature of the `MigrationDelegate` methods
  have changed to take a `NSPersistentContainer` instead of a
  `PersistentContainer` so that it can be shared between the two types of
  container.  
  [Jonas Reichert](https://github.com/jonnybeegod)
  [#11](https://github.com/johnfairh/TMLPersistentContainer/issues/11)

#### Enhancements

* None.

#### Bug Fixes

* None.

## 4.1.0

#### Breaking

* None.

#### Enhancements

* Add `warning` log messages when models are ignored due to
  conflicting names or entity metadata.  
  [John Fairhurst](https://github.com/johnfairh)

#### Bug Fixes

* Fix intermittent ignoring of a model that contains multiple
  entities and appears more than once in the bundles.  
  [John Fairhurst](https://github.com/johnfairh)

## 4.0.0

##### Breaking

* Port to Swift 5, Xcode 10.2  
  [John Fairhurst](https://github.com/johnfairh)

##### Enhancements

* None.

##### Bug Fixes

* None.

## 3.0.0

##### Breaking

* Port to Swift 4.1, Xcode 9.3.1  
  [John Fairhurst](https://github.com/johnfairh)

## 2.0.0

##### Breaking

* Port to Swift 4, Xcode 9.  
  [John Fairhurst](https://github.com/johnfairh)

## 1.0.1

##### Bug Fixes

* Detect best migration path correctly when first step of two alternates is
  an explicit migration.  
  [John Fairhurst](https://github.com/johnfairh)
  [#5](https://github.com/johnfairh/TMLPersistentContainer/issues/5)
