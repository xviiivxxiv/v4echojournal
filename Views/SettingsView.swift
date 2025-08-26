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
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {  // Natural section spacing
                // Custom header - now scrolls with content
                settingsHeaderView
                
                // Account Section
                accountSectionView
                
                // General Section
                generalSectionView
                
                // Security Section
                securitySectionView
                
                // Support Section
                supportSectionView
                
                // Legal Section
                legalSectionView
                
                // Data Management Section
                dataManagementSectionView
                
                // Sign Out Section
                if authService.user != nil {
                    signOutSectionView
                }
                
                #if DEBUG
                debugSectionView
                #endif
                
                // Bottom padding
                Color.clear.frame(height: 50)
            }
            .padding(.top, 35) // Closer to status bar while maintaining safe spacing
        }
        .background(Color.secondaryTaupe.ignoresSafeArea())
        .navigationBarHidden(true)
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
        .onAppear {
            // We can add any necessary on-appear logic here later
        }


    }
    
    // MARK: - Section Views
    
    private var settingsHeaderView: some View {
        ZStack {
            // Back button positioned to leading edge
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.buttonBrown)
                }
                Spacer()
            }
            .padding(.horizontal)
            
            // Settings text centered independently
            Text("Settings")
                .font(.custom("GentyDemo-Regular", size: 34))
                .foregroundColor(.buttonBrown)
        }
    }
    
    private var accountSectionView: some View {
        SettingsSection {
            SettingsRowWrapper {
                if authService.user != nil {
                    accountView
                } else {
                    signInView
                }
            }
        }
    }
    
    private var generalSectionView: some View {
        SettingsSection(header: "GENERAL") {
            Group {
                SettingsRowWrapper {
                    NavigationLink(destination: NotificationSettingsView()) {
                        SettingsRowView(title: "Notifications", iconName: "bell.fill", iconColor: .yellow)
                    }
                }
                
                SettingsRowWrapper {
                    NavigationLink(destination: EditNameView()) {
                        SettingsRowView(title: "Edit Name", iconName: "pencil", iconColor: .orange)
                    }
                }
                
                SettingsRowWrapper(showDivider: false) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        Link(destination: url) {
                            SettingsRowView(title: "Language", iconName: "globe", iconColor: .blue)
                        }
                    }
                }
            }
        }
    }
    
    private var securitySectionView: some View {
        SettingsSection(header: "SECURITY") {
            Group {
                SettingsRowWrapper {
                    NavigationLink(destination: PasscodeSettingsView()) {
                        SettingsRowView(title: "Passcode & Face ID", iconName: "lock.shield.fill", iconColor: .green)
                    }
                }
                
                SettingsRowWrapper(showDivider: false) {
                    Toggle(isOn: $settings.stayLoggedIn) {
                        SettingsRowView(title: "Stay Logged In", subtitle: settings.stayLoggedIn ? "On" : "Off", iconName: "person.badge.key.fill", iconColor: .blue)
                    }
                    .tint(Color.buttonBrown)
                }
            }
        }
    }
    
    private var supportSectionView: some View {
        SettingsSection(header: "SUPPORT") {
            Group {
                SettingsRowWrapper {
                    Button(action: openSupportEmail) {
                        SettingsRowView(title: "Contact Support", iconName: "bubble.left.and.bubble.right.fill", iconColor: .gray)
                    }
                }
                
                SettingsRowWrapper(showDivider: false) {
                    Button(action: copyUserID) {
                        SettingsRowView(title: "Copy My ID", iconName: "doc.on.doc.fill", iconColor: .purple)
                    }
                }
            }
        }
    }
    
    private var legalSectionView: some View {
        SettingsSection {
            Group {
                SettingsRowWrapper {
                    Link(destination: URL(string: "https://www.example.com/terms")!) {
                        SettingsRowView(title: "Terms of Use", iconName: "doc.text.fill", iconColor: .buttonBrown)
                    }
                }
                
                SettingsRowWrapper(showDivider: false) {
                    Link(destination: URL(string: "https://www.example.com/privacy")!) {
                        SettingsRowView(title: "Privacy Policy", iconName: "hand.raised.fill", iconColor: .buttonBrown)
                    }
                }
            }
        }
    }
    
    private var dataManagementSectionView: some View {
        SettingsSection {
            SettingsRowWrapper(showDivider: false) {
                Button(action: {
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
        }
    }
    
    private var signOutSectionView: some View {
        SettingsSection {
            SettingsRowWrapper(showDivider: false) {
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
    }
    
    #if DEBUG
    private var debugSectionView: some View {
        SettingsSection(header: "🧪 DEBUG & TESTING") {
            Group {
                SettingsRowWrapper {
                    Button("Reset All Settings") {
                        settings.resetForTesting()
                        authFlow.resetAuthenticationState()
                    }
                    .foregroundColor(.orange)
                }
                
                SettingsRowWrapper {
                    Button("Simulate New User") {
                        authFlow.simulateNewUser()
                    }
                    .foregroundColor(.blue)
                }
                
                SettingsRowWrapper {
                    Button("Simulate Returning User (Face ID)") {
                        authFlow.simulateReturningUserWithFaceID()
                    }
                    .foregroundColor(.green)
                }
                
                SettingsRowWrapper {
                    Button("Debug Current State") {
                        settings.debugCurrentState()
                        authFlow.debugCurrentState()
                    }
                    .foregroundColor(.purple)
                }
                
                SettingsRowWrapper {
                    Button("Force Flow Re-evaluation") {
                        authFlow.forceFlowReevaluation()
                    }
                    .foregroundColor(.cyan)
                }
                
                SettingsRowWrapper(showDivider: false) {
                    Button("Force Sign Out") {
                        Task {
                            await authService.signOut()
                        }
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
    #endif
    
    // MARK: - Subviews
    
    private var accountView: some View {
        VStack(alignment: .leading, spacing: 4) {
             HStack {
                  // Display user's email if available
                  Text(authService.user?.email ?? "Your Account")
                       .font(.system(size: 17, weight: .semibold, design: .default))
                       .foregroundColor(.buttonBrown)
                  Spacer()
                  // Keep diamond icon as yellow for premium indication
                  Image(systemName: "diamond.fill")
                       .foregroundColor(.yellow)
             }
             NavigationLink(destination: Text("Upgrade Plan View")) {
                  Text("Manage Subscription")
                       .font(.system(size: 15))
                       .foregroundColor(.buttonBrown.opacity(0.7))
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
                     .background(Circle().fill(Color.buttonBrown).frame(width: 32, height: 32))
                 Text("Sign In")
                      .font(.system(size: 17, weight: .regular, design: .default))
                      .foregroundColor(.buttonBrown)
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

// MARK: - Custom Settings Section
struct SettingsSection<Content: View>: View {
    let header: String?
    let content: Content
    
    init(header: String? = nil, @ViewBuilder content: () -> Content) {
        self.header = header
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let header = header {
                Text(header)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(.buttonBrown)
                    .textCase(.uppercase)
                    .padding(.horizontal)
                    .padding(.bottom, 6)
            }
            
            VStack(spacing: 0) {
                content
            }
            .background(Color.heardCreamBoxes)
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
}

// MARK: - Settings Row Wrapper for proper styling
struct SettingsRowWrapper<Content: View>: View {
    let content: Content
    let showDivider: Bool
    
    init(showDivider: Bool = true, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.showDivider = showDivider
    }
    
    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 44)  // Standard iOS minimum tap target
            
            if showDivider {
                Divider()
                    .background(Color.buttonBrown.opacity(0.2))
                    .padding(.leading, 60)
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
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 17, weight: .regular, design: .default))
                    .foregroundColor(.buttonBrown)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(.buttonBrown.opacity(0.7))
                }
            }
            
            Spacer()
        }
    }
}


#Preview {
    SettingsView()
} 