import Foundation

struct JournalEntry: Identifiable, Codable {
    let id: UUID
    var entryText: String
    var audioURL: String // Store the URL string from Supabase Storage
    let createdAt: Date
    let userId: String // To associate entries with users

    // Conformance to Identifiable
    var objectID: UUID { id }

    // Example initializer (adjust as needed)
    init(id: UUID = UUID(), entryText: String, audioURL: String, createdAt: Date = Date(), userId: String) {
        self.id = id
        self.entryText = entryText
        self.audioURL = audioURL
        self.createdAt = createdAt
        self.userId = userId
    }

    // Add Codable conformance if interacting with APIs/persistence that need it
    enum CodingKeys: String, CodingKey {
        case id
        case entryText = "entry_text" // Map to potential database column names
        case audioURL = "audio_url"
        case createdAt = "created_at"
        case userId = "user_id"
    }
} 