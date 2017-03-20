# TMLPersistentContainer

## background

What is the problem + what is the solution, briefly

## getting started

To start using the library replace references to `NSPersistentContainer`
with `PersistentContainer`.

The multi-step migration behaviour is enabled automatically for pcs with
the wossit flags set these are the default, if you are not explicitly
turning them off then they are set.

* ordering of model versions
    * xref to enum dox for details

## other features

* logging
* events
* store deletion

## Limitations

* atomicity guarantees
* multiple stores
* merged models
* multiple mapping models
* model version confusion with configs + frs?
