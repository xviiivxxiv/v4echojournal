import Foundation
import AVFoundation
import Combine

protocol AudioRecordingService {
    var isRecording: CurrentValueSubject<Bool, Never> { get }
    var recordingURL: URL? { get }
    var recordingLog: [URL] { get }  // ✅ Log of all file paths
    var errorPublisher: PassthroughSubject<Error, Never> { get }

    func startRecording() async throws -> URL
    func stopRecording() async throws -> URL
    func getRecordingData() -> Data?
}

final class AudioRecorder: NSObject, ObservableObject, AudioRecordingService, AVAudioRecorderDelegate {
    static let shared = AudioRecorder()

    private var audioRecorder: AVAudioRecorder?
    var recordingURL: URL?
    var recordingLog: [URL] = []

    var isRecording = CurrentValueSubject<Bool, Never>(false)
    var errorPublisher = PassthroughSubject<Error, Never>()

    private override init() {
        super.init()
    }

    // MARK: - Async Recording Functions

    func startRecording() async throws -> URL {
        try configureAudioSession()
        try await requestMicrophonePermission()

        let filename = getDocumentsDirectory().appendingPathComponent("recording-\(UUID().uuidString).m4a")
        recordingURL = filename

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: filename, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.prepareToRecord()

        if audioRecorder?.record() == true {
            isRecording.send(true)
            recordingLog.append(filename) // ✅ Log file
            print("🎙️ Recording started at: \(filename)")
            return filename
        } else {
            throw NSError(domain: "AudioRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Recording failed to start"])
        }
    }

    func stopRecording() async throws -> URL {
        guard let recorder = audioRecorder, let url = recordingURL else {
            throw NSError(domain: "AudioRecorder", code: 3, userInfo: [NSLocalizedDescriptionKey: "No recording in progress"])
        }

        recorder.stop()
        isRecording.send(false)
        print("🛑 Recording stopped")

        try await Task.sleep(nanoseconds: 300_000_000) // Ensure file finalizes

        return url
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

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
    }

    private func requestMicrophonePermission() async throws {
        let session = AVAudioSession.sharedInstance()

        if #available(iOS 17, *) {
            let granted = await AVAudioApplication.requestRecordPermission()
            guard granted else {
                throw NSError(domain: "Microphone", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mic access denied"])
            }
        } else {
            switch session.recordPermission {
            case .granted:
                return
            case .denied:
                throw NSError(domain: "Microphone", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mic access denied"])
            case .undetermined:
                var granted = false
                let semaphore = DispatchSemaphore(value: 0)
                session.requestRecordPermission {
                    granted = $0
                    semaphore.signal()
                }
                semaphore.wait()
                guard granted else {
                    throw NSError(domain: "Microphone", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mic access denied"])
                }
            @unknown default:
                throw NSError(domain: "Microphone", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mic permission unknown"])
            }
        }
    }

    // MARK: - AVAudioRecorderDelegate

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        isRecording.send(false)
        if !flag {
            print("⚠️ [AudioRecorder] Recording stopped prematurely.")
        }
        if audioRecorder === recorder {
            audioRecorder = nil
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        isRecording.send(false)
        if let error = error {
            errorPublisher.send(error)
        }
        if audioRecorder === recorder {
            audioRecorder = nil
        }
    }
}

