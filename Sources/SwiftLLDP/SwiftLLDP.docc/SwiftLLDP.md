# ``SwiftLLDP``

Discover LLDP peers on macOS interfaces and decode them into structured,
human-friendly data ready for automation.

## Overview

`SwiftLLDP` offers both a Swift library and a CLI tooling layer. The library
exposes types for LLDP TLVs, neighbor summaries, and the capture pipeline that
uses libpcap under the hood. You can embed the library in your own Swift code or
install the `swift-lldp` executable to inspect peers from the terminal.

```swift
import SwiftLLDP

let client = LLDPClient()
let neighbors = try client.discover(on: "en0", duration: 60)

neighbors.forEach { neighbor in
  print(neighbor.systemName ?? "Unknown neighbor")
}
```

The command-line interface provides the same decoding pipeline with formatted
output or JSON for automation:

```bash
swift run swift-lldp --interface en0 --format json
```

## Topics

### Getting Started

- ``LLDPClient``
- ``LLDPParser``
- ``SwiftLLDPCommand``

### Capture

- ``LLDPCaptureService``
- ``LLDPCaptureService/Options``

### Models

- ``LLDPNeighbor``
- ``LLDPChassisID``
- ``LLDPPortID``
- ``LLDPManagementAddress``
- ``LLDPCapabilities``
- ``LLDPOrganizationalTLV``
- ``LLDPMEDExtension``
