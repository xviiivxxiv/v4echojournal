import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    // MARK: - Properties
    
    @AppStorage("areRemindersEnabled") private var areRemindersEnabled: Bool = false
    @AppStorage("reminderTime") private var reminderTime: Date = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    
    @State private var notificationPermissionGranted = false
    
    // MARK: - Body
    
    var body: some View {
        Form {
            Section(header: Text("Daily Reminder"), footer: Text("Set a time to be reminded to reflect each day.")) {
                Toggle("Enable Reminders", isOn: $areRemindersEnabled.animation())
                    .tint(Color.buttonBrown)
                    .onChange(of: areRemindersEnabled) { _, enabled in
                        handleReminderToggle(enabled: enabled)
                    }

                if areRemindersEnabled {
                    if notificationPermissionGranted {
                        DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .onChange(of: reminderTime) { _, _ in scheduleNotification() }
                    } else {
                        // Guide user to enable notifications in settings
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            Link("Enable notifications in Settings to set a reminder time.", destination: url)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: checkNotificationPermission)
    }
    
    // MARK: - Notification Logic
    
    private var notificationCenter: UNUserNotificationCenter {
        UNUserNotificationCenter.current()
    }
    private let notificationIdentifier = "dailyReflectionReminder"
    
    private func handleReminderToggle(enabled: Bool) {
        if enabled {
            requestNotificationPermission { granted in
                notificationPermissionGranted = granted
                if granted {
                    scheduleNotification()
                } else {
                    areRemindersEnabled = false
                }
            }
        } else {
            cancelNotifications()
        }
    }

    private func checkNotificationPermission() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationPermissionGranted = (settings.authorizationStatus == .authorized)
                if !notificationPermissionGranted && areRemindersEnabled {
                    areRemindersEnabled = false
                }
            }
        }
    }

    private func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
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
    
    private func scheduleNotification() {
        guard areRemindersEnabled, notificationPermissionGranted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to Reflect"
        content.body = "Take a moment for yourself with Heard."
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Daily reminder scheduled successfully for \(dateComponents.hour ?? -1):\(dateComponents.minute ?? -1)")
            }
        }
    }
    
    private func cancelNotifications() {
        print("Cancelling pending daily reminders...")
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    }
}

#Preview {
    NavigationView {
        NotificationSettingsView()
    }
} 