// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "NYPLAudiobookToolkit",
  platforms: [.iOS(.v10), .macOS(.v10_12)],
  products: [
    .library(name: "NYPLAudiobookToolkit",
             targets: ["NYPLAudiobookToolkit"]),
  ],
  dependencies: [
    .package(name: "NYPLUtilities",
             url: "https://github.com/NYPL-Simplified/iOS-Utilities.git",
             branch: "main"),
    .package(url: "https://github.com/PureLayout/PureLayout.git", from: "3.1.9"),
  ],
  targets: [
    .target(
      name: "NYPLAudiobookToolkit",
      dependencies: ["NYPLUtilities", "PureLayout"],
      path: "NYPLAudiobookToolkit",
      exclude: [
        "Info.plist", "NYPLAudiobookToolkit.h", "Core/Bundle.swift"
      ],
      resources: [
        .process("Resources")
      ]
    ),
    .testTarget(
      name: "NYPLAudiobookToolkitTests",
      dependencies: ["NYPLAudiobookToolkit"],
      path: "NYPLAudiobookToolkitTests",
      exclude: [
        "Info.plist"
      ]
    ),
  ]
)
