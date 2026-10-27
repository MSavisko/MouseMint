# Architecture references

Checked 2026-10-27. These Swift macOS apps have GitHub repositories created in 2026. The dates below are repository creation dates, not claims about when their first code was written. Source links use the inspected commits so the evidence remains reviewable.

| Project | Repository created | License at inspection | Useful pattern for MouseMint |
| --- | --- | --- | --- |
| [FineTune](https://github.com/ronitsingh10/FineTune) | [2026-01-18](https://api.github.com/repos/ronitsingh10/FineTune) | GPL-3.0 | Injectable native-system services and explicit coordination ownership |
| [InputConfig](https://github.com/ryleighnewman/InputConfig) | [2026-04-09](https://api.github.com/repos/ryleighnewman/InputConfig) | MIT | Stateless HID decoding and report fixtures carrying evidence |
| [Filbert](https://github.com/victorhqc/filbert) | [2026-07-19](https://api.github.com/repos/victorhqc/filbert) | MIT | Shared contracts, registered implementations and a short repository guide |

## FineTune

This audio menu bar app defines hardware-facing protocols such as [AudioDeviceProviding](https://github.com/ronitsingh10/FineTune/blob/2285279d36d3f8115c1c2d4aecd904f1bdf96a51/FineTune/Audio/Monitors/AudioDeviceProviding.swift) and [ProcessTapControlling](https://github.com/ronitsingh10/FineTune/blob/2285279d36d3f8115c1c2d4aecd904f1bdf96a51/FineTune/Audio/Engine/ProcessTapControlling.swift). [AppListCoordinator](https://github.com/ronitsingh10/FineTune/blob/2285279d36d3f8115c1c2d4aecd904f1bdf96a51/FineTune/Audio/Engine/AppListCoordinator.swift) separates persistence responsibilities from live engine operations. Its [contribution guide](https://github.com/ronitsingh10/FineTune/blob/2285279d36d3f8115c1c2d4aecd904f1bdf96a51/CONTRIBUTING.md) asks views to take inputs and expose callbacks for mutations.

For MouseMint: keep system access replaceable in tests and give coordination a named owner. Audio callback constraints and FineTune's newer observation APIs do not become MouseMint requirements. MouseMint keeps AppKit and macOS 13 compatibility. No FineTune code was copied.

## InputConfig

This controller mapper's [HIDReportDecoder](https://github.com/ryleighnewman/InputConfig/blob/958bdd97ceecb182004b3d7d8521761b5a7e7756/InputConfig/Services/HIDReportDecoder.swift) transforms reports into controller state. [HIDFixture](https://github.com/ryleighnewman/InputConfig/blob/958bdd97ceecb182004b3d7d8521761b5a7e7756/InputConfig/Models/Fixtures/HIDFixture.swift) records transport, bytes, expected results, evidence status and citations. [RawHIDGamepad](https://github.com/ryleighnewman/InputConfig/blob/958bdd97ceecb182004b3d7d8521761b5a7e7756/InputConfig/Models/RawHIDGamepad.swift) explicitly distinguishes its temporary registry identity from persisted identity.

For MouseMint: keep decoding independent of live hardware, record where captures came from, and distinguish model matching from individual-device identity. Its larger controller feature set and synchronization choices are not a template to reproduce wholesale.

## Filbert

This usage-monitoring menu bar app declares [provider contracts](https://github.com/victorhqc/filbert/blob/d7b27544e487481b80012dee3e6d6fa5f0a9037b/Sources/Core/ProviderProtocol.swift) and a [registry](https://github.com/victorhqc/filbert/blob/d7b27544e487481b80012dee3e6d6fa5f0a9037b/Sources/Core/ProviderRegistry.swift). Its [package manifest](https://github.com/victorhqc/filbert/blob/d7b27544e487481b80012dee3e6d6fa5f0a9037b/Package.swift) makes provider modules depend on Core, while [startup](https://github.com/victorhqc/filbert/blob/d7b27544e487481b80012dee3e6d6fa5f0a9037b/Sources/App/AppMain.swift) imports and registers concrete providers. Its [AGENTS.md](https://github.com/victorhqc/filbert/blob/d7b27544e487481b80012dee3e6d6fa5f0a9037b/AGENTS.md) documents boundaries and workflow.

For MouseMint: compose device drivers at startup and let shared app state feed the UI. Keep the interface smaller than Filbert's provider contract and retain one app target initially. Filbert's network, credential, specification-approval and Git policies are specific to that repository; MouseMint's own guide defines its workflow.

## Decision

[MouseMint's architecture](architecture.md) combines these ideas with boundaries already present in its scrolling backend and Settings callbacks. The ownership model, gradual migration, and single-target choice are our recommendation for this codebase. The examples provide concrete references, not proof that a framework or a full rewrite is needed.
