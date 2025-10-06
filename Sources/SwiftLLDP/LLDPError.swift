import Foundation

/// Errors thrown while decoding LLDP payloads or capturing frames.
public enum LLDPError: Error, CustomNSError, LocalizedError {
  case truncatedFrame
  case malformedTLV(type: UInt8)
  case invalidChassisIDSubtype(UInt8)
  case invalidPortIDSubtype(UInt8)
  case invalidManagementAddress
  case captureFailure(message: String)
  case interfaceNotFound(String)

  public static var errorDomain: String { "org.network-weather.SwiftLLDP" }

  public var errorCode: Int {
    switch self {
    case .truncatedFrame: return 1
    case .malformedTLV: return 2
    case .invalidChassisIDSubtype: return 3
    case .invalidPortIDSubtype: return 4
    case .invalidManagementAddress: return 5
    case .captureFailure: return 6
    case .interfaceNotFound: return 7
    }
  }

  public var errorDescription: String? {
    switch self {
    case .truncatedFrame:
      return "LLDP frame shorter than expected"
    case .malformedTLV(let type):
      return "Malformed TLV encountered (type \(type))"
    case .invalidChassisIDSubtype(let value):
      return "Unsupported chassis ID subtype \(value)"
    case .invalidPortIDSubtype(let value):
      return "Unsupported port ID subtype \(value)"
    case .invalidManagementAddress:
      return "Invalid management address TLV"
    case .captureFailure(let message):
      return "pcap capture error: \(message)"
    case .interfaceNotFound(let name):
      return "Interface '\(name)' could not be opened for capture"
    }
  }
}
