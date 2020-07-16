// swift-tools-version:5.0
import PackageDescription


let package = Package(
  name: "TMLPersistentContainer",
  platforms: [.macOS("10.12")],
  products: [
    .library(
      name: "TMLPersistentContainer",
      targets: ["TMLPersistentContainer"])
  ],
  targets: [
    .target(name: "TMLPersistentContainer", path: "Sources")
  ]
)
