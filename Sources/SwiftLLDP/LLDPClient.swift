import Foundation

/// Convenience facade for decoding payloads and capturing LLDP neighbors.
public struct LLDPClient {
  private let parser: LLDPParser

  /// Create a client that can decode payloads or capture live traffic.
  ///
  /// - Parameter parser: The parser used to transform LLDP payloads into structured models.
  public init(parser: LLDPParser = LLDPParser()) {
    self.parser = parser
  }

  /// Decode a raw payload starting at the first TLV byte.
  public func decode(payload: Data) throws -> LLDPNeighbor {
    try parser.decode(payload: payload)
  }

  /// Capture LLDP frames on a named interface.
  ///
  /// - Parameters:
  ///   - interface: BSD interface name (for example `en0`).
  ///   - duration: Maximum capture window in seconds. Defaults to 60 seconds which aligns with the
  ///     default LLDP advertisement interval.
  ///   - limit: Maximum number of neighbors to return. Defaults to unlimited.
  ///   - deduplicate: When true, only unique chassis/port combinations are returned.
  public func discover(
    on interface: String,
    duration: TimeInterval = 60,
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
  ///
  /// - Parameters mirror ``discover(on:duration:limit:deduplicate:)`` with the addition of
  ///   `options` which exposes libpcap settings such as snapshot length and timeout.
  public func discover(
    options: LLDPCaptureService.Options,
    duration: TimeInterval = 60,
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
