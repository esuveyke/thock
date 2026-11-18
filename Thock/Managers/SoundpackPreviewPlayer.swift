import Foundation

/// Plays a short sample of a sound pack without switching to it.
/// Sounds come from a cache of their own, so a preview never changes what plays while typing.
final class SoundpackPreviewPlayer {
    typealias PCMSound = SoundManager.PCMSound

    static let shared = SoundpackPreviewPlayer(
        configProvider: { SoundpackConfigManager.shared.config(for: $0) },
        soundLoader: { SoundManager.shared.loadSounds(named: $0, for: $1) },
        output: { SoundManager.shared.playPreview($0, source: $1) }
    )

    private let configProvider: (Soundpack) -> SoundpackConfig?
    private let soundLoader: ([String], Soundpack) -> [String: PCMSound]
    private let output: (PCMSound, VolumeLevels.Source) -> Void

    private let lock = NSLock()
    private var playback: Task<Void, Never>?
    private var cache: [String: PCMSound] = [:]
    private var cachedID: UUID?

    /// The pack whose sounds are in the preview cache. Only the most recent pack is kept.
    var cachedPackID: UUID? {
        lock.lock(); defer { lock.unlock() }
        return cachedID
    }

    init(configProvider: @escaping (Soundpack) -> SoundpackConfig?,
         soundLoader: @escaping ([String], Soundpack) -> [String: PCMSound],
         output: @escaping (PCMSound, VolumeLevels.Source) -> Void) {
        self.configProvider = configProvider
        self.soundLoader = soundLoader
        self.output = output
    }

    /// Plays a sample of the pack, cancelling any preview still playing.
    func preview(_ soundpack: Soundpack) {
        cancel()
        guard let config = configProvider(soundpack) else { return }

        var rng = SystemRandomNumberGenerator()
        let steps = SoundpackPreviewSampler.steps(for: config, category: soundpack.category, using: &rng)
        guard !steps.isEmpty else { return }

        let sounds = sounds(for: steps.map(\.fileName), in: soundpack)
        let source: VolumeLevels.Source = soundpack.category == "mouse" ? .mouse : .keyboard
        let output = self.output

        let task = Task.detached(priority: .userInitiated) {
            let start = ContinuousClock.now
            for step in steps {
                try? await Task.sleep(until: start + .milliseconds(step.offsetMs), clock: .continuous)
                if Task.isCancelled { return }
                if let sound = sounds[step.fileName] { output(sound, source) }
            }
        }
        lock.lock()
        playback = task
        lock.unlock()
    }

    /// Stops the preview in progress, if any.
    func cancel() {
        lock.lock()
        let task = playback
        playback = nil
        lock.unlock()
        task?.cancel()
    }

    /// Returns the decoded sounds for these files, loading any the cache doesn't have yet.
    /// Switching to another pack empties the cache first.
    private func sounds(for names: [String], in soundpack: Soundpack) -> [String: PCMSound] {
        lock.lock()
        if cachedID != soundpack.id {
            cache.removeAll()
            cachedID = soundpack.id
        }
        let missing = Set(names).subtracting(cache.keys)
        lock.unlock()

        let loaded = missing.isEmpty ? [:] : soundLoader(Array(missing), soundpack)

        lock.lock(); defer { lock.unlock() }
        guard cachedID == soundpack.id else { return loaded }
        cache.merge(loaded) { current, _ in current }
        return cache
    }
}
