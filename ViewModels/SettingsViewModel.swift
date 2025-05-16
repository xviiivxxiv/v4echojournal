import SwiftUI
import CoreData

class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isNotificationsEnabled = false
    @Published var selectedVoice = "Default"
    @Published var transcriptionLanguage = "English"
    @Published var autoSaveEnabled = true
    @Published var darkModeEnabled = false
    
    // UserDefaults keys
    private let notificationsKey = "isNotificationsEnabled"
    private let voiceKey = "selectedVoice"
    private let languageKey = "transcriptionLanguage"
    private let autoSaveKey = "autoSaveEnabled"
    private let darkModeKey = "darkModeEnabled"
    
    init() {
        // Load saved settings
        loadSettings()
    }
    
    // MARK: - Public Methods
    func toggleNotifications() {
        isNotificationsEnabled.toggle()
        saveSettings()
    }
    
    func setVoice(_ voice: String) {
        selectedVoice = voice
        saveSettings()
    }
    
    func setLanguage(_ language: String) {
        transcriptionLanguage = language
        saveSettings()
    }
    
    func toggleAutoSave() {
        autoSaveEnabled.toggle()
        saveSettings()
    }
    
    func toggleDarkMode() {
        darkModeEnabled.toggle()
        saveSettings()
    }
    
    // MARK: - Private Methods
    private func loadSettings() {
        let defaults = UserDefaults.standard
        isNotificationsEnabled = defaults.bool(forKey: notificationsKey)
        selectedVoice = defaults.string(forKey: voiceKey) ?? "Default"
        transcriptionLanguage = defaults.string(forKey: languageKey) ?? "English"
        autoSaveEnabled = defaults.bool(forKey: autoSaveKey)
        darkModeEnabled = defaults.bool(forKey: darkModeKey)
    }
    
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(isNotificationsEnabled, forKey: notificationsKey)
        defaults.set(selectedVoice, forKey: voiceKey)
        defaults.set(transcriptionLanguage, forKey: languageKey)
        defaults.set(autoSaveEnabled, forKey: autoSaveKey)
        defaults.set(darkModeEnabled, forKey: darkModeKey)
    }
} 