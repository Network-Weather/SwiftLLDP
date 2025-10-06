import Darwin
import Foundation

/// Parses raw LLDP payloads into structured `LLDPNeighbor` values.
public struct LLDPParser {
  public init() {}

  /// Decode a raw LLDP PDU (without the Ethernet header) into a structured neighbor representation.
  /// - Parameter payload: A `Data` blob that starts at the first TLV of an LLDP frame.
  /// - Returns: A decoded `LLDPNeighbor`.
  /// - Throws: `LLDPError` when the payload is malformed.
  public func decode(payload: Data) throws -> LLDPNeighbor {
    var reader = ByteReader(payload)
    var tlvs: [LLDPTLV] = []

    while !reader.isAtEnd {
      let header = try reader.readUInt16()
      let type = UInt8((header & 0xFE00) >> 9)
      let length = Int(header & 0x01FF)

      if type == 0 {
        break
      }

      let value = try reader.readData(count: length)
      tlvs.append(LLDPTLV(type: type, length: length, rawValue: value))
    }

    var chassisID: LLDPChassisID?
    var portID: LLDPPortID?
    var ttl: UInt16?
    var portDescription: String?
    var systemName: String?
    var systemDescription: String?
    var systemCapabilities: LLDPCapabilities?
    var enabledCapabilities: LLDPCapabilities?
    var managementAddresses: [LLDPManagementAddress] = []
    var organizationalTLVs: [LLDPOrganizationalTLV] = []
    var customTLVs: [LLDPTLV] = []

    for tlv in tlvs {
      guard let tlvType = LLDPTLVType(rawValue: tlv.type) else {
        customTLVs.append(tlv)
        continue
      }
      switch tlvType {
      case .chassisID:
        chassisID = try decodeChassisID(tlv)
      case .portID:
        portID = try decodePortID(tlv)
      case .ttl:
        ttl = try decodeTTL(tlv)
      case .portDescription:
        portDescription = decodeString(tlv.rawValue)
      case .systemName:
        systemName = decodeString(tlv.rawValue)
      case .systemDescription:
        systemDescription = decodeString(tlv.rawValue)
      case .systemCapabilities:
        (systemCapabilities, enabledCapabilities) = try decodeCapabilities(tlv)
      case .managementAddress:
        if let address = try decodeManagementAddress(tlv) {
          managementAddresses.append(address)
        }
      case .organizationallySpecific:
        organizationalTLVs.append(try decodeOrganizational(tlv))
      case .end:
        break
      }
    }

    return LLDPNeighbor(
      chassisID: chassisID,
      portID: portID,
      ttl: ttl,
      portDescription: portDescription,
      systemName: systemName,
      systemDescription: systemDescription,
      systemCapabilities: systemCapabilities,
      enabledCapabilities: enabledCapabilities,
      managementAddresses: managementAddresses,
      organizationalTLVs: organizationalTLVs,
      customTLVs: customTLVs
    )
  }

  private func decodeChassisID(_ tlv: LLDPTLV) throws -> LLDPChassisID {
    guard let subtypeRaw = tlv.rawValue.first else {
      throw LLDPError.malformedTLV(type: tlv.type)
    }
    guard let subtype = LLDPChassisIDSubtype(rawValue: subtypeRaw) else {
      throw LLDPError.invalidChassisIDSubtype(subtypeRaw)
    }
    let valueBytes = tlv.rawValue.dropFirst()
    let value: String
    switch subtype {
    case .macAddress:
      value = formatMAC(valueBytes)
    case .networkAddress:
      value = formatNetworkAddress(valueBytes)
    default:
      value = decodeString(valueBytes)
    }
    return LLDPChassisID(subtype: subtype, value: value)
  }

  private func decodePortID(_ tlv: LLDPTLV) throws -> LLDPPortID {
    guard let subtypeRaw = tlv.rawValue.first else {
      throw LLDPError.malformedTLV(type: tlv.type)
    }
    guard let subtype = LLDPPortIDSubtype(rawValue: subtypeRaw) else {
      throw LLDPError.invalidPortIDSubtype(subtypeRaw)
    }
    let valueBytes = tlv.rawValue.dropFirst()
    let value: String
    switch subtype {
    case .macAddress:
      value = formatMAC(valueBytes)
    case .networkAddress:
      value = formatNetworkAddress(valueBytes)
    default:
      value = decodeString(valueBytes)
    }
    return LLDPPortID(subtype: subtype, value: value)
  }

  private func decodeTTL(_ tlv: LLDPTLV) throws -> UInt16 {
    guard tlv.rawValue.count == 2 else {
      throw LLDPError.malformedTLV(type: tlv.type)
    }
    return UInt16(tlv.rawValue[0]) << 8 | UInt16(tlv.rawValue[1])
  }

