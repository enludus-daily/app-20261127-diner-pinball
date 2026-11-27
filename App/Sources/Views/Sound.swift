import AVFoundation

/// 効果音（端末の中で作る。録音したファイルは持たない）。
/// 昼の食堂：フライ返しのカチッ、食材に当たるポン（食材ごとに高さが違う）、鍋に落ちるポチャン、
/// 料理があがった呼び鈴のチーン、連続の上がる 2 音、帰ったお客のため息、玉を落としたゴトン、ラストオーダーの鈴。
/// 消音スイッチに従い、ほかのアプリの音と混ぜる（.ambient）
@MainActor
final class SoundBox {
    static let shared = SoundBox()

    enum Cue: Hashable {
        case flip, pop(Double), sling, plop, bell, combo, miss, sigh, thud, lastCall, open, close
    }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var nextPlayer = 0
    private var prepared = false
    private let rate = 44_100.0
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)

    /// 音量の段階：カチッ 0.25・ポン 0.45・スリング 0.3・ポチャン 0.6・チーン 0.8・失敗 0.7・知らせ 0.7
    private func volume(_ cue: Cue) -> Float {
        switch cue {
        case .flip: 0.25
        case .pop: 0.45
        case .sling, .miss: 0.3
        case .plop: 0.6
        case .bell, .combo, .close: 0.8
        case .sigh, .thud: 0.7
        case .lastCall, .open: 0.7
        }
    }

    private func prepare() -> Bool {
        if prepared { return engine.isRunning || ((try? engine.start()) != nil) }
        guard let format else { return false }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for _ in 0..<8 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        prepared = true
        return (try? engine.start()) != nil
    }

    func play(_ cue: Cue, on: Bool) {
        guard on, prepare(), engine.isRunning else { return }
        let buffer: AVAudioPCMBuffer
        if let b = buffers[cue] {
            buffer = b
        } else {
            guard let b = make(cue) else { return }
            buffers[cue] = b
            buffer = b
        }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.volume = volume(cue)
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
    }

    private struct Tone {
        var freq: Double
        var amp: Double
        var decay: Double
        var delay: Double = 0
        var glide: Double? = nil
    }

    private func make(_ cue: Cue) -> AVAudioPCMBuffer? {
        switch cue {
        case .flip:
            // 木のカチッ
            return render(0.07, noise: 0.25, noiseDecay: 140, tones: [Tone(freq: 900, amp: 0.15, decay: 90)])
        case .pop(let f):
            // ぷるんとしたポン（少し上がる）
            return render(0.18, noise: 0.03, noiseDecay: 80, tones: [Tone(freq: f, amp: 0.35, decay: 22, glide: f * 1.35), Tone(freq: f * 2, amp: 0.08, decay: 30)])
        case .sling:
            return render(0.1, noise: 0.15, noiseDecay: 70, tones: [Tone(freq: 300, amp: 0.2, decay: 40, glide: 420)])
        case .plop:
            // 鍋にポチャン（下がってから上がる）
            return render(0.35, noise: 0.08, noiseDecay: 25, tones: [Tone(freq: 420, amp: 0.35, decay: 12, glide: 900)])
        case .bell:
            // 呼び鈴のチーン（倍音つき、長く残る）
            return render(1.2, noise: 0, tones: [Tone(freq: 1975.5, amp: 0.28, decay: 3.5), Tone(freq: 4939, amp: 0.08, decay: 6), Tone(freq: 2960, amp: 0.06, decay: 5)])
        case .combo:
            return render(1.2, noise: 0, tones: [Tone(freq: 1568, amp: 0.22, decay: 5), Tone(freq: 2093, amp: 0.26, decay: 3.5, delay: 0.09), Tone(freq: 5232, amp: 0.06, decay: 6, delay: 0.09)])
        case .miss:
            return render(0.2, noise: 0.05, noiseDecay: 40, tones: [Tone(freq: 330, amp: 0.2, decay: 18, glide: 280)])
        case .sigh:
            // ため息（ノイズが下がる）
            return render(0.6, noise: 0.18, noiseDecay: 5, tones: [Tone(freq: 520, amp: 0.12, decay: 5, glide: 260)])
        case .thud:
            // ゴトン
            return render(0.4, noise: 0.3, noiseDecay: 25, tones: [Tone(freq: 120, amp: 0.45, decay: 12, glide: 70)])
        case .lastCall:
            return render(0.7, noise: 0, tones: [Tone(freq: 2349, amp: 0.2, decay: 8), Tone(freq: 2349, amp: 0.2, decay: 8, delay: 0.22)])
        case .open:
            let notes = [784.0, 988.0, 1175.0]
            return render(0.9, noise: 0, tones: notes.enumerated().map { i, f in Tone(freq: f, amp: 0.2, decay: 5, delay: Double(i) * 0.1) })
        case .close:
            let notes = [1175.0, 988.0, 784.0, 1568.0]
            return render(1.4, noise: 0, tones: notes.enumerated().map { i, f in Tone(freq: f, amp: 0.2, decay: 4, delay: Double(i) * 0.13) })
        }
    }

    private func render(_ seconds: Double, noise: Double, noiseDecay: Double = 60, tones: [Tone]) -> AVAudioPCMBuffer? {
        guard let format else { return nil }
        let frames = AVAudioFrameCount(seconds * rate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        var rng = SeededRNG(seed: 27)
        var phases = Array(repeating: 0.0, count: tones.count)
        for i in 0..<Int(frames) {
            let t = Double(i) / rate
            var v = 0.0
            for (k, p) in tones.enumerated() where t >= p.delay {
                let local = t - p.delay
                var f = p.freq
                if let to = p.glide {
                    let x = min(1, local / max(0.01, seconds - p.delay))
                    f = p.freq + (to - p.freq) * x
                }
                phases[k] += 2 * .pi * f / rate
                let attack = min(1, local / 0.003)
                v += sin(phases[k]) * p.amp * exp(-local * p.decay) * attack
            }
            if noise > 0 {
                v += (rng.unit() * 2 - 1) * noise * exp(-t * noiseDecay)
            }
            let tail = min(1, (seconds - t) / 0.01)
            data[i] = Float(max(-1, min(1, v * tail)))
        }
        return buffer
    }
}
