import Foundation

/// One sound in a preview sample, played `offsetMs` after the sample starts.
struct PreviewStep: Equatable {
    let fileName: String
    let offsetMs: Int
}

/// Builds the short sample that plays when a sound pack is previewed from the menu.
enum SoundpackPreviewSampler {
    /// Keys typed in a keyboard sample: h, e, y, space.
    static let sampleKeyCodes: [Int64] = [4, 14, 16, 49]

    /// Time between one key-down and its key-up.
    private static let keyUpDelayMs = 60
    /// Time between key-downs, matching the typing demo in onboarding.
    private static let keyGapMs = 90...160
    /// Time between a mouse button's down and up sounds.
    private static let mouseUpDelayMs = 80

    static func steps(for config: SoundpackConfig, category: String, using rng: inout some RandomNumberGenerator) -> [PreviewStep] {
        category == "mouse" ? mouseSteps(for: config) : keyboardSteps(for: config, using: &rng)
    }

    private static func keyboardSteps(for config: SoundpackConfig, using rng: inout some RandomNumberGenerator) -> [PreviewStep] {
        let fallback = config.sounds[KeyMapper.keyCodeNotFound]
        var steps: [PreviewStep] = []
        var offset = 0

        for code in sampleKeyCodes {
            let sound = config.sounds[KeyMapper.fromKeyCode(code)] ?? fallback
            guard let down = sound?.down.randomElement(using: &rng) else { continue }
            if !steps.isEmpty { offset += Int.random(in: keyGapMs, using: &rng) }
            steps.append(PreviewStep(fileName: down, offsetMs: offset))
            if config.metadata.supportsKeyUp, let up = sound?.up.randomElement(using: &rng) {
                steps.append(PreviewStep(fileName: up, offsetMs: offset + keyUpDelayMs))
            }
        }
        return steps
    }

    private static func mouseSteps(for config: SoundpackConfig) -> [PreviewStep] {
        guard let left = config.sounds["left"], let down = left.down.first else { return [] }
        var steps = [PreviewStep(fileName: down, offsetMs: 0)]
        if let up = left.up.first {
            steps.append(PreviewStep(fileName: up, offsetMs: mouseUpDelayMs))
        }
        return steps
    }
}
