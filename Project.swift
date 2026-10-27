import ProjectDescription
import Foundation

guard let version = ProcessInfo.processInfo.environment["TUIST_MOUSEMINT_VERSION"],
      let updatePublicKey = ProcessInfo.processInfo.environment["TUIST_MOUSEMINT_PUBLIC_KEY"] else {
    fatalError("Use mise run generate, test or build to load version and update metadata")
}
let components = version.split(separator: ".").compactMap { Int($0) }
guard components.count == 3, components.allSatisfy({ $0 >= 0 }), components[0] < 9900, components[1] < 100, components[2] < 100 else { fatalError("Invalid release version") }
let buildVersion = "\(components[0] + 100).\(components[1]).\(components[2])"

let project = Project(
    name: "MouseMint",
    options: .options(
        automaticSchemesOptions: .disabled,
        disableBundleAccessors: true,
        disableSynthesizedResourceAccessors: true
    ),
    settings: .settings(base: [
        "SWIFT_VERSION": "5.0",
        "MARKETING_VERSION": .string(version),
        "CURRENT_PROJECT_VERSION": .string(buildVersion),
        "SPARKLE_PUBLIC_KEY": .string(updatePublicKey),
        "ARCHS": "arm64",
        "CODE_SIGN_IDENTITY": "-",
        "CODE_SIGN_STYLE": "Manual",
        "ENABLE_APP_SANDBOX": "NO",
    ], release: ["CODE_SIGN_INJECT_BASE_ENTITLEMENTS": "NO"]),
    targets: [
        .target(
            name: "MouseMint",
            destinations: .macOS,
            product: .app,
            bundleId: "io.github.msavisko.mousemint",
            deploymentTargets: .macOS("13.0"),
            infoPlist: .file(path: "Resources/Info.plist"),
            sources: ["Sources/**"],
            resources: ["LICENSE", "THIRD_PARTY_NOTICES.md"],
            dependencies: [.sdk(name: "IOKit", type: .framework), .external(name: "Sparkle")]
        ),
        // Hostless tests compile the same sources without the app entry point.
        // Testing must never launch the mouse/scrolling automation.
        .target(
            name: "MouseMintTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "io.github.msavisko.mousemint.tests",
            deploymentTargets: .macOS("13.0"),
            sources: [
                .glob("Sources/**", excluding: ["Sources/main.swift"]),
                .glob("Tests/**", excluding: ["Tests/Support/**"]),
            ],
            dependencies: [.sdk(name: "IOKit", type: .framework), .external(name: "Sparkle")],
            settings: .settings(base: ["TEST_HOST": "", "BUNDLE_LOADER": ""])
        ),
        .target(
            name: "PreferencesPersistenceProbe",
            destinations: .macOS,
            product: .commandLineTool,
            bundleId: "io.github.msavisko.mousemint.tests.persistence",
            deploymentTargets: .macOS("13.0"),
            infoPlist: nil,
            sources: [
                "Sources/Domain/NaturalScrolling.swift",
                "Sources/Domain/StatusInterval.swift",
                "Sources/Preferences/SavedScrollingPreferences.swift",
                "Sources/Preferences/StatusPollingPreferences.swift",
                "Tests/Support/PreferencesPersistenceProbe.swift",
            ]
        ),
    ],
    schemes: [
        .scheme(
            name: "MouseMint",
            buildAction: .buildAction(targets: ["MouseMint", "PreferencesPersistenceProbe"]),
            testAction: .targets(["MouseMintTests"]),
            runAction: .runAction(executable: "MouseMint")
        ),
    ],
    additionalFiles: ["AGENTS.md", "README.md", "PLAN.md", "mise.toml", "mise.lock", "docs/**"]
)
