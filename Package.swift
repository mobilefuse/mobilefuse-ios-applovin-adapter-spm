// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "MobileFuseAppLovinAdapter",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "MobileFuseAppLovinAdapter", targets: ["MobileFuseAppLovinAdapter"])
    ],
    dependencies: [
        .package(url: "https://github.com/mobilefuse/mobilefuse-ios-sdk-spm.git", exact: "1.13.1"),
        .package(url: "https://github.com/AppLovin/AppLovin-MAX-Swift-Package.git", from: "13.0.0")
    ],
    targets: [
        .target(
            name: "MobileFuseAppLovinAdapter",
            dependencies: [
                .product(name: "MobileFuseSDK", package: "mobilefuse-ios-sdk-spm"),
                .product(name: "AppLovinSDK", package: "applovin-max-swift-package")
            ]
        )
    ]
)
