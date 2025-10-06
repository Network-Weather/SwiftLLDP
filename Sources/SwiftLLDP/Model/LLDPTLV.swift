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

/// Organizationally specific TLV carrying vendor-defined data.
///
/// Instances provide both raw bytes and a decoded summary so consumers can render vendor specific
/// information—including LLDP-MED extensions—without losing access to the original payload.
public struct LLDPOrganizationalTLV: Codable, Equatable, Sendable {
  /// IEEE Organizationally Unique Identifier (lowest 24 bits are significant).
  public let oui: UInt32
  public let subtype: UInt8
  public let payload: Data
  public let decoded: LLDPOrganizationalPayload

  public init(oui: UInt32, subtype: UInt8, payload: Data) {
    self.oui = oui & 0x00FF_FFFF
    self.subtype = subtype
    self.payload = payload
    self.decoded = LLDPOrganizationalPayload(oui: self.oui, subtype: subtype, payload: payload)
  }

  /// The OUI broken out into its constituent bytes.
  public var ouiBytes: (UInt8, UInt8, UInt8) {
    (UInt8((oui >> 16) & 0xFF), UInt8((oui >> 8) & 0xFF), UInt8(oui & 0xFF))
  }

  /// Human readable rendering of the OUI (for example `00-12-BB`).
  public var ouiString: String {
    let (first, second, third) = ouiBytes
    return String(format: "%02X-%02X-%02X", first, second, third)
  }

  /// Convenience accessor for LLDP-MED extensions when present.
  public var med: LLDPMEDExtension? {
    decoded.med
  }

  private enum CodingKeys: String, CodingKey {
    case oui
    case subtype
    case payload
    case decoded
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let oui = try container.decode(UInt32.self, forKey: .oui)
    let subtype = try container.decode(UInt8.self, forKey: .subtype)
    let payload = try container.decode(Data.self, forKey: .payload)
    self.init(oui: oui, subtype: subtype, payload: payload)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(oui, forKey: .oui)
    try container.encode(subtype, forKey: .subtype)
    try container.encode(payload, forKey: .payload)
    try container.encode(decoded, forKey: .decoded)
  }
}

/// Human-friendly interpretation of an organizational TLV payload.
///
/// The payload attempts to recognise LLDP-MED extensions; if the data is textual ASCII it is
/// surfaced as-is, otherwise a hexadecimal representation is provided.
public struct LLDPOrganizationalPayload: Codable, Equatable, Sendable {
  public let summary: String
  public let med: LLDPMEDExtension?
  public let text: String?
  public let hexData: String?
  public let dataLength: Int

  private let raw: Data

  public init(oui: UInt32, subtype: UInt8, payload: Data) {
    self.raw = payload
    self.dataLength = payload.count
    if let med = LLDPMEDExtension.parse(oui: oui, subtype: subtype, payload: payload) {
      self.med = med
      self.summary = med.summary
      self.text = med.text
      self.hexData = med.binaryHex
    } else if let ascii = LLDPOrganizationalPayload.decodeASCII(payload) {
      self.med = nil
      self.summary = ascii
      self.text = ascii
      self.hexData = nil
    } else {
      self.med = nil
      self.text = nil
      self.hexData = LLDPOrganizationalPayload.hexString(payload)
      let (first, second, third) = (
        UInt8((oui >> 16) & 0xFF),
        UInt8((oui >> 8) & 0xFF),
        UInt8(oui & 0xFF)
      )
      self.summary = String(
        format: "OUI %02X-%02X-%02X subtype %d (%d bytes)",
        first, second, third, subtype, payload.count
      )
    }
  }

  /// Raw payload bytes for organizational TLVs.
  /// Raw payload bytes for organizational TLVs.
  public var rawData: Data { raw }

