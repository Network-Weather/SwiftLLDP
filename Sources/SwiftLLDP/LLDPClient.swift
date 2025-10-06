import Foundation

/// Convenience facade for decoding payloads and capturing LLDP neighbors.
public struct LLDPClient {
  private let parser: LLDPParser

  public init(parser: LLDPParser = LLDPParser()) {
    self.parser = parser
  }

  /// Decode a raw payload starting at the first TLV byte.
  public func decode(payload: Data) throws -> LLDPNeighbor {
    try parser.decode(payload: payload)
  }

  /// Capture LLDP frames on a named interface.
  public func discover(
    on interface: String,
    duration: TimeInterval = 3,
    limit: Int = .max,
    deduplicate: Bool = true
  ) throws -> [LLDPNeighbor] {
    try discover(
      options: .init(interface: interface),
      duration: duration,
      limit: limit,
      deduplicate: deduplicate
    )
  }

  /// Capture LLDP frames using explicit capture options.
  public func discover(
    options: LLDPCaptureService.Options,
    duration: TimeInterval = 3,
    limit: Int = .max,
    deduplicate: Bool = true
  ) throws -> [LLDPNeighbor] {
    let service = LLDPCaptureService(options: options)
    return try service.discoverNeighbors(
      duration: duration,
      limit: limit,
      deduplicate: deduplicate
    )
  }
}
