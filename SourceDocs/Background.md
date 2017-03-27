<!--
TMLPersistentContainer
Usage.md
Distributed under the ISC license, see LICENSE.
-->
# Background

*This document is background on the Core Data
migration-from-multiple-model-versions problem.  If you are a Core Data
developer and know all about this then you should probably [read the user guide
instead](usage.html).*

Developers change their Core Data models over time to support new requirements.
If a user upgrades the app on their device and the new version of the app has a
new version of the Core Data model then the app's Core Data stores have to be
*migrated* to match the new version of the model.  

A Core Data *mapping model* contains rules to migrate a store from one version
of a model to another.  Developers create explicit mapping models in Xcode
or can rely on inferred mapping models created at run-time by Core Data for
simple model changes.  These inferred mapping models are usually more efficient
at run-time.

Apps have to support migration from all possible installed model versions up to
the latest version otherwise users will be upset.  Vanilla Core Data allows for
a single mapping model to be used when loading a store.  This leaves developers
with a problem deploying model version 5, for example, that has to support
migration from any of model versions 1 to 4.

**Option 1** is to consider all the possible migrations from versions 1-4 to 5.
If the inferred mapping model is OK then great, otherwise we have to create a
mapping model in Xcode to perform the necessary transformations.  

**Option 2** is to use multiple sequential migrations at run-time.  So if the
user's store happens to be at version 2, it would be migrated from 2->3 then
3->4 and finally 4->5.

Option 1 requires more mapping models to be created, tested, and maintained.
It can require more actual code to be written, tested, and maintained depending
on the requirements for custom entity mappings.  The benefit is that users see
a single migration step and so the speediest app launch possible.

Option 2 requires some one-off app code to perform the sequential migrations.
Users who have been tardy updating their device will see a one-off longer app
launch time after the update as their stores are migrated multiple times.

Option 2 is generally the best choice and several libraries exist to assist
with the mechanics.

This library, `TMLPersistentContainer`, is another such assistant.  It allows
developers to minimize the long migration sequences that can occur in mature
apps and to take advantage of the light-weight migrations enabled by inferred
mapping models.

[Read the user guide to find out how](usage.html).
