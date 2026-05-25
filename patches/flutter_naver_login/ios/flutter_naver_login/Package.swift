// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "flutter_naver_login",
    platforms: [.iOS("13.0")],
    products: [
        .library(name: "flutter_naver_login", targets: ["flutter_naver_login"])
    ],
    targets: [
        .target(
            name: "flutter_naver_login",
            path: "../Classes"
        )
    ]
)
