// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ffmpeg_kit_extended_flutter",
    platforms: [
        .macOS("10.15"),
    ],
    products: [
        .library(
            name: "ffmpeg-kit-extended-flutter",
            targets: ["ffmpeg_kit_native"]
        )
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        // Objective-C Target - contains the actual plugin implementation
        .target(
            name: "ffmpeg_kit_native",
            path: ".",
            sources: [
                "Classes/ffmpeg_kit_native/FfmpegKitExtendedFlutterPlugin.m",
                "Classes/ffmpeg_kit_native/FfplayKitPlugin.m"
            ],
            resources: [
                .process("Resources/PrivacyInfo.xcprivacy")
            ],
            publicHeadersPath: "Classes/ffmpeg_kit_native/include",
            cSettings: [
                .headerSearchPath("Classes/ffmpeg_kit_native/include")
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
