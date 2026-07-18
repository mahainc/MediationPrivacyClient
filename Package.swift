// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MediationPrivacyClient",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .singleTargetLibrary("MediationPrivacyClient"),
        .singleTargetLibrary("MediationPrivacyClientAppLovin"),
        .singleTargetLibrary("MediationPrivacyClientMeta"),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-dependencies.git",
            from: "1.9.0"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-case-paths.git",
            from: "1.5.0"
        ),
        .package(
            url: "https://github.com/AppLovin/AppLovin-MAX-Swift-Package.git",
            from: "13.0.0"
        ),
        .package(
            url: "https://github.com/facebook/facebook-ios-sdk.git",
            "17.0.0"..<"19.0.0"
        ),
    ],
    targets: [
        .target(
            name: "MediationPrivacyClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "CasePaths", package: "swift-case-paths"),
            ]
        ),
        .target(
            name: "MediationPrivacyClientAppLovin",
            dependencies: [
                "MediationPrivacyClient",
                .product(name: "AppLovinSDK", package: "AppLovin-MAX-Swift-Package"),
            ]
        ),
        .target(
            name: "MediationPrivacyClientMeta",
            dependencies: [
                "MediationPrivacyClient",
                .product(name: "FacebookCore", package: "facebook-ios-sdk"),
            ]
        ),
        .testTarget(
            name: "MediationPrivacyClientTests",
            dependencies: ["MediationPrivacyClient"]
        ),
    ]
)

extension Product {
    static func singleTargetLibrary(_ name: String) -> Product {
        .library(name: name, targets: [name])
    }
}
