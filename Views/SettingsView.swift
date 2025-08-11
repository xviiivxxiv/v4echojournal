import SwiftUI
import UserNotifications // Import UserNotifications framework

struct SettingsView: View {
    // MARK: - Properties
    
    // Environment
    @Environment(\.dismiss) private var dismiss
    
    // State for notification permission
    @State private var notificationPermissionGranted = false
    
    // Auth Service and Settings Manager
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var authFlow: AuthenticationFlowManager
    
    // State for presenting auth sheet
    @State private var showingAuthSheet = false
    
    // State for erase data alert
    @State private var showingEraseAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                // Use a grouped-style background color for consistency
                Color(.systemGroupedBackground).ignoresSafeArea()

                Form {
                    // MARK: - Premium & Account Section
                    Section {
                        if authService.user != nil {
                            accountView
                        } else {
                            signInView
                        }
                    }
                    
                    // MARK: - General Section
                    Section(header: Text("General").font(.system(size: 14, weight: .regular, design: .default))) {
                        NavigationLink(destination: NotificationSettingsView()) {
                            SettingsRowView(title: "Notifications", iconName: "bell.fill", iconColor: .yellow)
                        }
                        NavigationLink(destination: EditNameView()) {
                            SettingsRowView(title: "Edit Name", iconName: "pencil", iconColor: .orange)
                        }
                        // For language, we link to the app's settings in the iOS Settings app
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            Link(destination: url) {
                                SettingsRowView(title: "Language", iconName: "globe", iconColor: .blue)
                            }
                        }
                    }
                    
                    // MARK: - Security Section
                    Section(header: Text("Security").font(.system(size: 14, weight: .regular, design: .default))) {
                        NavigationLink(destination: PasscodeSettingsView()) {
                            SettingsRowView(title: "Passcode & Face ID", iconName: "lock.shield.fill", iconColor: .green)
                        }
                        
                        Toggle(isOn: $settings.stayLoggedIn) {
                            SettingsRowView(title: "Stay Logged In", subtitle: settings.stayLoggedIn ? "On" : "Off", iconName: "person.badge.key.fill", iconColor: .blue)
                        }
                        .tint(Color.buttonBrown)
                    }

                    // MARK: - Support & Legal Section
                    Section(header: Text("Support").font(.system(size: 14, weight: .regular, design: .default))) {
                        Button(action: openSupportEmail) {
                            SettingsRowView(title: "Contact Support", iconName: "bubble.left.and.bubble.right.fill", iconColor: .gray)
                    }
                        
                        Button(action: copyUserID) {
                           SettingsRowView(title: "Copy My ID", iconName: "doc.on.doc.fill", iconColor: .purple)
                        }
                    }

                    Section {
                         Link(destination: URL(string: "https://www.example.com/terms")!) {
                            SettingsRowView(title: "Terms of Use", iconName: "doc.text.fill", iconColor: .secondary)
                        }
                         Link(destination: URL(string: "https://www.example.com/privacy")!) {
                            SettingsRowView(title: "Privacy Policy", iconName: "hand.raised.fill", iconColor: .secondary)
                        }
                    }

                    // MARK: - Data Management Section
                    Section {
                        Button(action: {
                            // Show the confirmation alert
                            showingEraseAlert = true
                        }) {
                            HStack {
                                Spacer()
                                Text("Erase Personal Data")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                    
                    // Sign Out Button
                    if authService.user != nil {
                        Section {
                            Button(action: {
                                authService.signOut()
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Sign Out")
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                            }
                        }
                    }

                    #if DEBUG
                    Section(header: Text("🧪 Debug & Testing").font(.system(size: 14, weight: .regular, design: .default))) {
                        Button("Reset All Settings") {
                            settings.resetForTesting()
                            authFlow.resetAuthenticationState()
                        }
                        .foregroundColor(.orange)
                        
                        Button("Simulate New User") {
                            authFlow.simulateNewUser()
                        }
                        .foregroundColor(.blue)
                        
                        Button("Simulate Returning User (Face ID)") {
                            authFlow.simulateReturningUserWithFaceID()
                        }
                        .foregroundColor(.green)
                        
                        Button("Debug Current State") {
                            settings.debugCurrentState()
                            authFlow.debugCurrentState()
                        }
                        .foregroundColor(.purple)
                        
                        Button("Force Flow Re-evaluation") {
                            authFlow.forceFlowReevaluation()
                        }
                        .foregroundColor(.cyan)
                        
                        Button("Force Sign Out") {
                            Task {
                                await authService.signOut()
                            }
                        }
                        .foregroundColor(.red)
                    }
                    #endif
                }
                .sheet(isPresented: $showingAuthSheet) {
                    AuthenticationView()
                        .environmentObject(authService)
                }
                .alert("Are you sure?", isPresented: $showingEraseAlert) {
                    Button("Delete All Data", role: .destructive) {
                        // Perform the erasure
                        DataManager.eraseAllData()
                        
                        // After erasing, you might want to force the app to restart
                        // or navigate to a specific view (e.g., onboarding).
                        // For now, we just dismiss the settings view.
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This action is permanent and cannot be undone. All journal entries, settings, and personal data will be deleted.")
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                        dismiss()
                        }) {
                           Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primaryEspresso)
                        }
                    }
                }
            }
            .onAppear {
                // We can add any necessary on-appear logic here later
            }
        }
    }
    
    // MARK: - Subviews
    
    private var accountView: some View {
        VStack(alignment: .leading, spacing: 4) {
             HStack {
                  // Display user's email if available
                  Text(authService.user?.email ?? "Your Account")
                       .font(.system(size: 17, weight: .semibold, design: .default))
                  Spacer()
                  // TODO: Check premium status from a different service later
                  Image(systemName: "diamond.fill")
                       .foregroundColor(.yellow)
             }
             NavigationLink(destination: Text("Upgrade Plan View")) {
                  Text("Manage Subscription")
                       .font(.system(size: 15))
                       .foregroundColor(.secondary)
                  }
             }
        }

    private var signInView: some View {
         Button(action: {
             showingAuthSheet = true
         }) {
             HStack(spacing: 15) {
                 Image(systemName: "person.fill")
                     .font(.title2)
                     .foregroundColor(.white)
                     .background(Circle().fill(Color.gray).frame(width: 32, height: 32))
                 Text("Sign In")
                      .font(.system(size: 17, weight: .regular, design: .default))
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func copyUserID() {
        let userIDKey = "appUserID"
        var userID = UserDefaults.standard.string(forKey: userIDKey)
        
        if userID == nil {
            let newUserID = UUID().uuidString
            UserDefaults.standard.set(newUserID, forKey: userIDKey)
            userID = newUserID
        }
        
        UIPasteboard.general.string = userID
        
        // Optionally, show a confirmation to the user
        print("User ID copied to clipboard: \(userID ?? "N/A")")
    }
    
    private func openSupportEmail() {
        let email = "support@yourapp.com" // Replace with your support email
        if let url = URL(string: "mailto:\(email)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
}

// MARK: - Reusable Settings Row
struct SettingsRowView: View {
    let title: String
    var subtitle: String? = nil
    let iconName: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 32)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.system(size: 17, weight: .regular, design: .default))
                    .foregroundColor(.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4) // Add some padding for better spacing
    }
}


#Preview {
    SettingsView()
} 