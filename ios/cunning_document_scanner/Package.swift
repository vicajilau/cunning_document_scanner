// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "cunning_document_scanner",
    defaultLocalization: "en",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "cunning-document-scanner", targets: ["cunning_document_scanner"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "cunning_document_scanner",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                .process("Resources"),
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
