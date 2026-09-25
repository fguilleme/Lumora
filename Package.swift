// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumoraCore",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v18)],
    products: [.library(name: "LumoraCore", targets: ["LumoraCore"])],
    targets: [
        .target(name: "LumoraCore", path: "Lumora",
                exclude: ["ContentView.swift", "MyApp.swift", "UI", "Editor/EditorSession.swift", "Editor/PresetController.swift", "Library/ImportedPhoto.swift", "Masks/MaskGenerator.swift", "Adjustments/GeometryAnalyzer.swift", "Assets.xcassets"],
                sources: ["Editor/EditState.swift", "Editor/HistoryManager.swift", "Adjustments", "Masks", "Creative", "Beauty", "Presets", "Rendering", "Export", "Library/PhotoDocument.swift", "Persistence"]),
        .testTarget(name: "LumoraCoreTests", dependencies: ["LumoraCore"]),
        .testTarget(name: "LumoraVisualTestLab", dependencies: ["LumoraCore"],
                    exclude: ["LOW_KEY_CONTRACT.md", "AdaptiveToneMetalPrototype", "SpatialImportancePrototype",
                              "ShadowBudgetPrototype", "adaptive_tone_phase2.py", "adaptive_tone_prototype.py", "__pycache__"],
                    resources: [.copy("Baselines"), .copy("Fixtures")])
    ]
)
