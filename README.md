# SwiftLLDP

SwiftLLDP is a Swift 6.2 package and command line interface for discovering
neighbors that advertise the Link Layer Discovery Protocol (LLDP) on macOS. It
uses libpcap for frame capture, decodes IEEE 802.1AB TLVs—including LLDP-MED
(ANSI/TIA-1057) extensions—and exposes the results through a strongly-typed
Swift API and an ergonomic `swift-lldp` executable.

---

## Contents

1. [Features](#features)
2. [Quick Start](#quick-start)
   - [CLI](#cli)
   - [Library](#library)
3. [Reference Documentation](#reference-documentation)
4. [Testing & Coverage](#testing--coverage)
5. [Development Workflow](#development-workflow)
6. [Background & Standards](#background--standards)
7. [License](#license)

---

## Features

- ✅ **Full LLDP decoding** for the common TLVs (chassis ID, port ID, TTL, port
  description, system name/description, capabilities, management addresses, and
  organizational data).
- ✅ **LLDP-MED support** with typed accessors for endpoint capabilities,
  inventory TLVs, and power negotiation (including inferred PoE class).
- ✅ **Libpcap-powered capture** with snapshot control, deduplication, and error
  reporting that maps into Swift errors.
- ✅ **CLI output** in a readable table or machine-friendly JSON, sharing the
  same decoding pipeline as the library.
- ✅ **DocC documentation** and doc comments suitable for `swift package
  generate-documentation`.
- ✅ **Unit tests** covering TLV decoding, LLDP-MED parsing, and malformed frame
  handling.
- ✅ **Swift Package Manager friendly**: add the module to server-side, CLI, or
  app tooling projects.

---

## Quick Start

### Prerequisites

- macOS 14.4 or newer
- Swift 6.2 toolchain (Xcode 15.4 or `swift-6.2-RELEASE`)
- System `libpcap` (preinstalled on macOS)
- Optional: membership in the `access_bpf` group or `sudo` access for live capture

### CLI

```bash
# Clone and build
$ git clone https://github.com/network-weather/SwiftLLDP.git
$ cd SwiftLLDP
$ swift run swift-lldp --interface en0
```

Sample output:

```
Neighbor #1
  Chassis ID (macAddress): 76:83:C2:3B:55:C4
  Port ID (macAddress): 74:83:C2:1B:55:C3
  TTL: 120s
  Port Description: eth0
  System Name: RearMasterAP
  System Description: UAP-HD-IW, 6.7.31.15618
  Supported Capabilities: bridge, wlan-ap, router, station-only
  Enabled Capabilities: bridge, wlan-ap, router
  Management Addresses:
    - ipv4: 192.168.147.59 (ifIndex 25)
    - ipv6: fd68:2e9e:d99d:cdb7:7683:c2ff:fe1b:55c3 (ifIndex 25)
  Organizational TLVs:
    - LLDP-MED Capabilities
      Capabilities: capabilities, network-policy, location-identification, extended-power-pse, extended-power-pd, inventory
      Device Type: network-connectivity
    - Software Revision: 4.4.153
      4.4.153
    - LLDP-MED Extended Power via MDI
      Power Type: PD Device
      Power Source: Primary Power Source
      Power Priority: High
      Power: 12.9 W
      PoE Standard: 802.3af (PoE)
```

Switch to JSON output or adjust the capture window:

```bash
$ swift run swift-lldp --interface en0 --duration 120 --format json
```

### Library

Add SwiftLLDP to another package:

```swift
// In Package.swift dependencies
.package(url: "https://github.com/network-weather/SwiftLLDP.git", from: "0.1.0")
```

Then depend on the `SwiftLLDP` product:

```swift
.product(name: "SwiftLLDP", package: "SwiftLLDP"),
```

Use the API from your code:

```swift
import SwiftLLDP

let client = LLDPClient()
let neighbors = try client.discover(on: "en0")

for neighbor in neighbors {
  print(neighbor.systemName ?? "Unknown", neighbor.medExtensions.first?.summary ?? "")
}
```

Decode an existing payload captured from another source:

```swift
import SwiftLLDP

let payload = Data(...) // bytes beginning at the first TLV
let neighbor = try LLDPClient().decode(payload: payload)
print(neighbor.managementAddresses)
```

Explore the `Examples/QuickStart` executable target for a minimal integration
scaffold that depends on the local checkout.

---

## Reference Documentation

DocC documentation is included under `Sources/SwiftLLDP/SwiftLLDP.docc` and
covers the capture pipeline, models, and CLI.

Generate documentation locally:

```bash
$ swift package generate-documentation --target SwiftLLDP \
    --output-path Docs --transform-for-static-hosting
```

Open `Docs/index.html` in a browser to explore the rendered reference. The
package and CLI source is extensively documented with doc comments so symbol
documentation appears in Xcode and the DocC archive.

---

## Testing & Coverage

Run the test suite through Swift Package Manager:

```bash
$ swift test
```

Collect coverage data (requires Swift 6.1+):

```bash
$ swift test --enable-code-coverage
$ llvm-cov show \
    .build/debug/SwiftLLDPPackageTests.xctest/Contents/MacOS/SwiftLLDPPackageTests \
    -instr-profile .build/debug/codecov/default.profdata \
    Sources/SwiftLLDP
```

The unit tests focus on deterministic parsing. Live capture is not part of the
suite to avoid relying on privileged interfaces.

The GitHub Actions workflow (`.github/workflows/ci.yml`) runs linting, build,
tests with coverage, and exports an `lcov` artifact on each push/PR.

---

## Development Workflow

- **Formatting:** `./Scripts/format.sh`
- **Linting:** `./Scripts/lint.sh`
- **Tests:** `./Scripts/test.sh`
- **Documentation:** `./Scripts/docs.sh`
- **DocC:** `swift package generate-documentation --target SwiftLLDP`

The project is organised as a SwiftPM package with three core targets:

1. `SwiftLLDP` – core library (public API surface)
2. `SwiftLLDPCLI` – `swift-lldp` executable built with ArgumentParser
3. `SwiftLLDPTests` – unit tests with fixture-based TLV data

Supplementary directories include `Examples/QuickStart` for sample integration
and GitHub workflow definitions for CI.

When contributing new APIs, follow the naming and style guidance from the
official [Swift Programming Language book](https://github.com/swiftlang/swift-book)
to keep the project aligned with modern Swift best practices.

The capture pipeline uses libpcap, so running the CLI usually requires `sudo`
or membership in the `access_bpf` group on macOS.

---

## Background & Standards

SwiftLLDP implements the structures defined in:

- **IEEE 802.1AB** – Station and Media Access Control Connectivity Discovery
  (LLDP) specification.
- **ANSI/TIA-1057** – Link Layer Discovery Protocol – Media Endpoint Discovery
  (LLDP-MED) for endpoint capabilities, inventory, and power negotiation.
- **IEEE 802.3-2018, Clause 104** – Power over Ethernet (PoE) classification
  (used for inferred PoE standard reporting).

Additional vendor TLVs surface through the `LLDPOrganizationalTLV` model, which
retains raw payloads so downstream tools can implement custom decoders.

For contributors targeting the [Swift Package Index](https://swiftpackageindex.com/):

- Ensure new APIs carry doc comments so DocC remains complete.
- Consider publishing the generated DocC archive (workflow artifact) via GitHub
  Pages or Netlify for discoverability.
- Update `CHANGELOG.md` and tag releases; the CI workflow already validates
  builds against Swift 6.2 on macOS.

---

## License

SwiftLLDP is released under the [MIT License](LICENSE).
