import ArgumentParser
import Foundation
import SwiftLLDP

@main
struct SwiftLLDPCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "swift-lldp",
    abstract: "Inspect LLDP neighbors on a local interface",
    discussion:
      "Captures LLDP frames using libpcap and renders them in a friendly or JSON output format."
  )

  @Option(name: [.short, .long], help: "Interface name to monitor (for example: en0)")
  var interface: String

  @Option(name: [.short, .customLong("duration")], help: "Capture window in seconds (default: 3)")
  var durationInSeconds: Double = 3

  @Option(name: .shortAndLong, help: "Maximum number of neighbors to return")
  var limit: Int?

  @Flag(name: .customLong("no-deduplicate"), help: "Return duplicate frames for the same neighbor")
  var disableDeduplication: Bool = false

  @Option(help: "Output format (table or json)")
  var format: OutputFormat = .table

  func run() throws {
    let client = LLDPClient()
    let neighbors = try client.discover(
      options: .default(interface: interface),
      duration: durationInSeconds,
      limit: limit.map { max($0, 1) } ?? .max,
      deduplicate: !disableDeduplication
    )

    switch format {
    case .table:
      renderTable(neighbors)
    case .json:
      try renderJSON(neighbors)
    }
  }

  private func renderTable(_ neighbors: [LLDPNeighbor]) {
    guard !neighbors.isEmpty else {
      print("No LLDP neighbors discovered.")
      return
    }

    for (index, neighbor) in neighbors.enumerated() {
      print("Neighbor #\(index + 1)")
      if let chassis = neighbor.chassisID {
        print("  Chassis ID (\(chassis.subtype)): \(chassis.value)")
      }
      if let port = neighbor.portID {
        print("  Port ID (\(port.subtype)): \(port.value)")
      }
      if let ttl = neighbor.ttl {
        print("  TTL: \(ttl)s")
      }
      if let description = neighbor.portDescription {
        print("  Port Description: \(description)")
      }
      if let systemName = neighbor.systemName {
        print("  System Name: \(systemName)")
      }
      if let systemDescription = neighbor.systemDescription {
        print("  System Description: \(systemDescription)")
      }
      if let capabilities = neighbor.systemCapabilities {
        print("  Supported Capabilities: \(describe(capabilities))")
      }
      if let enabled = neighbor.enabledCapabilities {
        print("  Enabled Capabilities: \(describe(enabled))")
      }
      if !neighbor.managementAddresses.isEmpty {
        print("  Management Addresses:")
        for address in neighbor.managementAddresses {
          var line = "    - \(address.subtype): \(address.address)"
          if let interface = address.interfaceNumber {
            line += " (ifIndex \(interface))"
          }
          if let oid = address.oid {
            line += " oid=\(oid)"
          }
          print(line)
        }
      }
      if !neighbor.customTLVs.isEmpty {
        print("  Custom TLVs: \(neighbor.customTLVs.count)")
      }
      if index < neighbors.count - 1 {
        print("")
      }
    }
  }

  private func renderJSON(_ neighbors: [LLDPNeighbor]) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(neighbors)
    if let text = String(data: data, encoding: .utf8) {
      print(text)
    }
  }

  private func describe(_ capabilities: LLDPCapabilities) -> String {
    var descriptors: [String] = []
    if capabilities.contains(.other) { descriptors.append("other") }
    if capabilities.contains(.repeater) { descriptors.append("repeater") }
    if capabilities.contains(.bridge) { descriptors.append("bridge") }
    if capabilities.contains(.wlanAccessPoint) { descriptors.append("wlan-ap") }
    if capabilities.contains(.router) { descriptors.append("router") }
    if capabilities.contains(.telephone) { descriptors.append("telephone") }
    if capabilities.contains(.docsis) { descriptors.append("docsis") }
    if capabilities.contains(.stationOnly) { descriptors.append("station-only") }
    if capabilities.contains(.cvlanBridge) { descriptors.append("cvlan-bridge") }
    if capabilities.contains(.svlanBridge) { descriptors.append("svlan-bridge") }
    if capabilities.contains(.twoPortMacRelay) { descriptors.append("two-port-mac-relay") }
    return descriptors.joined(separator: ", ")
  }

  enum OutputFormat: String, ExpressibleByArgument {
    case table
    case json
  }
}
