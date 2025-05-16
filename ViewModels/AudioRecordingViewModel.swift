import SwiftUI
import AVFoundation

class AudioRecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var audioFileURL: URL?
    @Published var error: Error?
    
    private var audioRecorder: AVAudioRecorder?
    private let audioSession = AVAudioSession.sharedInstance()
    
    init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            self.error = error
            print("❌ Failed to set up audio session: \(error)")
        }
    }
    
    func startRecording(fileNameBase: String? = nil) async -> Bool {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = fileNameBase ?? UUID().uuidString
        let audioFilename = documentsPath.appendingPathComponent("\(filename).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            
            await MainActor.run {
                self.isRecording = true
                self.audioFileURL = audioFilename
            }
            
            return true
        } catch {
            await MainActor.run {
                self.error = error
            }
            print("❌ Failed to start recording: \(error)")
            return false
        }
    }
    
    func stopRecording() async -> URL? {
        audioRecorder?.stop()
        
        await MainActor.run {
            self.isRecording = false
        }
        
        return audioFileURL
    }
    
    func deleteRecording() {
        guard let url = audioFileURL else { return }
        
        do {
            try FileManager.default.removeItem(at: url)
            audioFileURL = nil
        } catch {
            print("❌ Failed to delete recording: \(error)")
            self.error = error
        }
    }
} 