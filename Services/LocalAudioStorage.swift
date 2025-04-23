import Foundation

// Protocol for local audio file operations
protocol AudioStorageService {
    func saveAudio(data: Data, filename: String) throws -> URL
    func deleteAudio(at url: URL) throws
    func getAudioURL(filename: String) -> URL?
}

class LocalAudioStorage: AudioStorageService {

    private let fileManager = FileManager.default
    private let documentsDirectory: URL

    enum StorageError: Error {
        case directoryCreationFailed
        case writeFailed(Error)
        case deleteFailed(Error)
        case fileNotFound
    }

    init() {
        // Get the app's documents directory URL
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            // This should realistically never fail on iOS
            fatalError("Could not access Documents directory.")
        }
        documentsDirectory = url
        print("LocalAudioStorage initialized. Documents directory: \(documentsDirectory.path)")
        // Optional: Create a subdirectory specifically for audio if desired
        // let audioDirectory = documentsDirectory.appendingPathComponent("JournalAudio")
        // if !fileManager.fileExists(atPath: audioDirectory.path) { ... create directory ... }
    }

    /// Saves audio data to a file in the app's Documents directory.
    /// - Parameters:
    ///   - data: The audio data to save.
    ///   - filename: The desired filename (e.g., "<UUID>.m4a"). The '.m4a' extension will be added if missing.
    /// - Returns: The file URL where the data was saved.
    /// - Throws: A StorageError if saving fails.
    func saveAudio(data: Data, filename: String) throws -> URL {
        // Ensure filename has the correct extension
        let correctedFilename = filename.hasSuffix(".m4a") ? filename : "\(filename).m4a"
        let fileURL = documentsDirectory.appendingPathComponent(correctedFilename)

        do {
            // Write the data to the file URL. Use .atomic to ensure integrity.
            try data.write(to: fileURL, options: .atomic)
            print("Audio saved successfully to: \(fileURL.path)")
            return fileURL
        } catch {
            print("Error saving audio file \(filename): \(error.localizedDescription)")
            throw StorageError.writeFailed(error)
        }
    }

    /// Deletes the audio file at the specified URL.
    /// - Parameter url: The file URL of the audio file to delete.
    /// - Throws: A StorageError if deletion fails.
    func deleteAudio(at url: URL) throws {
        // Check if the file exists before attempting deletion
        guard fileManager.fileExists(atPath: url.path) else {
            print("Audio file not found for deletion at: \(url.path)")
            // Depending on requirements, you might ignore this or throw fileNotFound
            // throw StorageError.fileNotFound
            return // File doesn't exist, nothing to delete
        }

        do {
            try fileManager.removeItem(at: url)
            print("Audio file deleted successfully from: \(url.path)")
        } catch {
            print("Error deleting audio file at \(url.path): \(error.localizedDescription)")
            throw StorageError.deleteFailed(error)
        }
    }
    
    /// Gets the full URL for a given filename within the Documents directory.
    /// Checks if the file actually exists.
    /// - Parameter filename: The filename (e.g., "<UUID>.m4a").
    /// - Returns: The file URL if the file exists, otherwise nil.
    func getAudioURL(filename: String) -> URL? {
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        // Check if the file exists at the constructed path
        if fileManager.fileExists(atPath: fileURL.path) {
            return fileURL
        } else {
            print("Audio file not found at expected path: \(fileURL.path)")
            return nil
        }
    }
} 