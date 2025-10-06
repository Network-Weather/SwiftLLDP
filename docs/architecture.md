# Architecture

SwiftLLDP is split into three main layers:

1. **Model Layer (`Sources/SwiftLLDP/Model/`)** – Defines lightweight, Codable
   value types for TLVs and neighbors. The option set of capabilities mirrors
   IEEE 802.1AB bit positions.
2. **Parsing Layer (`Sources/SwiftLLDP/Parsing/`)** – Implements a streaming TLV
   parser (`LLDPParser`) on top of a simple `ByteReader` helper and gracefully
   handles malformed frames.
3. **Capture Layer (`Sources/SwiftLLDP/Capture/`)** – Wraps libpcap to open a BPF
   device, apply an LLDP filter, and convert captured frames into payloads for
   the parser. The capture layer deduplicates neighbors by chassis and port ID
   by default.

The CLI (`Sources/SwiftLLDPCLI`) is a thin adapter around `LLDPClient`, which in
turn ties together the parser and capture service. Additional applications can
choose any layer depending on their needs: fully managed capture via
`LLDPClient`, manual decoding via `LLDPParser`, or even constructing
`LLDPNeighbor` values from fixtures for testing.
