# SwiftLLDP

SwiftLLDP is a Swift 6.2 command line client and library for discovering LLDP
(Link Layer Discovery Protocol) neighbors on macOS. It uses libpcap to capture
LLDP frames, decodes them into structured models, and exposes the data in both a
programmatic API and an ergonomic `swift-lldp` executable.

## Highlights

- LLDP parser with support for the most common TLVs (chassis ID, port ID, TTL,
  port description, system name/description, capabilities, management address).
- Deduplicated capture pipeline powered by libpcap.
- Codable neighbor model for easy integration with other tools.
- CLI output in human-readable table or JSON formats.
- DocC documentation, unit tests with sample frames, and formatter/linter
  scripts.

## Requirements

- macOS 14.4 or newer
- Swift 6.2 toolchain (Xcode 15.4 or `swift-6.2-RELEASE`)
- Command line tools: `libpcap` (ships with macOS)
- Optional: [`swift-format`](https://github.com/apple/swift-format) for
  formatting on Swift versions prior to the integrated formatter

Capturing LLDP frames usually requires elevated privileges via `sudo` or
membership in the `access_bpf` group on macOS.

## Getting Started

Clone the repository and bootstrap (optional) git hooks:

```bash
$ git clone git@github.com:network-weather/SwiftLLDP.git
$ cd SwiftLLDP
$ ./Scripts/bootstrap.sh
```

Build the project and run the CLI:

```bash
$ swift build
$ swift run swift-lldp --interface en0
```

Sample output:

```
Neighbor #1
  Chassis ID (macAddress): AA:BB:CC:DD:EE:FF
  Port ID (interfaceName): GigabitEthernet1/0/24
  TTL: 120s
  Port Description: Uplink port to Distribution-Switch
  System Name: dist-sw-01
  System Description: NX-OS 10.3(2)F
  Supported Capabilities: bridge, router
  Enabled Capabilities: bridge, router
  Management Addresses:
    - ipv4: 192.0.2.10 (ifIndex 24)
```

To output JSON instead:

```bash
$ swift run swift-lldp --interface en0 --format json
```

## Library Usage

Embed the library target in another package by adding a dependency to your
`Package.swift`:

```swift
.package(url: "https://github.com/network-weather/SwiftLLDP.git", from: "0.1.0")
```

Then import the module and either decode raw payloads or capture directly:

```swift
import SwiftLLDP

let client = LLDPClient()
let neighbors = try client.discover(on: "en0", duration: 5)
print(neighbors)
```

## Testing

Run the unit tests (note: capturing tests are limited to deterministic fixtures):

```bash
$ ./Scripts/test.sh
```

Due to sandboxing or permissions the Swift Package Manager may need an explicit
module cache path. If you encounter `ModuleCache` errors, try:

```bash
$ SWIFT_MODULE_CACHE_PATH=$PWD/.swift-module-cache ./Scripts/test.sh
```

## Formatting & Linting

Ensure code style consistency with the provided scripts:

```bash
$ ./Scripts/format.sh
$ ./Scripts/lint.sh
```

The scripts automatically fall back to `swift-format` if the integrated Swift 6
formatter is unavailable.

## Documentation

A DocC catalog lives at `Sources/SwiftLLDP/SwiftLLDP.docc`. Generate developer
reference material with:

```bash
$ swift package generate-documentation --target SwiftLLDP
```

Rendered documentation appears in `.build/plugins/Swift-DocC/outputs/` and can
be viewed in a browser.

## License

SwiftLLDP is released under the [MIT License](LICENSE).
