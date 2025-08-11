import Foundation
import Security

struct KeychainService {
    
    // Uniquely identify the keychain item
    private static let service = "com.yourapp.passcode" // Should be unique to your app
    private static let account = "userPasscode"

    // MARK: - Save Passcode
    
    /// Saves the user's passcode securely to the Keychain.
    /// - Parameter passcode: The 4-digit passcode string to save.
    /// - Returns: A boolean indicating whether the save operation was successful.
    static func save(passcode: String) -> Bool {
        guard let data = passcode.data(using: .utf8) else {
            print("Keychain Error: Could not convert passcode to data.")
            return false
        }

        // 1. Check if an item already exists
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)

        switch status {
        case errSecSuccess: // Item found, update it
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data
            ]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            if updateStatus == errSecSuccess {
                print("Keychain: Passcode updated successfully.")
                return true
            } else {
                print("Keychain Error: Failed to update passcode. Status: \(updateStatus)")
                return false
            }

        case errSecItemNotFound: // Item not found, add it
            var newItem = query
            newItem[kSecValueData as String] = data
            // Set accessibility to only allow access when device is unlocked
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked

            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            if addStatus == errSecSuccess {
                print("Keychain: Passcode saved successfully.")
                return true
            } else {
                print("Keychain Error: Failed to save passcode. Status: \(addStatus)")
                return false
            }

        default: // Any other error
            print("Keychain Error: An unknown error occurred. Status: \(status)")
            return false
        }
    }

    // MARK: - Get Passcode
    
    /// Retrieves the user's passcode from the Keychain.
    /// - Returns: The stored passcode string, or `nil` if it doesn't exist or an error occurs.
    static func getPasscode() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess {
            guard let data = dataTypeRef as? Data,
                  let passcode = String(data: data, encoding: .utf8) else {
                print("Keychain Error: Could not decode passcode data.")
                return nil
            }
            print("Keychain: Passcode retrieved successfully.")
            return passcode
        } else if status == errSecItemNotFound {
            print("Keychain: No passcode found.")
            return nil
        } else {
            print("Keychain Error: Failed to retrieve passcode. Status: \(status)")
            return nil
        }
    }

    // MARK: - Delete Passcode
    
    /// Deletes the user's passcode from the Keychain.
    /// - Returns: A boolean indicating whether the deletion was successful.
    static func deletePasscode() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        switch status {
        case errSecSuccess:
            print("Keychain: Passcode deleted successfully.")
            return true
        case errSecItemNotFound:
            print("Keychain: No passcode to delete, which is fine.")
            return true // It's not an error if it wasn't there to begin with
        default:
            print("Keychain Error: Failed to delete passcode. Status: \(status)")
            return false
        }
    }
} 