<!--
TMLPersistentContainer
Usage.md
Distributed under the ISC license, see LICENSE.
-->
# TMLPersistentContainer

## Overview

What is the problem + what is the solution.
Explain shortest-path algorithm and E vs I.
Pictures.

The rest of this document covers...

## Creating the container

To start using the library replace references to `NSPersistentContainer`
with `PersistentContainer`.

### Describing the valid migrations

### Finding data and mapping models

### Registering for logging

## Loading the stores

### Setting the StoreDescription flags

The multi-step migration behaviour is enabled automatically for pcs with
the wossit flags set these are the default, if you are not explicitly
turning them off then they are set.

### Using the delegate to track migrations

### Working with multiple stores

(tn2350)

## Limitations

* merged models
* multiple mapping models
