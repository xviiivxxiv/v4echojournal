import Foundation
import FirebaseCore
import FirebaseAppCheck

class CustomAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
        // Use the debug provider for builds run from Xcode on a real device.
        return AppCheckDebugProvider(app: app)
        #else
        // Use the App Attest provider for TestFlight and App Store builds.
        return AppAttestProvider(app: app)
        #endif
    }
}




