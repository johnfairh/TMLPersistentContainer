import PackageDescription

#if os(Linux)
// No CoreData on Linux
let targets = []
#else
let targets = [Target(name: "TMLPersistentContainer")]
#endif

let package = Package(
    name: "TMLPersistentContainer",
    targets: targets
)
