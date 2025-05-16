import SwiftUI
import UserNotifications // Import UserNotifications framework

struct SettingsView: View {
    // Use AppStorage to persist settings
    @AppStorage("selectedAIResponseTone") private var selectedTone: String = "Supportive" // Default
    @AppStorage("isFaceIDEnabled") private var isFaceIDEnabled: Bool = false
    @AppStorage("reminderTime") private var reminderTime: Date = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    @AppStorage("areRemindersEnabled") private var areRemindersEnabled: Bool = false
    
    @Environment(\.dismiss) private var dismiss

    let availableTones = ["Supportive", "Curious", "Neutral", "Direct"]
    
    // State to disable date picker if permission denied
    @State private var notificationPermissionGranted = false

    var body: some View {
        NavigationView { // Embed in NavigationView for Title and potential toolbar items
            ZStack {
                Color.backgroundCream.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 20) {
                    
                    // Tone Selector Section
                    Text("AI Response Tone")
                        .font(.system(size: 20, weight: .medium, design: .default)) // SF Pro
                        .foregroundColor(.primaryEspresso)
                    Picker("Response Tone", selection: $selectedTone) {
                        ForEach(availableTones, id: \.self) { tone in
                            Text(tone).font(.system(size: 16, weight: .regular, design: .default)) // SF Pro
                        }
                    }
                    .pickerStyle(.segmented) // Or .menu
                    .background(Color.accentPaleGrey.opacity(0.5))
                    .cornerRadius(8)
                    .tint(Color.buttonBrown) // Color for the selected segment
                    
                    Divider()
                    
                    // Face ID Toggle Section
                    Toggle(isOn: $isFaceIDEnabled) {
                        Text("Enable Face ID / Touch ID")
                            .font(.system(size: 17, weight: .regular, design: .default)) // SF Pro
                            .foregroundColor(.primaryEspresso)
                    }
                    .tint(Color.buttonBrown) // Color for the toggle switch
                    
                    Divider()
                    
                    // Reminder Section
                    Text("Daily Reminder")
                         .font(.system(size: 20, weight: .medium, design: .default)) // SF Pro
                         .foregroundColor(.primaryEspresso)
                    
                    Toggle(isOn: $areRemindersEnabled.animation()) {
                        Text("Enable Reminders")
                            .font(.system(size: 17, weight: .regular, design: .default)) // SF Pro
                            .foregroundColor(.primaryEspresso)
                    }
                    .tint(Color.buttonBrown)
                    .onChange(of: areRemindersEnabled) { _, enabled in
                         if enabled {
                              // Request permission when toggle is turned on
                              requestNotificationPermission { granted in
                                   notificationPermissionGranted = granted
                                   if granted {
                                        scheduleNotification()
                                   } else {
                                        // If permission denied, turn toggle back off
                                        areRemindersEnabled = false
                                        // Optionally show an alert guiding user to settings
                                   }
                              }
                         } else {
                              cancelNotifications()
                         }
                    }
                    
                    if areRemindersEnabled && notificationPermissionGranted {
                        DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .font(.system(size: 16, weight: .regular, design: .default)) // SF Pro
                            .foregroundColor(.primaryEspresso)
                            .tint(Color.buttonBrown)
                            .onChange(of: reminderTime) { _, _ in scheduleNotification() }
                    } else if areRemindersEnabled && !notificationPermissionGranted {
                         // Show if toggle is on but permission was denied
                         Text("Please enable notification permissions in the Settings app.")
                              .font(.system(size: 14, weight: .regular, design: .default)) // SF Pro
                              .foregroundColor(.secondaryTaupe)
                    }

                    Spacer() // Push content to top
                }
                .padding()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { // Changed to leading
                    Button("Close") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium, design: .rounded)) // SF Pro Rounded
                    .foregroundColor(.buttonBrown)
                }
            }
            .onAppear(perform: checkNotificationPermission) // Check permission status on appear
        }
    }
    
    // MARK: - Notification Logic
    
    private var notificationCenter: UNUserNotificationCenter {
         UNUserNotificationCenter.current()
    }
    private let notificationIdentifier = "dailyReflectionReminder"

    // Check current permission status
    func checkNotificationPermission() {
        notificationCenter.getNotificationSettings { settings in
             DispatchQueue.main.async {
                  notificationPermissionGranted = (settings.authorizationStatus == .authorized)
                  // If permission granted but toggle is off, do nothing.
                  // If permission not granted but toggle *was* on, turn it off.
                  if !notificationPermissionGranted && areRemindersEnabled {
                       areRemindersEnabled = false
                  }
             }
        }
    }

    // Request permission (callback indicates success/failure)
    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Notification permission error: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("Notification permission granted: \(granted)")
                    completion(granted)
                }
            }
        }
    }
    
    // Schedule the daily notification
    func scheduleNotification() {
        // Ensure toggle is on and permission granted
        guard areRemindersEnabled, notificationPermissionGranted else { 
             print("Cannot schedule notification: Reminders disabled or permission not granted.")
             return
         }

        // Content
        let content = UNMutableNotificationContent()
        content.title = "Time to Reflect"
        content.body = "Take a moment for yourself with Heard."
        content.sound = .default

        // Trigger (Daily at user-specified time)
        let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        // Request
        let request = UNNotificationRequest(identifier: notificationIdentifier,
                                            content: content,
                                            trigger: trigger)

        // Remove old before adding new
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        
        // Add Request
        notificationCenter.add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error scheduling notification: \(error.localizedDescription)")
                    // Optionally show an error to the user?
                } else {
                    print("Daily reminder scheduled successfully for \(dateComponents.hour ?? -1):\(dateComponents.minute ?? -1)")
                }
            }
        }
    }
    
    // Cancel pending notifications
    func cancelNotifications() {
        print("Cancelling pending daily reminders...")
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    }
}

#Preview {
    SettingsView()
} 