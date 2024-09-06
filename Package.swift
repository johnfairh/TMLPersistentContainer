// swift-tools-version:6.0
import PackageDescription


let package = Package(
  name: "TMLPersistentContainer",
  platforms: [.macOS("14.0")],
  products: [
    .library(
      name: "TMLPersistentContainer",
      targets: ["TMLPersistentContainer"])
  ],
  targets: [
    .target(name: "TMLPersistentContainer", path: "Sources")
  ]
)
