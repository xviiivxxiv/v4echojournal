import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Onboarding Data Structure
struct OnboardingData: Codable {
    var userName: String?
    var userAge: Int?
    
    // Updated fields for new flow
    var selectedGoal: String?
    var selectedTone: String?
    
    // Deprecated - will be replaced by goal/tone
    var selectedIntention: String? 
    
    var reminderSettings: ReminderSettings?
    var reflectionTranscript: String?
    var reflectionFollowUp: String?
    
    struct ReminderSettings: Codable {
        var isEnabled: Bool
        var time: Date?
    }
}

// MARK: - Onboarding Persistence Manager
class OnboardingPersistenceManager {
    private let userDefaults = UserDefaults.standard
    private let keyPrefix = "onboarding_"
    
    // Keys
    private let currentStateKey = "onboarding_current_state"
    private let temporaryDataKey = "onboarding_temporary_data"
    private let subscriptionActiveKey = "onboarding_subscription_active"
    private let lastValidStateKey = "onboarding_last_valid_state"
    private let acceptedTandCKey = "onboarding_accepted_tandc"

    // MARK: - State Persistence
    
    func saveState(_ state: AppState, context: [String: Any] = [:]) {
        print("💾 Saving state: \(state.description)")
        
        // Save current state
        userDefaults.set(state.rawValue, forKey: currentStateKey)
        
        // Save as last valid state (for recovery)
        userDefaults.set(state.rawValue, forKey: lastValidStateKey)
        
        // Save any context data
        if !context.isEmpty {
            saveTemporaryData(context)
        }
        
        userDefaults.synchronize()
    }
    
    func getPersistedState() -> AppState? {
        guard let rawValue = userDefaults.string(forKey: currentStateKey),
              let state = AppState(rawValue: rawValue) else {
            return nil
        }
        return state
    }
    
    func getLastValidState() -> AppState? {
        guard let rawValue = userDefaults.string(forKey: lastValidStateKey),
              let state = AppState(rawValue: rawValue) else {
            return nil
        }
        return state
    }
    
    // MARK: - T&C Management
    
    func markTandCAccepted() {
        print("💾 Marking T&Cs as accepted")
        userDefaults.set(true, forKey: acceptedTandCKey)
        userDefaults.synchronize()
    }
    
    func getHasAcceptedTandC() -> Bool {
        return userDefaults.bool(forKey: acceptedTandCKey)
    }
    
    // MARK: - Temporary Data Management
    
    func saveTemporaryData(_ data: [String: Any]) {
        print("💾 Saving temporary data: \(data.keys)")
        
        // Get existing data
        var existingData = getTemporaryData()
        
        // Merge with new data
        for (key, value) in data {
            existingData[key] = value
        }
        
        // Save back
        if let encodedData = try? JSONSerialization.data(withJSONObject: existingData) {
            userDefaults.set(encodedData, forKey: temporaryDataKey)
            userDefaults.synchronize()
        }
    }
    
    func getTemporaryData() -> [String: Any] {
        guard let data = userDefaults.data(forKey: temporaryDataKey),
              let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return decoded
    }
    
    func saveOnboardingData(_ onboardingData: OnboardingData) {
        print("💾 Saving structured onboarding data")
        
        let data: [String: Any] = [
            "userName": onboardingData.userName ?? "",
            "userAge": onboardingData.userAge ?? 0,
            "selectedGoal": onboardingData.selectedGoal ?? "",
            "selectedTone": onboardingData.selectedTone ?? "",
            "selectedIntention": onboardingData.selectedIntention ?? "", // Legacy
            "reminderEnabled": onboardingData.reminderSettings?.isEnabled ?? false,
            "reminderTime": onboardingData.reminderSettings?.time?.timeIntervalSince1970 ?? 0,
            "reflectionTranscript": onboardingData.reflectionTranscript ?? "",
            "reflectionFollowUp": onboardingData.reflectionFollowUp ?? ""
        ]
        
        saveTemporaryData(data)
    }
    
    func getOnboardingData() -> OnboardingData {
        let tempData = getTemporaryData()
        
        let reminderTime = tempData["reminderTime"] as? TimeInterval
        let reminderSettings = OnboardingData.ReminderSettings(
            isEnabled: tempData["reminderEnabled"] as? Bool ?? false,
            time: reminderTime != nil && reminderTime! > 0 ? Date(timeIntervalSince1970: reminderTime!) : nil
        )
        
        return OnboardingData(
            userName: tempData["userName"] as? String,
            userAge: tempData["userAge"] as? Int,
            selectedGoal: tempData["selectedGoal"] as? String,
            selectedTone: tempData["selectedTone"] as? String,
            selectedIntention: tempData["selectedIntention"] as? String, // Legacy
            reminderSettings: reminderSettings,
            reflectionTranscript: tempData["reflectionTranscript"] as? String,
            reflectionFollowUp: tempData["reflectionFollowUp"] as? String
        )
    }
    
    // MARK: - Subscription Management
    
