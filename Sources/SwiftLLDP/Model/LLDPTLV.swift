import Foundation

public struct LLDPTLV: Codable, Equatable, Sendable {
  public let type: UInt8
  public let length: Int
  public let rawValue: Data

  public init(type: UInt8, length: Int, rawValue: Data) {
    self.type = type
    self.length = length
    self.rawValue = rawValue
  }
}

public struct LLDPChassisID: Codable, Equatable, Sendable {
  public let subtype: LLDPChassisIDSubtype
  public let value: String

  public init(subtype: LLDPChassisIDSubtype, value: String) {
    self.subtype = subtype
    self.value = value
  }
}

public struct LLDPPortID: Codable, Equatable, Sendable {
  public let subtype: LLDPPortIDSubtype
  public let value: String

  public init(subtype: LLDPPortIDSubtype, value: String) {
    self.subtype = subtype
    self.value = value
  }
}

/// A management address TLV describing how to reach the remote device.
public struct LLDPManagementAddress: Codable, Equatable, Sendable {
  public let subtype: LLDPManagementAddressSubtype
  public let address: String
  public let interfaceNumber: UInt32?
  public let oid: String?

  public init(
    subtype: LLDPManagementAddressSubtype, address: String, interfaceNumber: UInt32?, oid: String?
  ) {
    self.subtype = subtype
    self.address = address
    self.interfaceNumber = interfaceNumber
    self.oid = oid
  }
}

/// Data model describing a discovered LLDP peer.
public struct LLDPNeighbor: Codable, Equatable, Sendable {
  public let chassisID: LLDPChassisID?
  public let portID: LLDPPortID?
  public let ttl: UInt16?
  public let portDescription: String?
  public let systemName: String?
  public let systemDescription: String?
  public let systemCapabilities: LLDPCapabilities?
  public let enabledCapabilities: LLDPCapabilities?
  public let managementAddresses: [LLDPManagementAddress]
  public let customTLVs: [LLDPTLV]

  public init(
    chassisID: LLDPChassisID?,
    portID: LLDPPortID?,
    ttl: UInt16?,
    portDescription: String?,
    systemName: String?,
    systemDescription: String?,
    systemCapabilities: LLDPCapabilities?,
    enabledCapabilities: LLDPCapabilities?,
    managementAddresses: [LLDPManagementAddress],
    customTLVs: [LLDPTLV]
  ) {
    self.chassisID = chassisID
    self.portID = portID
    self.ttl = ttl
    self.portDescription = portDescription
    self.systemName = systemName
    self.systemDescription = systemDescription
    self.systemCapabilities = systemCapabilities
    self.enabledCapabilities = enabledCapabilities
    self.managementAddresses = managementAddresses
    self.customTLVs = customTLVs
  }
}