  private static func decodeASCII(_ data: Data) -> String? {
    guard !data.isEmpty else { return nil }
    guard data.allSatisfy({ $0 >= 0x20 && $0 <= 0x7E }) else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private static func hexString(_ data: Data) -> String? {
    guard !data.isEmpty else { return nil }
    return data.map { String(format: "%02X", $0) }.joined()
  }

  private enum CodingKeys: String, CodingKey {
    case summary
    case med
    case text
    case hexData
    case dataLength
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.summary = try container.decode(String.self, forKey: .summary)
    self.med = try container.decodeIfPresent(LLDPMEDExtension.self, forKey: .med)
    self.text = try container.decodeIfPresent(String.self, forKey: .text)
    self.hexData = try container.decodeIfPresent(String.self, forKey: .hexData)
    self.dataLength = try container.decode(Int.self, forKey: .dataLength)
    self.raw = Data()
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(summary, forKey: .summary)
    try container.encodeIfPresent(med, forKey: .med)
    try container.encodeIfPresent(text, forKey: .text)
    try container.encodeIfPresent(hexData, forKey: .hexData)
    try container.encode(dataLength, forKey: .dataLength)
  }
}

/// Parsed LLDP-MED extension embedded within an organizational TLV.
///
/// Extensions describe endpoint capabilities, power negotiation, and inventory metadata defined in
/// ANSI/TIA-1057.
public struct LLDPMEDExtension: Codable, Equatable, Sendable {
  public enum Kind: String, Codable, Sendable {
    case capabilities
    case networkPolicy
    case locationIdentification
    case extendedPower
    case hardwareRevision
    case firmwareRevision
    case softwareRevision
    case serialNumber
    case manufacturerName
    case modelName
    case assetID
    case other
  }

  /// Structured view of LLDP-MED endpoint capabilities.
  public struct Capabilities: Codable, Equatable, Sendable {
    public let flags: LLDPMEDCapabilityFlags
    public let deviceType: LLDPMEDDeviceType
  }

  /// Structured view of LLDP-MED extended power information.
  public struct ExtendedPower: Codable, Equatable, Sendable {
    public let powerType: LLDPMEDPowerType
    public let powerSource: LLDPMEDPowerSource
    public let powerPriority: LLDPMEDPowerPriority
    public let powerValueTenthsWatts: UInt16

    public var powerValueWatts: Double {
      Double(powerValueTenthsWatts) / 10.0
    }

    /// Attempt to infer the IEEE 802.3 PoE class from the requested power.
    public var inferredPoEStandard: String? {
      let watts = powerValueWatts
      switch watts {
      case ..<0:
        return nil
      case ...13.5:
        return "802.3af (PoE)"
      case ...26.0:
        return "802.3at (PoE+)"
      case ...52.0:
        return "802.3bt Type 3 (PoE++)"
      case ...72.0:
        return "802.3bt Type 4 (PoE++)"
      default:
        return String(format: "Non-standard (>%.1f W)", watts)
      }
    }
  }

  public let kind: Kind
  public let subtype: UInt8
  public let capabilities: Capabilities?
  public let extendedPower: ExtendedPower?
  public let text: String?
  public let binaryHex: String?

  public init(
    kind: Kind,
    subtype: UInt8,
    capabilities: Capabilities? = nil,
    extendedPower: ExtendedPower? = nil,
    text: String? = nil,
    binaryHex: String? = nil
  ) {
    self.kind = kind
    self.subtype = subtype
    self.capabilities = capabilities
    self.extendedPower = extendedPower
    self.text = text
    self.binaryHex = binaryHex
  }

  /// A concise human-readable summary appropriate for UI presentation.
  public var summary: String {
    switch kind {
    case .capabilities:
      return "LLDP-MED Capabilities"
    case .networkPolicy:
      return "LLDP-MED Network Policy"
    case .locationIdentification:
      return "LLDP-MED Location Identification"
    case .extendedPower:
      return "LLDP-MED Extended Power via MDI"
    case .hardwareRevision:
      return text.map { "Hardware Revision: " + $0 } ?? "LLDP-MED Hardware Revision"
    case .firmwareRevision:
      return text.map { "Firmware Revision: " + $0 } ?? "LLDP-MED Firmware Revision"
    case .softwareRevision:
      return text.map { "Software Revision: " + $0 } ?? "LLDP-MED Software Revision"
    case .serialNumber:
      return text.map { "Serial Number: " + $0 } ?? "LLDP-MED Serial Number"
    case .manufacturerName:
      return text.map { "Manufacturer: " + $0 } ?? "LLDP-MED Manufacturer Name"
    case .modelName:
      return text.map { "Model: " + $0 } ?? "LLDP-MED Model Name"
    case .assetID:
      return text.map { "Asset ID: " + $0 } ?? "LLDP-MED Asset ID"
    case .other:
      return "LLDP-MED Subtype \(subtype)"
    }
  }

  /// Convenience rendering of capability flags ready for user display.
  public var capabilityFlagDescriptions: [String]? {
    capabilities?.flags.descriptions
  }