    func markSubscriptionActive() {
        print("💾 Marking subscription as active")
        userDefaults.set(true, forKey: subscriptionActiveKey)
        userDefaults.set(Date().timeIntervalSince1970, forKey: "\(subscriptionActiveKey)_timestamp")
        userDefaults.synchronize()
    }
    
    func hasActiveSubscription() -> Bool {
        return userDefaults.bool(forKey: subscriptionActiveKey)
    }
    
    func getSubscriptionTimestamp() -> Date? {
        let timestamp = userDefaults.double(forKey: "\(subscriptionActiveKey)_timestamp")
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }
    
    // MARK: - Firebase Integration
    
    func commitTemporaryDataToFirebase() {
        print("🔥 Committing temporary data to Firebase")
        
        guard let user = Auth.auth().currentUser else {
            print("❌ No Firebase user - cannot commit data")
            return
        }
        
        let onboardingData = getOnboardingData()
        let db = Firestore.firestore()
        
        // Prepare user profile data
        var userData: [String: Any] = [
            "createdAt": FieldValue.serverTimestamp(),
            "lastUpdated": FieldValue.serverTimestamp()
        ]
        
        if let userName = onboardingData.userName, !userName.isEmpty {
            userData["displayName"] = userName
        }
        
        if let userAge = onboardingData.userAge, userAge > 0 {
            userData["age"] = userAge
        }
        
        if let selectedTone = onboardingData.selectedTone, !selectedTone.isEmpty {
            userData["preferredTone"] = selectedTone
        }
        
        if let selectedIntention = onboardingData.selectedIntention, !selectedIntention.isEmpty {
            userData["preferredIntention"] = selectedIntention
        }
        
        if let reminderSettings = onboardingData.reminderSettings {
            userData["reminderEnabled"] = reminderSettings.isEnabled
            if let reminderTime = reminderSettings.time {
                userData["reminderTime"] = Timestamp(date: reminderTime)
            }
        }
        
        // Save to Firestore
        db.collection("users").document(user.uid).setData(userData, merge: true) { error in
            if let error = error {
                print("❌ Error saving user data to Firebase: \(error.localizedDescription)")
            } else {
                print("✅ User data successfully saved to Firebase")
                
                // Save reflection data if available
                self.saveReflectionDataToFirebase(onboardingData)
            }
        }
    }
    
    private func saveReflectionDataToFirebase(_ onboardingData: OnboardingData) {
        guard let user = Auth.auth().currentUser,
              let transcript = onboardingData.reflectionTranscript,
              !transcript.isEmpty else {
            return
        }
        
        let db = Firestore.firestore()
        
        let reflectionData: [String: Any] = [
            "transcript": transcript,
            "followUpQuestion": onboardingData.reflectionFollowUp ?? "",
            "createdAt": FieldValue.serverTimestamp(),
            "isOnboardingReflection": true
        ]
        
        db.collection("users").document(user.uid)
            .collection("reflections").addDocument(data: reflectionData) { error in
            if let error = error {
                print("❌ Error saving reflection to Firebase: \(error.localizedDescription)")
            } else {
                print("✅ Onboarding reflection saved to Firebase")
            }
        }
    }
    
    // MARK: - Data Cleanup
    
    func clearTemporaryData() {
        print("🧹 Clearing temporary onboarding data")
        userDefaults.removeObject(forKey: temporaryDataKey)
        userDefaults.synchronize()
    }
    
    func clearAllData() {
        print("🧹 Clearing all onboarding persistence data")
        
        let keysToRemove = [
            currentStateKey,
            temporaryDataKey,
            subscriptionActiveKey,
            "\(subscriptionActiveKey)_timestamp",
            lastValidStateKey,
            acceptedTandCKey
        ]
        
        for key in keysToRemove {
            userDefaults.removeObject(forKey: key)
        }
        
        userDefaults.synchronize()
    }
    
    // MARK: - Debug Methods
    
    func debugCurrentData() {
        print("💾 OnboardingPersistenceManager Debug:")
        print("   - Current State: \(getPersistedState()?.description ?? "none")")
        print("   - Last Valid State: \(getLastValidState()?.description ?? "none")")
        print("   - Has Active Subscription: \(hasActiveSubscription())")
        print("   - Has T&Cs been accepted: \(getHasAcceptedTandC())")
        print("   - Subscription Timestamp: \(getSubscriptionTimestamp()?.description ?? "none")")
        
        let tempData = getTemporaryData()
        print("   - Temporary Data Keys: \(tempData.keys.sorted())")
        
        let onboardingData = getOnboardingData()
        print("   - User Name: \(onboardingData.userName ?? "none")")
        print("   - User Age: \(onboardingData.userAge?.description ?? "none")")
        print("   - Selected Goal: \(onboardingData.selectedGoal ?? "none")")
        print("   - Selected Tone: \(onboardingData.selectedTone ?? "none")")
        print("   - Selected Intention (Legacy): \(onboardingData.selectedIntention ?? "none")")
    }
} 