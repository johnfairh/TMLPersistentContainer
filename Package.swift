// swift-tools-version:5.0
import PackageDescription

#if os(Linux)
// No Core Data on Linux
let targets: [Target] = []
#else
let targets: [Target] = [
  .target(name: "TMLPersistentContainer", path: "Sources")]
#endif

let package = Package(
  name: "TMLPersistentContainer",
  platforms: [.macOS("10.12")],
  products: [
    .library(
      name: "TMLPersistentContainer",
      targets: ["TMLPersistentContainer"])
  ],
  targets: targets
)
