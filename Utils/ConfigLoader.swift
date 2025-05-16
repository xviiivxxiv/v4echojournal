import Foundation

enum ConfigError: Error {
    case fileNotFound
    case keyNotFound
    case invalidFormat
}

class ConfigLoader {
    static let shared = ConfigLoader()
    private var config: [String: Any]?

    private init() {
        print("▶️ ConfigLoader: init() called.")
        loadConfig()
    }

    private func loadConfig() {
        print("▶️ ConfigLoader: loadConfig() called.")
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let xml = FileManager.default.contents(atPath: path) else {
            print("❌ ConfigLoader: Config.plist not found in bundle. Check name and Target Membership.") // More specific error
            config = nil
            return
        }
        print("  ConfigLoader: Found Config.plist at path: \(path)")

        do {
            config = try PropertyListSerialization.propertyList(from: xml, options: .mutableContainersAndLeaves, format: nil) as? [String: Any]
             print("✅ ConfigLoader: Config.plist loaded successfully.")
        } catch {
            print("❌ ConfigLoader: Failed to parse Config.plist - \(error)")
            config = nil
        }
    }

    func getOpenAIKey() throws -> String {
        print("▶️ ConfigLoader: getOpenAIKey() called.")
        guard let config = config else {
             print("❌ ConfigLoader: Config dictionary is nil. loadConfig must have failed earlier.") // Changed message slightly
            throw ConfigError.fileNotFound // Or a different internal error
        }
        print("  ConfigLoader: Config dictionary loaded, checking for key...")
        guard let apiKey = config["OPENAI_API_KEY"] as? String, !apiKey.isEmpty else {
            print("❌ ConfigLoader: 'OPENAI_API_KEY' key not found, is empty, or not a String in Config.plist.") // More specific error
            throw ConfigError.keyNotFound
        }
        // Optional: Add validation if needed (e.g., check prefix "sk-")
        print("🔑 ConfigLoader: Retrieved OPENAI_API_KEY from Config.plist.")
        return apiKey
    }
} 