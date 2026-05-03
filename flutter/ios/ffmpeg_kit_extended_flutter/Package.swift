// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "ffmpeg_kit_extended_flutter",
  platforms: [
    .iOS("13.0")
  ],
  products: [
    .library(
      name: "ffmpeg-kit-extended-flutter",
      targets: ["ffmpeg_kit_native"]
    )
  ],
  dependencies: [
    // FlutterFramework is still needed for FlutterPlugin protocol
    .package(name: "FlutterFramework", path: "../FlutterFramework")
  ],
  targets: [
    // Objective-C Target - contains the actual plugin implementation
    .target(
      name: "ffmpeg_kit_native",
      path: "Classes/ffmpeg_kit_native",
      publicHeadersPath: "include",  // Critical: exposes headers to Swift/Flutter
      cSettings: [
        .headerSearchPath("include")
      ],
      linkerSettings: [
        // System frameworks required by FFmpeg
        .linkedFramework("AVFoundation"),
        .linkedFramework("CoreMedia"),
        .linkedFramework("CoreVideo"),
        .linkedFramework("AudioToolbox"),
        .linkedFramework("VideoToolbox"),
        // System libraries
        .linkedLibrary("c++"),
        .linkedLibrary("iconv"),
        .linkedLibrary("z"),
      ]
    )
  ]
)
