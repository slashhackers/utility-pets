// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UtilityPet",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "UtilityPet", targets: ["UtilityPet"])
    ],
    targets: [
        .executableTarget(name: "UtilityPet", dependencies: ["PetCore", "SharedUI", "Scooby"], path: "App/UtilityPets", exclude: ["Info.plist"], resources: [.process("Resources")]),
        .target(name: "PetCore", path: "Packages/PetCore/Sources"),
        .target(name: "SharedUI", path: "Packages/SharedUI/Sources"),
        .target(name: "FinderKit", path: "Packages/FinderKit/Sources"),
        .target(name: "AIKit", dependencies: ["PetCore"], path: "Packages/AIKit/Sources"),
        .target(name: "SettingsKit", path: "Packages/SettingsKit/Sources"),
        .target(name: "NotificationKit", path: "Packages/NotificationKit/Sources"),
        .target(name: "DeviceDiscovery", path: "Packages/DeviceDiscovery/Sources"),
        .target(name: "Scooby", dependencies: ["PetCore", "SharedUI", "DeviceDiscovery"], path: "Pets/Scooby/Sources"),
        .testTarget(name: "PetCoreTests", dependencies: ["PetCore"], path: "Tests/PetCoreTests"),
        .testTarget(name: "ScoobyTests", dependencies: ["Scooby", "DeviceDiscovery"], path: "Tests/ScoobyTests")
    ]
)