  /// Human readable description of the device type if present.
  public var deviceTypeDescription: String? {
    capabilities?.deviceType.description
  }

  /// Convenience accessor that returns the extended power information if present.
  public var powerSummary: (type: String, source: String, priority: String, watts: Double)? {
    guard let extendedPower else { return nil }
    return (
      extendedPower.powerType.description,
      extendedPower.powerSource.description,
      extendedPower.powerPriority.description,
      extendedPower.powerValueWatts
    )
  }

  /// Attempt to parse a TLV payload as an LLDP-MED extension.
  ///
  /// - Parameters:
  ///   - oui: Organizationally Unique Identifier associated with the TLV.
  ///   - subtype: Organization-defined subtype.
  ///   - payload: The TLV payload data.
  /// - Returns: A parsed ``LLDPMEDExtension`` when the OUI is recognised, otherwise `nil`.
  public static func parse(oui: UInt32, subtype: UInt8, payload: Data) -> LLDPMEDExtension? {
    guard oui == 0x0012BB else { return nil }
    return decode(subtype: subtype, payload: payload)
  }

  private static func decode(subtype: UInt8, payload: Data) -> LLDPMEDExtension? {
    switch subtype {
    case 1:
      guard payload.count >= 3 else { return nil }
      let flags = LLDPMEDCapabilityFlags(rawValue: UInt16(payload[0]) << 8 | UInt16(payload[1]))
      let device = LLDPMEDDeviceType(rawValue: payload[2])
      let capabilities = Capabilities(flags: flags, deviceType: device)
      return LLDPMEDExtension(
        kind: .capabilities,
        subtype: subtype,
        capabilities: capabilities,
        extendedPower: nil,
        text: nil,
        binaryHex: nil
      )
    case 2:
      return LLDPMEDExtension(
        kind: .networkPolicy,
        subtype: subtype,
        capabilities: nil,
        extendedPower: nil,
        text: nil,
        binaryHex: hexString(payload)
      )
    case 3:
      return LLDPMEDExtension(
        kind: .locationIdentification,
        subtype: subtype,
        capabilities: nil,
        extendedPower: nil,
        text: nil,
        binaryHex: hexString(payload)
      )
    case 4:
      guard payload.count >= 3 else { return nil }
      let descriptor = payload[0]
      let powerType = LLDPMEDPowerType(rawValue: descriptor >> 6)
      let powerSource = LLDPMEDPowerSource(rawValue: (descriptor >> 4) & 0x3)
      let powerPriority = LLDPMEDPowerPriority(rawValue: descriptor & 0xF)
      let tenthsWatts = UInt16(payload[1]) << 8 | UInt16(payload[2])
      let power = ExtendedPower(
        powerType: powerType,
        powerSource: powerSource,
        powerPriority: powerPriority,
        powerValueTenthsWatts: tenthsWatts
      )
      return LLDPMEDExtension(
        kind: .extendedPower,
        subtype: subtype,
        capabilities: nil,
        extendedPower: power,
        text: nil,
        binaryHex: nil
      )
    case 5:
      return makeText(kind: .hardwareRevision, subtype: subtype, payload: payload)
    case 6:
      return makeText(kind: .firmwareRevision, subtype: subtype, payload: payload)
    case 7:
      return makeText(kind: .softwareRevision, subtype: subtype, payload: payload)
    case 8:
      return makeText(kind: .serialNumber, subtype: subtype, payload: payload)
    case 9:
      return makeText(kind: .manufacturerName, subtype: subtype, payload: payload)
    case 10:
      return makeText(kind: .modelName, subtype: subtype, payload: payload)
    case 11:
      return makeText(kind: .assetID, subtype: subtype, payload: payload)
    default:
      return LLDPMEDExtension(
        kind: .other,
        subtype: subtype,
        capabilities: nil,
        extendedPower: nil,
        text: nil,
        binaryHex: hexString(payload)
      )
    }
  }

  private static func makeText(kind: Kind, subtype: UInt8, payload: Data) -> LLDPMEDExtension? {
    if let text = String(data: payload, encoding: .utf8), !text.isEmpty {
      return LLDPMEDExtension(
        kind: kind,
        subtype: subtype,
        capabilities: nil,
        extendedPower: nil,
        text: text,
        binaryHex: nil
      )
    }
    return LLDPMEDExtension(
      kind: kind,
      subtype: subtype,
      capabilities: nil,
      extendedPower: nil,
      text: nil,
      binaryHex: hexString(payload)
    )
  }