  private func decodeCapabilities(_ tlv: LLDPTLV) throws -> (LLDPCapabilities, LLDPCapabilities) {
    guard tlv.rawValue.count == 4 else {
      throw LLDPError.malformedTLV(type: tlv.type)
    }
    let supported = UInt16(tlv.rawValue[0]) << 8 | UInt16(tlv.rawValue[1])
    let enabled = UInt16(tlv.rawValue[2]) << 8 | UInt16(tlv.rawValue[3])
    return (LLDPCapabilities(rawValue: supported), LLDPCapabilities(rawValue: enabled))
  }

  private func decodeManagementAddress(_ tlv: LLDPTLV) throws -> LLDPManagementAddress? {
    var reader = ByteReader(tlv.rawValue)
    guard let addressLengthByte = tlv.rawValue.first, addressLengthByte > 0 else {
      throw LLDPError.invalidManagementAddress
    }
    let addressLength = Int(addressLengthByte)
    guard addressLength >= 2 else {
      throw LLDPError.invalidManagementAddress
    }
    _ = try reader.readUInt8()  // consume length
    let subtypeRaw = try reader.readUInt8()
    let subtype = LLDPManagementAddressSubtype(rawValue: subtypeRaw)
    let addressValue = try reader.readData(count: addressLength - 1)
    let interfaceSubtype = try reader.readUInt8()
    let interfaceNumberRaw = try reader.readUInt32()
    let interfaceNumber: UInt32? = interfaceSubtype == 0 ? nil : interfaceNumberRaw
    let oidLength = try reader.readUInt8()
    let oidData = try reader.readData(count: Int(oidLength))
    let addressString: String
    switch subtype {
    case .ipv4:
      addressString = formatIPv4(addressValue)
    case .ipv6:
      addressString = formatIPv6(addressValue)
    case .mac:
      addressString = formatMAC(addressValue)
    case .unknown:
      addressString = addressValue.map { String(format: "%02x", $0) }.joined()
    }
    let oidString = oidData.isEmpty ? nil : decodeString(oidData)
    return LLDPManagementAddress(
      subtype: subtype,
      address: addressString,
      interfaceNumber: interfaceNumber,
      oid: oidString
    )
  }

  private func decodeOrganizational(_ tlv: LLDPTLV) throws -> LLDPOrganizationalTLV {
    guard tlv.rawValue.count >= 4 else {
      throw LLDPError.malformedTLV(type: tlv.type)
    }
    let oui = UInt32(tlv.rawValue[0]) << 16 | UInt32(tlv.rawValue[1]) << 8 | UInt32(tlv.rawValue[2])
    let subtype = tlv.rawValue[3]
    let payload = Data(tlv.rawValue.dropFirst(4))
    return LLDPOrganizationalTLV(oui: oui, subtype: subtype, payload: payload)
  }

  private func decodeString(_ bytes: Data) -> String {
    if let string = String(data: bytes, encoding: .utf8), !string.isEmpty {
      return string
    }
    if let string = String(data: bytes, encoding: .ascii), !string.isEmpty {
      return string
    }
    return bytes.map { String(format: "%02X", $0) }.joined()
  }

  private func formatMAC(_ bytes: Data) -> String {
    bytes.map { String(format: "%02X", $0) }.joined(separator: ":")
  }

  private func formatNetworkAddress(_ bytes: Data) -> String {
    guard let family = bytes.first else { return decodeString(bytes) }
    let body = bytes.dropFirst()
    switch family {
    case 1:
      return formatIPv4(body)
    case 2:
      return formatIPv6(body)
    case 6:
      return formatMAC(body)
    default:
      return body.map { String(format: "%02x", $0) }.joined()
    }
  }

  private func formatIPv4(_ bytes: Data) -> String {
    guard bytes.count == 4 else { return decodeString(bytes) }
    return bytes.map { String($0) }.joined(separator: ".")
  }

  private func formatIPv6(_ bytes: Data) -> String {
    guard bytes.count == 16 else { return decodeString(bytes) }
    return bytes.withUnsafeBytes { rawPointer -> String in
      guard let source = rawPointer.baseAddress else { return decodeString(bytes) }
      var destination = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
      return destination.withUnsafeMutableBufferPointer { buffer in
        guard let dst = buffer.baseAddress else {
          return decodeString(bytes)
        }
        guard inet_ntop(AF_INET6, source, dst, socklen_t(buffer.count)) != nil else {
          return decodeString(bytes)
        }
        return String(cString: dst)
      }
    }
  }
}
