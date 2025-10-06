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
      0x0C, 0x0E, 0x4E, 0x65, 0x74, 0x77, 0x6F, 0x72, 0x6B, 0x20,
      0x53, 0x77, 0x69, 0x74, 0x63, 0x68,
    ]
    let capabilities: [UInt8] = [
      0x0E, 0x04, 0x00, 0x14, 0x00, 0x14,
    ]
    let managementAddress: [UInt8] = [
      0x10, 0x0C, 0x05, 0x01, 0xC0, 0xA8, 0x01, 0x01, 0x02, 0x00, 0x00, 0x00, 0x01, 0x00,
    ]

    var bytes: [UInt8] = []
    bytes.append(contentsOf: chassisID)
    bytes.append(contentsOf: portID)
    bytes.append(contentsOf: ttl)
    bytes.append(contentsOf: portDescription)
    bytes.append(contentsOf: systemName)
    bytes.append(contentsOf: systemDescription)
    bytes.append(contentsOf: capabilities)
    bytes.append(contentsOf: managementAddress)
    bytes.append(contentsOf: [0x00, 0x00])
    let payload = Data(bytes)

    let parser = LLDPParser()
    let neighbor = try parser.decode(payload: payload)
    let expectedCapabilities: LLDPCapabilities = [.bridge, .router]

    XCTAssertEqual(neighbor.chassisID?.subtype, .macAddress)
    XCTAssertEqual(neighbor.chassisID?.value, "AA:BB:CC:DD:EE:FF")
    XCTAssertEqual(neighbor.portID?.subtype, .interfaceName)
    XCTAssertEqual(neighbor.portID?.value, "eth0")
    XCTAssertEqual(neighbor.ttl, 0x78)
    XCTAssertEqual(neighbor.portDescription, "Uplink port")
    XCTAssertEqual(neighbor.systemName, "switch01")
    XCTAssertEqual(neighbor.systemDescription, "Network Switch")
    XCTAssertEqual(neighbor.systemCapabilities, expectedCapabilities)
    XCTAssertEqual(neighbor.enabledCapabilities, expectedCapabilities)
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
  func testDecodesOrganizationalTLVs() throws {
    func makeTLV(type: UInt8, value: [UInt8]) -> [UInt8] {
      let length = value.count
      let header = UInt16(type) << 9 | UInt16(length)
      return [UInt8(header >> 8), UInt8(header & 0xFF)] + value
    }

    let samples: [[UInt8]] = [
      [0x00, 0x12, 0xBB, 0x01, 0x00, 0x3F, 0x04],
      [0x00, 0x12, 0xBB, 0x07, 0x34, 0x2E, 0x34, 0x2E, 0x31, 0x35, 0x33],
      [0x00, 0x12, 0xBB, 0x04, 0x52, 0x00, 0x81],
    ]
    var bytes: [UInt8] = []
    for sample in samples {
      bytes += makeTLV(type: 127, value: sample)
    }
    bytes += [0x00, 0x00]

    let neighbor = try LLDPParser().decode(payload: Data(bytes))

    XCTAssertEqual(neighbor.organizationalTLVs.count, 3)
    XCTAssertTrue(neighbor.customTLVs.isEmpty)
    XCTAssertEqual(neighbor.medExtensions.count, 3)

    let first = neighbor.organizationalTLVs[0]
    XCTAssertEqual(first.oui, 0x0012BB)
    XCTAssertEqual(first.subtype, 0x01)
    XCTAssertEqual(first.payload, Data([0x00, 0x3F, 0x04]))
    guard let medCapabilities = first.med else {
      return XCTFail("Expected LLDP-MED capabilities TLV")
    }
    XCTAssertEqual(medCapabilities.kind, .capabilities)
    guard let capabilities = medCapabilities.capabilities else {
      return XCTFail("Missing parsed capabilities")
    }
    let expectedFlags: LLDPMEDCapabilityFlags = [
      .capabilities,
      .networkPolicy,
      .locationIdentification,
      .extendedPowerPSE,
      .extendedPowerPD,
      .inventory,
    ]
    XCTAssertEqual(capabilities.flags, expectedFlags)
    XCTAssertEqual(capabilities.deviceType, .networkConnectivity)

    let second = neighbor.organizationalTLVs[1]
    XCTAssertEqual(second.subtype, 0x07)
    XCTAssertEqual(String(decoding: second.payload, as: UTF8.self), "4.4.153")
    guard let medSoftware = second.med else {
      return XCTFail("Expected LLDP-MED software revision TLV")
    }
    XCTAssertEqual(medSoftware.kind, .softwareRevision)
    XCTAssertEqual(medSoftware.text, "4.4.153")

    let third = neighbor.organizationalTLVs[2]
    XCTAssertEqual(third.subtype, 0x04)
    XCTAssertEqual(third.payload, Data([0x52, 0x00, 0x81]))
    guard let medPower = third.med else {
      return XCTFail("Expected LLDP-MED power TLV")
    }
    XCTAssertEqual(medPower.kind, .extendedPower)
    guard let power = medPower.extendedPower else {
      return XCTFail("Missing parsed power information")
    }
    XCTAssertEqual(power.powerType, .pd)
    XCTAssertEqual(power.powerSource, .primary)
    XCTAssertEqual(power.powerPriority, .high)
    XCTAssertEqual(power.powerValueTenthsWatts, 0x0081)
    XCTAssertEqual(power.powerValueWatts, 12.9, accuracy: 0.01)
  }

}
