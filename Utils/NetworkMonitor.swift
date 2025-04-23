import Foundation
import Network
import Combine

/// Monitors network connectivity status.
@MainActor // Ensure updates are published on the main thread
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.echournal.networkmonitor")

    /// Published property indicating current connectivity status.
    @Published var isConnected: Bool = false

    private init() {
        monitor = NWPathMonitor()
        
        monitor.pathUpdateHandler = { [weak self] path in
            // Update isConnected on the main thread
            DispatchQueue.main.async {
                self?.isConnected = (path.status == .satisfied)
                print("Network Status Changed: \(self?.isConnected ?? false ? "Connected" : "Disconnected")")
            }
        }
        
        monitor.start(queue: queue)
        print("Network Monitor Started.")
    }

    deinit {
        monitor.cancel()
        print("Network Monitor Cancelled.")
    }
} 