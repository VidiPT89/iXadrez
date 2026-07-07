import AVFoundation

enum ToneShape {
    case sine, triangle, square, sawtooth
}

/// Tiny real-time synth for short UI feedback beeps — no audio files.
final class SoundEngine {
    static let shared = SoundEngine()

    private struct Voice {
        let freq: Double
        let shape: ToneShape
        let gain: Double
        let startSample: Int64
        let durationSamples: Int64
    }

    private let engine = AVAudioEngine()
    private let sampleRate = 44100.0
    private var voices: [Voice] = []
    private let lock = NSLock()
    private var sampleClock: Int64 = 0
    private(set) var isOn: Bool {
        didSet { UserDefaults.standard.set(isOn, forKey: "xadrez.sound") }
    }

    private init() {
        isOn = UserDefaults.standard.object(forKey: "xadrez.sound") == nil ? true : UserDefaults.standard.bool(forKey: "xadrez.sound")

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let source = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = abl[0]
            let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)

            self.lock.lock()
            let localVoices = self.voices
            let startClock = self.sampleClock
            self.lock.unlock()

            for frame in 0..<Int(frameCount) {
                let now = startClock + Int64(frame)
                var sample: Float = 0
                for v in localVoices {
                    guard now >= v.startSample, now < v.startSample + v.durationSamples else { continue }
                    let elapsed = Double(now - v.startSample)
                    let t = elapsed / self.sampleRate
                    let ph = (elapsed * v.freq / self.sampleRate).truncatingRemainder(dividingBy: 1)
                    let raw: Double
                    switch v.shape {
                    case .sine: raw = sin(2 * .pi * ph)
                    case .triangle: raw = 4 * abs(ph - 0.5) - 1
                    case .square: raw = ph < 0.5 ? 1.0 : -1.0
                    case .sawtooth: raw = 2.0 * ph - 1.0
                    }
                    let durationSec = Double(v.durationSamples) / self.sampleRate
                    let envelope = v.gain * exp(-4.0 * (t / max(durationSec, 0.001)))
                    sample += Float(raw * envelope)
                }
                ptr[frame] = max(-1, min(1, sample))
            }

            self.lock.lock()
            self.sampleClock += Int64(frameCount)
            self.voices.removeAll { $0.startSample + $0.durationSamples < self.sampleClock }
            self.lock.unlock()

            return noErr
        }

        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    func toggleSound() -> Bool { isOn.toggle(); return isOn }

    private func playTone(freq: Double, duration: Double, shape: ToneShape = .sine, gain: Double = 0.16, delay: Double = 0) {
        guard isOn else { return }
        lock.lock()
        let start = sampleClock + Int64(delay * sampleRate)
        voices.append(Voice(freq: freq, shape: shape, gain: gain, startSample: start, durationSamples: Int64(duration * sampleRate)))
        lock.unlock()
    }

    func playMove() { playTone(freq: 320, duration: 0.09, shape: .triangle, gain: 0.16) }
    func playCapture() { playTone(freq: 180, duration: 0.14, shape: .square, gain: 0.18) }
    func playCheck() { playTone(freq: 520, duration: 0.1, shape: .sawtooth, gain: 0.15, delay: 0); playTone(freq: 660, duration: 0.12, shape: .sawtooth, gain: 0.15, delay: 0.09) }
    func playEnd() { playTone(freq: 440, duration: 0.15, shape: .sine, gain: 0.18, delay: 0); playTone(freq: 330, duration: 0.25, shape: .sine, gain: 0.18, delay: 0.14) }
    func playClick() { playTone(freq: 700, duration: 0.05, shape: .sine, gain: 0.1) }
}
