import AVFoundation
import Combine

class AVSpeechSynthesizerDelegateHandler: NSObject, AVSpeechSynthesizerDelegate {
    let didFinishPublisher = PassthroughSubject<Void, Never>()

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        didFinishPublisher.send()
    }
} 