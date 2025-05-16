import Foundation
import AVFoundation
import Combine

protocol AudioRecordingService: ObservableObject {
    var isRecordingPublisher: Published<Bool>.Publisher { get }
    var isRecording: Bool { get }
    var recordingURL: URL? { get }
    var recordingLog: [URL] { get }  // ✅ Log of all file paths
    var errorPublisher: PassthroughSubject<Error, Never> { get }
    var audioFileURL: URL? { get }

    func startRecording(fileNameBase: String) async -> Bool
    func stopRecording() async -> URL?
    func deleteRecording()
    func getRecordingData() -> Data?
}

final class AudioRecorder: NSObject, ObservableObject, AudioRecordingService, AVAudioRecorderDelegate {
    static let shared = AudioRecorder()

    @Published private(set) var isRecording = false
    var isRecordingPublisher: Published<Bool>.Publisher { $isRecording }
    @Published var elapsedTime: TimeInterval = 0
    @Published private(set) var audioFileURL: URL? = nil
    @Published var audioPower: Float = 0.0
    
    private var audioRecorder: AVAudioRecorder?
    var recordingURL: URL?
    var recordingLog: [URL] = []

    var errorPublisher = PassthroughSubject<Error, Never>()

    private var recordingSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var timer: Timer?
    private var powerTimer: Timer?

    private override init() {
        super.init()
    }

    // MARK: - File Management Helpers
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    private func getAudioDirectory(subdirectory: String = "Recordings") -> URL {
        let audioDirectory = getDocumentsDirectory().appendingPathComponent(subdirectory)
        do {
            try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true, attributes: nil)
            print("✅ Audio directory created/ensured at: \(audioDirectory.path)")
        } catch {
            print("❌ Failed to create audio directory: \(error)")
        }
        return audioDirectory
    }

    // MARK: - Recording Control

    func startRecording(fileNameBase: String) async -> Bool {
        await MainActor.run { self.isRecording = false }
        print("🎙️ Attempting to start recording...")
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
            print("🎙️ Recording session activated.")

            let audioDirectory = getAudioDirectory(subdirectory: "FutureNotesAudio")
            let targetURL = audioDirectory.appendingPathComponent("\(fileNameBase).m4a")
            self.audioFileURL = targetURL
            print("🎙️ Recording target URL: \(targetURL.path)")

            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: targetURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true

            if audioRecorder?.record() == true {
                print("✅ Recording started successfully.")
                await MainActor.run {
                    self.isRecording = true
                    self.startTimers()
                }
                return true
            } else {
                print("❌ AudioRecorder failed to start recording.")
                await MainActor.run { self.cleanupAfterRecording() }
                return false
            }
        } catch {
            print("❌ Failed to set up recording session or recorder: \(error)")
            await MainActor.run { self.cleanupAfterRecording() }
            return false
        }
    }

    func stopRecording() async -> URL? {
        print("🎙️ Stopping recording...")
        audioRecorder?.stop()
        await MainActor.run {
            cleanupAfterRecording()
        }
        return audioFileURL
    }

    private func startTimers() {
        stopTimers()
        
        self.elapsedTime = 0
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecording else { return }
            self.elapsedTime += 0.1
        }
        
        self.powerTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
             guard let self = self, let recorder = self.audioRecorder, self.isRecording else { return }
             recorder.updateMeters()
             let normalizedPower = max(0, (recorder.averagePower(forChannel: 0) + 60) / 60)
             self.audioPower = normalizedPower
        }
    }

    private func stopTimers() {
        timer?.invalidate()
        timer = nil
        powerTimer?.invalidate()
        powerTimer = nil
        self.audioPower = 0.0
    }

    private func cleanupAfterRecording() {
        print("🧹 Cleaning up recording resources...")
        stopTimers()
        isRecording = false
        audioRecorder = nil
    }
    
    func deleteRecording() {
        guard let url = audioFileURL else {
             print("🗑️ No recording file URL found to delete.")
             return
        }
        print("🗑️ Attempting to delete recording at: \(url.path)")
        do {
            try FileManager.default.removeItem(at: url)
            print("✅ Recording deleted successfully.")
            self.audioFileURL = nil
        } catch {
            print("❌ Failed to delete recording file: \(error)")
        }
        Task { await MainActor.run { self.cleanupAfterRecording() } }
    }

    // MARK: - Support Helpers

    func getRecordingData() -> Data? {
        guard let url = recordingURL else { return nil }
        do {
            return try Data(contentsOf: url)
        } catch {
            errorPublisher.send(error)
            return nil
        }
    }

    // MARK: - AVAudioRecorderDelegate

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("🎙️ Delegate: audioRecorderDidFinishRecording (Success: \(flag))")
        Task {
            await MainActor.run {
                self.cleanupAfterRecording()
                if !flag {
                    print("❌ Recording finished unsuccessfully.")
                    self.audioFileURL = nil
                }
            }
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("❌ Delegate: audioRecorderEncodeErrorDidOccur: \(error?.localizedDescription ?? "Unknown error")")
        Task {
            await MainActor.run {
                self.cleanupAfterRecording()
                self.audioFileURL = nil
            }
        }
    }
}

