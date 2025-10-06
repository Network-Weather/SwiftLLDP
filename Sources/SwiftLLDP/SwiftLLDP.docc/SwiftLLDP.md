# ``SwiftLLDP``

Discover LLDP peers on macOS interfaces and decode them into structured,
human-friendly data.

## Overview

`SwiftLLDP` offers both a Swift library and a CLI tooling layer. The library
exposes types for LLDP TLVs, neighbor summaries, and the capture pipeline that
uses libpcap under the hood.

The key entry points are:

- ``LLDPClient`` for high level capture or payload decoding.
- ``LLDPCaptureService`` for fine-grained control over pcap configuration.
- ``LLDPParser`` for translating raw TLV payloads into ``LLDPNeighbor`` values.

## Topics

### Getting Started

- ``LLDPClient``
- ``LLDPParser``

### Capture

- ``LLDPCaptureService``
- ``LLDPCaptureService/Options``

### Models

- ``LLDPNeighbor``
- ``LLDPChassisID``
- ``LLDPPortID``
- ``LLDPManagementAddress``
- ``LLDPCapabilities``
