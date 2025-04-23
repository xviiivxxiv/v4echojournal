import Foundation
import AVFoundation
import Combine

protocol AudioRecordingService {
    var isRecording: CurrentValueSubject<Bool, Never> { get }
    var recordingURL: URL? { get }
    var errorPublisher: PassthroughSubject<Error, Never> { get }

    func startRecording()
    func stopRecording()
    func getRecordingData() -> Data?
}

final class AudioRecorder: NSObject, ObservableObject, AudioRecordingService, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    var recordingURL: URL?

    var isRecording = CurrentValueSubject<Bool, Never>(false)
    var errorPublisher = PassthroughSubject<Error, Never>()

    override init() {
        super.init()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            print("✅ Audio session configured")
        } catch {
            print("❌ Audio session error: \(error.localizedDescription)")
            errorPublisher.send(error)
        }
    }

    func startRecording() {
        configureAudioSession()

        requestMicrophonePermission { [weak self] granted in
            guard let self = self else { return }

            if !granted {
                print("❌ Mic permission denied or not granted")
                self.errorPublisher.send(
                    NSError(domain: "Microphone", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mic access denied"])
                )
                return
            }

            do {
                let filename = self.getDocumentsDirectory().appendingPathComponent("recording-\(UUID().uuidString).m4a")
                self.recordingURL = filename

                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 12000,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]

                self.audioRecorder = try AVAudioRecorder(url: filename, settings: settings)
                self.audioRecorder?.delegate = self
                self.audioRecorder?.prepareToRecord()

                if self.audioRecorder?.record() == true {
                    self.isRecording.send(true)
                    print("🎙️ Recording started at: \(filename)")
                } else {
                    throw NSError(domain: "AudioRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Recording failed to start."])
                }

            } catch {
                print("❌ Recording error: \(error.localizedDescription)")
                self.isRecording.send(false)
                self.errorPublisher.send(error)
            }
        }
    }

    func stopRecording() {
        print("🛑 [AudioRecorder] Entering stopRecording() - Current isRecording: \(isRecording.value)")

        guard let recorder = audioRecorder else {
            print("⚠️ [AudioRecorder] audioRecorder is nil, cannot stop. Forcing isRecording to false.")
            isRecording.send(false)
            return
        }

        print("▶️ [AudioRecorder] About to call recorder.stop()")
        recorder.stop()
        print("⏹️ [AudioRecorder] recorder.stop() called.")

        // Setting audioRecorder to nil might prevent delegate methods from being called reliably
        // Let's see if the delegate handles setting isRecording to false.
        // audioRecorder = nil // Temporarily commented out for debugging

        // Let's monitor if the delegate is called. If not, we might need to uncomment the line below.
        // print("⏳ [AudioRecorder] Manually sending isRecording false BEFORE delegate call (for testing)")
        // isRecording.send(false)

        print("🏁 [AudioRecorder] Exiting stopRecording() - Current isRecording: \(isRecording.value)")
    }

    func getRecordingData() -> Data? {
        guard let url = recordingURL else { return nil }
        do {
            return try Data(contentsOf: url)
        } catch {
            print("❌ Failed to get data: \(error.localizedDescription)")
            errorPublisher.send(error)
            return nil
        }
    }

    // MARK: - AVAudioRecorderDelegate

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("🔔 [AudioRecorder] audioRecorderDidFinishRecording called - Success: \(flag)")
        if flag {
            print("✅ [AudioRecorder] Finished recording successfully: \(recorder.url)")
        } else {
            print("⚠️ [AudioRecorder] Recording failed or stopped prematurely.")
        }
        print("📊 [AudioRecorder] Sending isRecording false from delegate. Current value: \(isRecording.value)")
        isRecording.send(false)
        print("📉 [AudioRecorder] isRecording set to false by delegate. New value: \(isRecording.value)")
        // Make sure the recorder instance is nilled out *after* delegate calls potentially finish
        if audioRecorder === recorder { // Ensure we are nilling the correct instance
             audioRecorder = nil
             print("🗑️ [AudioRecorder] audioRecorder instance nilled out in delegate.")
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("❌ [AudioRecorder] Encode error: \(error?.localizedDescription ?? "Unknown")")
        isRecording.send(false)
        if let error = error {
            errorPublisher.send(error)
        }
        // Make sure the recorder instance is nilled out *after* delegate calls potentially finish
        if audioRecorder === recorder { // Ensure we are nilling the correct instance
             audioRecorder = nil
             print("🗑️ [AudioRecorder] audioRecorder instance nilled out after encode error.")
        }
    }

    // MARK: - Helpers

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let session = AVAudioSession.sharedInstance()

        if #available(iOS 17, *) {
            Task {
                let granted = await AVAudioApplication.requestRecordPermission()
                print("🔊 [iOS 17+] Mic permission result: \(granted)")
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        } else {
            switch session.recordPermission {
            case .granted:
                print("🔊 Mic permission already granted")
                completion(true)
            case .denied:
                print("❌ Mic permission previously denied")
                completion(false)
            case .undetermined:
                session.requestRecordPermission { granted in
                    print("📣 Legacy mic permission result: \(granted)")
                    DispatchQueue.main.async {
                        completion(granted)
                    }
                }
            @unknown default:
                completion(false)
            }
        }
    }
}
