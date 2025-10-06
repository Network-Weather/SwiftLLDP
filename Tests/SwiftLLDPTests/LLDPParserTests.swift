import XCTest

@testable import SwiftLLDP

final class LLDPParserTests: XCTestCase {
  func testDecodesCompleteFrame() throws {
    let chassisID: [UInt8] = [
      0x02, 0x07, 0x04, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF,
    ]
    let portID: [UInt8] = [
      0x04, 0x05, 0x05, 0x65, 0x74, 0x68, 0x30,
    ]
    let ttl: [UInt8] = [
      0x06, 0x02, 0x00, 0x78,
    ]
    let portDescription: [UInt8] = [
      0x08, 0x0B, 0x55, 0x70, 0x6C, 0x69, 0x6E, 0x6B, 0x20, 0x70, 0x6F, 0x72, 0x74,
    ]
    let systemName: [UInt8] = [
      0x0A, 0x08, 0x73, 0x77, 0x69, 0x74, 0x63, 0x68, 0x30, 0x31,
    ]
    let systemDescription: [UInt8] = [
      0x0C, 0x0E, 0x4E, 0x65, 0x74, 0x77, 0x6F, 0x72,
      0x6B, 0x20, 0x53, 0x77, 0x69, 0x74, 0x63, 0x68,
    ]
    let capabilities: [UInt8] = [
      0x0E, 0x04, 0x00, 0x14, 0x00, 0x14,
    ]
    let managementAddress: [UInt8] = [
      0x10, 0x0C, 0x05, 0x01, 0xC0, 0xA8, 0x01, 0x01, 0x02, 0x00, 0x00, 0x00, 0x01, 0x00,
    ]
    let payload = Data(
      chassisID
        + portID
        + ttl
        + portDescription
        + systemName
        + systemDescription
        + capabilities
        + managementAddress
        + [0x00, 0x00]
    )

    let parser = LLDPParser()
    let neighbor = try parser.decode(payload: payload)

    XCTAssertEqual(neighbor.chassisID?.subtype, .macAddress)
    XCTAssertEqual(neighbor.chassisID?.value, "AA:BB:CC:DD:EE:FF")
    XCTAssertEqual(neighbor.portID?.subtype, .interfaceName)
    XCTAssertEqual(neighbor.portID?.value, "eth0")
    XCTAssertEqual(neighbor.ttl, 0x78)
    XCTAssertEqual(neighbor.portDescription, "Uplink port")
    XCTAssertEqual(neighbor.systemName, "switch01")
    XCTAssertEqual(neighbor.systemDescription, "Network Switch")
    XCTAssertEqual(neighbor.systemCapabilities, [.bridge, .router])
    XCTAssertEqual(neighbor.enabledCapabilities, [.bridge, .router])
    XCTAssertEqual(neighbor.managementAddresses.count, 1)
    XCTAssertEqual(neighbor.managementAddresses.first?.address, "192.168.1.1")
  }

  func testThrowsForMalformedTTL() {
    let malformed = Data([
      0x06, 0x01, 0x00,
      0x00, 0x00,
    ])
    let parser = LLDPParser()
    XCTAssertThrowsError(try parser.decode(payload: malformed)) { error in
      guard case LLDPError.malformedTLV(let type) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertEqual(type, 3)
    }
  }

  func testDecodesIPv6ManagementAddress() throws {
    let ipv6Bytes: [UInt8] = [
      0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
    ]
    var payload: [UInt8] = [
      0x10, 0x18, 0x11, 0x02,
    ]
    payload.append(contentsOf: ipv6Bytes)
    payload.append(contentsOf: [
      0x02, 0x00, 0x00, 0x00, 0x02, 0x00,
    ])
    payload.append(contentsOf: [0x00, 0x00])
    let parser = LLDPParser()
    let neighbor = try parser.decode(payload: Data(payload))
    XCTAssertEqual(neighbor.managementAddresses.first?.subtype, .ipv6)
    XCTAssertEqual(neighbor.managementAddresses.first?.address, "1000::1")
  }

  func testDecodesNetworkAddressInChassisID() throws {
    let payload = Data([
      0x02, 0x06, 0x05, 0x01, 0xC0, 0xA8, 0x01, 0x64,
      0x00, 0x00,
    ])
    let parser = LLDPParser()
    let neighbor = try parser.decode(payload: payload)
    XCTAssertEqual(neighbor.chassisID?.value, "192.168.1.100")
  }
}
