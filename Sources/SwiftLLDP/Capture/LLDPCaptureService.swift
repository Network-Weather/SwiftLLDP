import CLibpcap
import Foundation

/// Uses libpcap to capture LLDP frames from a local interface.
public final class LLDPCaptureService {
  /// Configuration controlling how the capture session is configured.
  public struct Options: Sendable {
    public var interface: String
    public var snapshotLength: Int
    public var promiscuous: Bool
    public var timeoutMilliseconds: Int

    public init(
      interface: String,
      snapshotLength: Int = 512,
      promiscuous: Bool = false,
      timeoutMilliseconds: Int = 1_000
    ) {
      self.interface = interface
      self.snapshotLength = snapshotLength
      self.promiscuous = promiscuous
      self.timeoutMilliseconds = timeoutMilliseconds
    }

    public static func `default`(interface: String) -> Options {
      Options(interface: interface)
    }
  }

  private let options: Options
  private let parser = LLDPParser()

  public init(options: Options) {
    self.options = options
  }

  /// Capture LLDP frames and return the decoded neighbors.
  /// - Parameters:
  ///   - duration: Maximum duration to wait for packets.
  ///   - limit: Maximum number of neighbors to return.
  ///   - deduplicate: When `true`, results are uniqued by chassis and port IDs.
  /// - Returns: An array of discovered neighbors.
  /// - Throws: `LLDPError` when capturing fails or frames are malformed.
  public func discoverNeighbors(
    duration: TimeInterval = 3,
    limit: Int = .max,
    deduplicate: Bool = true
  ) throws -> [LLDPNeighbor] {
    let handle = try openHandle()
    defer { pcap_close(handle) }

    var filterProgram = bpf_program()
    guard pcap_compile(handle, &filterProgram, "ether proto 0x88cc", 1, PCAP_NETMASK_UNKNOWN) != -1
    else {
      throw LLDPError.captureFailure(message: errorMessage(handle))
    }
    defer { pcap_freecode(&filterProgram) }

    guard pcap_setfilter(handle, &filterProgram) != -1 else {
      throw LLDPError.captureFailure(message: errorMessage(handle))
    }

    let stopTime = Date().addingTimeInterval(duration)
    var neighbors: [LLDPNeighbor] = []
    var seenKeys: Set<String> = []

    while Date() < stopTime, neighbors.count < limit {
      var headerPointer: UnsafeMutablePointer<pcap_pkthdr>?
      var packetPointer: UnsafePointer<UInt8>?
      let result = withUnsafeMutablePointer(to: &headerPointer) { headerPtr in
        withUnsafeMutablePointer(to: &packetPointer) { packetPtr in
          pcap_next_ex(handle, headerPtr, packetPtr)
        }
      }
      if result == 0 {
        continue
      }
      if result == -1 {
        throw LLDPError.captureFailure(message: errorMessage(handle))
      }
      guard result == 1, let header = headerPointer?.pointee, let packet = packetPointer else {
        continue
      }
      let frameData = Data(bytes: packet, count: Int(header.caplen))
      guard let payload = try extractLLDPPayload(from: frameData) else {
        continue
      }
      let neighbor = try parser.decode(payload: payload)
      if deduplicate {
        let key = neighborKey(neighbor)
        if seenKeys.contains(key) {
          continue
        }
        seenKeys.insert(key)
      }
      neighbors.append(neighbor)
    }

    return neighbors
  }

  private func openHandle() throws -> OpaquePointer {
    var errorBuffer = [Int8](repeating: 0, count: Int(PCAP_ERRBUF_SIZE))
    guard
      let handle = pcap_open_live(
        options.interface,
        Int32(options.snapshotLength),
        options.promiscuous ? 1 : 0,
        Int32(options.timeoutMilliseconds),
        &errorBuffer
      )
    else {
      let message = String(cString: &errorBuffer)
      if message.contains("No such device") {
        throw LLDPError.interfaceNotFound(options.interface)
      }
      throw LLDPError.captureFailure(message: message)
    }
    return handle
  }

  private func extractLLDPPayload(from frame: Data) throws -> Data? {
    guard frame.count >= 14 else {
      throw LLDPError.truncatedFrame
    }
    var index = 12
    var etherType = UInt16(frame[index]) << 8 | UInt16(frame[index + 1])
    while etherType == 0x8100 || etherType == 0x88A8 || etherType == 0x9100 {
      index += 4
      guard frame.count >= index + 2 else {
        throw LLDPError.truncatedFrame
      }
      etherType = UInt16(frame[index]) << 8 | UInt16(frame[index + 1])
    }
    guard etherType == 0x88CC else {
      return nil
    }
    let start = index + 2
    guard frame.count >= start else {
      throw LLDPError.truncatedFrame
    }
    return Data(frame[start..<frame.count])
  }

  private func neighborKey(_ neighbor: LLDPNeighbor) -> String {
    let chassis = neighbor.chassisID?.value ?? "unknown"
    let port = neighbor.portID?.value ?? "unknown"
    return "\(chassis)|\(port)"
  }

  private func errorMessage(_ handle: OpaquePointer?) -> String {
    if let handle {
      if let messagePointer = pcap_geterr(handle) {
        return String(cString: messagePointer)
      }
    }
    return "unknown error"
  }
}
