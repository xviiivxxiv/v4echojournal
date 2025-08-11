import UIKit
import FirebaseCore
import SuperwallKit
import FacebookCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // --- Manual Firebase and Google Sign-In Configuration ---
        
        // 1. Find the GoogleService-Info.plist file
        guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            fatalError("FATAL ERROR: GoogleService-Info.plist not found in app bundle.")
        }
        
        // ** NEW: Manually parse the plist to debug **
        if let plistDict = NSDictionary(contentsOfFile: plistPath) {
            print("🔍 Manually Parsed GoogleService-Info.plist:")
            for (key, value) in plistDict {
                print("   - Key: \(key), Value: \(value)")
            }
            if let clientID = plistDict["CLIENT_ID"] as? String {
                print("✅ TEST PASSED: CLIENT_ID found manually: \(clientID)")
            } else {
                print("❌ TEST FAILED: CLIENT_ID key NOT found in the plist file.")
            }
        }
        
        // 2. Create FirebaseOptions from the file
        guard let firebaseOptions = FirebaseOptions(contentsOfFile: plistPath) else {
            fatalError("FATAL ERROR: Could not create FirebaseOptions from GoogleService-Info.plist.")
        }
        
        // 3. Configure Firebase with the manual options
        print("▶️ Custom AppDelegate: Configuring Firebase MANUALLY...")
        FirebaseApp.configure(options: firebaseOptions)
        print("✅ Custom AppDelegate: Firebase configured MANUALLY.")
        
        // 4. Configure Google Sign-In with the explicit clientID
        guard let clientID = firebaseOptions.clientID else {
            fatalError("FATAL ERROR: clientID not found in the manually configured Firebase options.")
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        print("✅ Custom AppDelegate: Google Sign-In configured MANUALLY with ClientID.")
        
        // --- Other Services ---

        print("▶️ Custom AppDelegate: Configuring Superwall...")
        Superwall.configure(apiKey: "pk_6a1858950ed4e5f8020095f48dea661eb7ea11e91489719d")
        print("✅ Custom AppDelegate: Superwall configured.")
        
        print("▶️ Custom AppDelegate: Configuring Facebook SDK...")
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        print("✅ Custom AppDelegate: Facebook SDK configured.")
        
        // ** THE TEST **
        if let testValue = Bundle.main.object(forInfoDictionaryKey: "Test_Key_For_Verification") as? String {
            print("✅ TEST PASSED: Found test key with value: '\(testValue)'")
        } else {
            print("❌ TEST FAILED: Could not find 'Test_Key_For_Verification' in the Info.plist being used by the project.")
        }
        
        return true
    }
    
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        // Handle both Google and Facebook URL schemes
        let isGoogleURL = GIDSignIn.sharedInstance.handle(url)
        let isFacebookURL = ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
            annotation: options[UIApplication.OpenURLOptionsKey.annotation]
        )
        
        return isGoogleURL || isFacebookURL
    }
} 