  private static func hexString(_ data: Data) -> String? {
    guard !data.isEmpty else { return nil }
    return data.map { String(format: "%02X", $0) }.joined()
  }

  private enum CodingKeys: String, CodingKey {
    case kind
    case subtype
    case capabilities
    case extendedPower
    case text
    case binaryHex
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.kind = try container.decode(Kind.self, forKey: .kind)
    self.subtype = try container.decode(UInt8.self, forKey: .subtype)
    self.capabilities = try container.decodeIfPresent(Capabilities.self, forKey: .capabilities)
    self.extendedPower = try container.decodeIfPresent(ExtendedPower.self, forKey: .extendedPower)
    self.text = try container.decodeIfPresent(String.self, forKey: .text)
    self.binaryHex = try container.decodeIfPresent(String.self, forKey: .binaryHex)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(kind, forKey: .kind)
    try container.encode(subtype, forKey: .subtype)
    try container.encodeIfPresent(capabilities, forKey: .capabilities)
    try container.encodeIfPresent(extendedPower, forKey: .extendedPower)
    try container.encodeIfPresent(text, forKey: .text)
    try container.encodeIfPresent(binaryHex, forKey: .binaryHex)
  }
}

public struct LLDPMEDCapabilityFlags: OptionSet, Codable, Sendable {
  public let rawValue: UInt16

  public init(rawValue: UInt16) {
    self.rawValue = rawValue
  }

  public static let capabilities = LLDPMEDCapabilityFlags(rawValue: 1 << 0)
  public static let networkPolicy = LLDPMEDCapabilityFlags(rawValue: 1 << 1)
  public static let locationIdentification = LLDPMEDCapabilityFlags(rawValue: 1 << 2)
  public static let extendedPowerPSE = LLDPMEDCapabilityFlags(rawValue: 1 << 3)
  public static let extendedPowerPD = LLDPMEDCapabilityFlags(rawValue: 1 << 4)
  public static let inventory = LLDPMEDCapabilityFlags(rawValue: 1 << 5)

  public var descriptions: [String] {
    var result: [String] = []
    if contains(.capabilities) { result.append("capabilities") }
    if contains(.networkPolicy) { result.append("network-policy") }
    if contains(.locationIdentification) { result.append("location-identification") }
    if contains(.extendedPowerPSE) { result.append("extended-power-pse") }
    if contains(.extendedPowerPD) { result.append("extended-power-pd") }
    if contains(.inventory) { result.append("inventory") }
    return result
  }

  public static func from(descriptions: [String]) -> LLDPMEDCapabilityFlags {
    var flags: LLDPMEDCapabilityFlags = []
    for description in descriptions {
      switch description.lowercased() {
      case "capabilities": flags.insert(.capabilities)
      case "network-policy", "networkpolicy": flags.insert(.networkPolicy)
      case "location-identification", "locationidentification":
        flags.insert(.locationIdentification)
      case "extended-power-pse", "extendedpowerpse": flags.insert(.extendedPowerPSE)
      case "extended-power-pd", "extendedpowerpd": flags.insert(.extendedPowerPD)
      case "inventory": flags.insert(.inventory)
      default: break
      }
    }
    return flags
  }
}

public enum LLDPMEDDeviceType: Equatable, Sendable {
  case notDefined
  case endpointClassI
  case endpointClassII
  case endpointClassIII
  case networkConnectivity
  case unknown(rawValue: UInt8)

  public init(rawValue: UInt8) {
    switch rawValue {
    case 0: self = .notDefined
    case 1: self = .endpointClassI
    case 2: self = .endpointClassII
    case 3: self = .endpointClassIII
    case 4: self = .networkConnectivity
    default: self = .unknown(rawValue: rawValue)
    }
  }

  public init(description: String) {
    let normalized =
      description
      .lowercased()
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "-", with: "")
      .replacingOccurrences(of: "_", with: "")
    switch normalized {
    case "notdefined": self = .notDefined
    case "endpointclassi": self = .endpointClassI
    case "endpointclassii": self = .endpointClassII
    case "endpointclassiii": self = .endpointClassIII
    case "networkconnectivity", "networkconnectivitydevice": self = .networkConnectivity
    default: self = .unknown(rawValue: 0xFF)
    }
  }

