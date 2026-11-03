// swift-tools-version:5.9
// The rules of Lockout as plain Swift: no Apple-only frameworks, so the whole
// rulebook is unit-tested on every Codemagic build before anything ships.
import PackageDescription

let package = Package(
    name: "LockoutCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "LockoutCore", targets: ["LockoutCore"]),
    ],
    targets: [
        .target(name: "LockoutCore"),
        .testTarget(name: "LockoutCoreTests", dependencies: ["LockoutCore"]),
    ]
)
