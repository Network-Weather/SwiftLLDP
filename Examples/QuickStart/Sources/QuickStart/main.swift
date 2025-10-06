import SwiftLLDP

@main
struct QuickStartApp {
  static func main() async {
    let client = LLDPClient()
    do {
      let neighbors = try client.discover(on: "en0", duration: 60, limit: 5)
      if neighbors.isEmpty {
        print("No LLDP neighbors discovered in the sampling window.")
      }
      for (index, neighbor) in neighbors.enumerated() {
        print("Neighbor #\(index + 1): \(neighbor.systemName ?? "Unknown")")
      }
    } catch {
      print("Failed to discover LLDP neighbors: \(error)")
    }
  }
}
