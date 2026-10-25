import ProjectDescription

let project = Project(
    name: "MouseMint",
    options: .options(
        automaticSchemesOptions: .disabled,
        disableBundleAccessors: true,
        disableSynthesizedResourceAccessors: true
    ),
    settings: .settings(base: [
        "SWIFT_VERSION": "5.0",
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
            dependencies: [.sdk(name: "IOKit", type: .framework)]
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
                .glob("Tests/*.swift"),
            ],
            dependencies: [.sdk(name: "IOKit", type: .framework)],
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
                "Sources/NaturalScrolling.swift",
                "Sources/StatusPolling.swift",
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
    additionalFiles: ["README.md", "PLAN.md", "mise.toml", "mise.lock", "docs/**"]
)
