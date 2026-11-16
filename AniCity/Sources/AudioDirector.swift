import AVFoundation

/// Short procedural loops: siren, engine hum, horn, and a crash tick.
/// If the audio session fails the rest of the game keeps running.
final class AudioDirector {
    private let engine = AVAudioEngine()
    private let sirenNode = AVAudioPlayerNode()
    private let humNode = AVAudioPlayerNode()
    private let fxNode = AVAudioPlayerNode()
    private let varispeed = AVAudioUnitVarispeed()
    private var sirenBuffer: AVAudioPCMBuffer?
    private var humBuffer: AVAudioPCMBuffer?
    private var hornBuffer: AVAudioPCMBuffer?
    private var bumpBuffer: AVAudioPCMBuffer?
    private var ready = false
    private var sirenOn = false

    init() {
        prepare()
    }

    func update(siren: Bool, distance: Float, driving: Bool, speed: Float) {
        guard ready else { return }
        if siren && !sirenOn {
            if let sirenBuffer {
                sirenNode.scheduleBuffer(sirenBuffer, at: nil, options: .loops)
            }
            sirenNode.volume = 0.2
            sirenNode.play()
            sirenOn = true
        }
        if !siren && sirenOn {
            sirenNode.stop()
            sirenOn = false
        }
        if sirenOn {
            let closeness = clamp(1 - distance / 55, 0, 1)
            sirenNode.volume = 0.08 + closeness * 0.45
        }
        if driving {
            if !humNode.isPlaying { humNode.play() }
            let norm = clamp(abs(speed) / 20, 0, 1)
            varispeed.rate = 0.65 + norm * 1.5
            humNode.volume = 0.05 + norm * 0.16
        } else if humNode.isPlaying {
            humNode.volume = 0
        }
    }

    func playHorn() {
        play(hornBuffer, volume: 0.35)
    }

    func playBump(intensity: Float) {
        play(bumpBuffer, volume: clamp(0.15 + intensity * 0.6, 0, 0.8))
    }

    private func play(_ buffer: AVAudioPCMBuffer?, volume: Float) {
        guard ready, let buffer else { return }
        fxNode.volume = volume
        fxNode.stop()
        fxNode.scheduleBuffer(buffer, at: nil, options: [])
        fxNode.play()
    }

    private func prepare() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            return
        }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 22050, channels: 1) else { return }
        sirenBuffer = tone(format: format, seconds: 0.8) { t in
            let freq: Float = t < 0.4 ? 680 : 920
            return sin(2 * Float.pi * freq * t) * 0.35
        }
        humBuffer = tone(format: format, seconds: 0.4) { t in
            let base = sin(2 * Float.pi * 70 * t)
            let harm = sin(2 * Float.pi * 140 * t) * 0.3
            return (base + harm) * 0.4
        }
        hornBuffer = tone(format: format, seconds: 0.18) { t in
            let env = min(1, t * 40) * min(1, (0.18 - t) * 20)
            return sin(2 * Float.pi * 360 * t) * 0.5 * env
        }
        bumpBuffer = tone(format: format, seconds: 0.16) { t in
            let env = (1 - t / 0.16)
            let noise = Float.random(in: -1...1)
            return noise * env * env
        }
        guard sirenBuffer != nil, humBuffer != nil else { return }

        engine.attach(sirenNode)
        engine.attach(humNode)
        engine.attach(fxNode)
        engine.attach(varispeed)
        engine.connect(sirenNode, to: engine.mainMixerNode, format: format)
        engine.connect(humNode, to: varispeed, format: format)
        engine.connect(varispeed, to: engine.mainMixerNode, format: format)
        engine.connect(fxNode, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
        } catch {
            return
        }
        if let sirenBuffer {
            sirenNode.scheduleBuffer(sirenBuffer, at: nil, options: .loops)
        }
        if let humBuffer {
            humNode.scheduleBuffer(humBuffer, at: nil, options: .loops)
        }
        humNode.volume = 0
        humNode.play()
        ready = true
    }

    private func tone(format: AVAudioFormat, seconds: Float, sample: (Float) -> Float) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(format.sampleRate * Double(seconds))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        guard let samples = buffer.floatChannelData?[0] else { return nil }
        let rate = Float(format.sampleRate)
        for index in 0..<Int(frames) {
            samples[index] = sample(Float(index) / rate)
        }
        return buffer
    }
}