  public var rawValue: UInt8 {
    switch self {
    case .notDefined: return 0
    case .endpointClassI: return 1
    case .endpointClassII: return 2
    case .endpointClassIII: return 3
    case .networkConnectivity: return 4
    case .unknown(let raw): return raw
    }
  }

  public var description: String {
    switch self {
    case .notDefined: return "not-defined"
    case .endpointClassI: return "endpoint-class-i"
    case .endpointClassII: return "endpoint-class-ii"
    case .endpointClassIII: return "endpoint-class-iii"
    case .networkConnectivity: return "network-connectivity"
    case .unknown(let raw): return "unknown(\(raw))"
    }
  }
}

extension LLDPMEDDeviceType: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let value = try? container.decode(UInt8.self) {
      self.init(rawValue: value)
    } else if let description = try? container.decode(String.self) {
      self.init(description: description)
    } else {
      self = .unknown(rawValue: 0xFF)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(description)
  }
}

public enum LLDPMEDPowerType: Equatable, Sendable {
  case pse
  case pd
  case pseAndPd
  case reserved(rawValue: UInt8)

  init(rawValue: UInt8) {
    switch rawValue & 0x3 {
    case 0: self = .pse
    case 1: self = .pd
    case 2: self = .pseAndPd
    default: self = .reserved(rawValue: rawValue & 0x3)
    }
  }

  public var description: String {
    switch self {
    case .pse: return "PSE Device"
    case .pd: return "PD Device"
    case .pseAndPd: return "PSE and PD Device"
    case .reserved(let value): return "Reserved(\(value))"
    }
  }
}

extension LLDPMEDPowerType: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let raw = try container.decode(UInt8.self)
    self.init(rawValue: raw)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .pse: try container.encode(UInt8(0))
    case .pd: try container.encode(UInt8(1))
    case .pseAndPd: try container.encode(UInt8(2))
    case .reserved(let raw): try container.encode(raw & 0x3)
    }
  }
}

public enum LLDPMEDPowerSource: Equatable, Sendable {
  case unknown
  case primary
  case backup
  case reserved(rawValue: UInt8)

  init(rawValue: UInt8) {
    switch rawValue & 0x3 {
    case 0: self = .unknown
    case 1: self = .primary
    case 2: self = .backup
    default: self = .reserved(rawValue: rawValue & 0x3)
    }
  }

  public var description: String {
    switch self {
    case .unknown: return "Unknown"
    case .primary: return "Primary Power Source"
    case .backup: return "Backup Power Source"
    case .reserved(let value): return "Reserved(\(value))"
    }
  }
}

extension LLDPMEDPowerSource: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let raw = try container.decode(UInt8.self)
    self.init(rawValue: raw)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .unknown: try container.encode(UInt8(0))
    case .primary: try container.encode(UInt8(1))
    case .backup: try container.encode(UInt8(2))
    case .reserved(let raw): try container.encode(raw & 0x3)
    }
  }
}

public enum LLDPMEDPowerPriority: Equatable, Sendable {
  case unknown
  case critical
  case high
  case low
  case reserved(rawValue: UInt8)

  init(rawValue: UInt8) {
    switch rawValue & 0xF {
    case 0: self = .unknown
    case 1: self = .critical
    case 2: self = .high
    case 3: self = .low
    default: self = .reserved(rawValue: rawValue & 0xF)
    }
  }

  public var description: String {
    switch self {
    case .unknown: return "Unknown"
    case .critical: return "Critical"
    case .high: return "High"
    case .low: return "Low"
    case .reserved(let value): return "Reserved(\(value))"
    }
  }
}

extension LLDPMEDPowerPriority: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let raw = try container.decode(UInt8.self)
    self.init(rawValue: raw)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .unknown: try container.encode(UInt8(0))
    case .critical: try container.encode(UInt8(1))
    case .high: try container.encode(UInt8(2))
    case .low: try container.encode(UInt8(3))
    case .reserved(let raw): try container.encode(raw & 0xF)
    }
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
  public let organizationalTLVs: [LLDPOrganizationalTLV]
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
    organizationalTLVs: [LLDPOrganizationalTLV],
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
    self.organizationalTLVs = organizationalTLVs
    self.customTLVs = customTLVs
  }

  /// Convenience accessor for all LLDP-MED extensions present on the neighbor.
  public var medExtensions: [LLDPMEDExtension] {
    organizationalTLVs.compactMap { $0.med }
  }
}
