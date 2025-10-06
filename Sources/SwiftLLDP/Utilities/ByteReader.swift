import Foundation

struct ByteReader {
  private let data: Data
  private var offset: Data.Index = 0

  init(_ data: Data) {
    self.data = data
  }

  var isAtEnd: Bool { offset >= data.endIndex }
  var remainingCount: Int { data.count - offset }

  mutating func readUInt8() throws -> UInt8 {
    guard offset < data.endIndex else {
      throw LLDPError.truncatedFrame
    }
    let value = data[offset]
    offset += 1
    return value
  }

  mutating func readUInt16() throws -> UInt16 {
    let high = try readUInt8()
    let low = try readUInt8()
    return (UInt16(high) << 8) | UInt16(low)
  }

  mutating func readUInt32() throws -> UInt32 {
    let byte0 = try readUInt8()
    let byte1 = try readUInt8()
    let byte2 = try readUInt8()
    let byte3 = try readUInt8()
    return (UInt32(byte0) << 24) | (UInt32(byte1) << 16) | (UInt32(byte2) << 8) | UInt32(byte3)
  }

  mutating func readData(count: Int) throws -> Data {
    guard count >= 0, data.distance(from: offset, to: data.endIndex) >= count else {
      throw LLDPError.truncatedFrame
    }
    let end = data.index(offset, offsetBy: count)
    let slice = data[offset..<end]
    offset = end
    return Data(slice)
  }
}
