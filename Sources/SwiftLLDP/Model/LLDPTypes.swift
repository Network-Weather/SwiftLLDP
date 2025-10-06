import Foundation

public enum LLDPChassisIDSubtype: UInt8, Codable, CaseIterable, Sendable {
  case chassisComponent = 1
  case interfaceAlias = 2
  case portComponent = 3
  case macAddress = 4
  case networkAddress = 5
  case interfaceName = 6
  case local = 7
}

public enum LLDPPortIDSubtype: UInt8, Codable, CaseIterable, Sendable {
  case interfaceAlias = 1
  case portComponent = 2
  case macAddress = 3
  case networkAddress = 4
  case interfaceName = 5
  case agentCircuitID = 6
  case local = 7
}

public struct LLDPCapabilities: OptionSet, Codable, Sendable {
  public let rawValue: UInt16

  public init(rawValue: UInt16) {
    self.rawValue = rawValue
  }

  public static let other = LLDPCapabilities(rawValue: 1 << 0)
  public static let repeater = LLDPCapabilities(rawValue: 1 << 1)
  public static let bridge = LLDPCapabilities(rawValue: 1 << 2)
  public static let wlanAccessPoint = LLDPCapabilities(rawValue: 1 << 3)
  public static let router = LLDPCapabilities(rawValue: 1 << 4)
  public static let telephone = LLDPCapabilities(rawValue: 1 << 5)
  public static let docsis = LLDPCapabilities(rawValue: 1 << 6)
  public static let stationOnly = LLDPCapabilities(rawValue: 1 << 7)
  public static let cvlanBridge = LLDPCapabilities(rawValue: 1 << 8)
  public static let svlanBridge = LLDPCapabilities(rawValue: 1 << 9)
  public static let twoPortMacRelay = LLDPCapabilities(rawValue: 1 << 10)
}

public enum LLDPManagementAddressSubtype: UInt8, Codable, Sendable {
  case ipv4 = 1
  case ipv6 = 2
  case mac = 6
  case unknown

  public init(rawValue: UInt8) {
    switch rawValue {
    case 1: self = .ipv4
    case 2: self = .ipv6
    case 6: self = .mac
    default: self = .unknown
    }
  }
}

enum LLDPTLVType: UInt8 {
  case end = 0
  case chassisID = 1
  case portID = 2
  case ttl = 3
  case portDescription = 4
  case systemName = 5
  case systemDescription = 6
  case systemCapabilities = 7
  case managementAddress = 8
  case organizationallySpecific = 127
}
