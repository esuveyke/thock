import Testing
import Foundation
@testable import Thock

@Suite(.serialized)
struct SoundpackPreviewPlayerTests {

    private typealias PCMSound = SoundManager.PCMSound

    /// Records what the player sends to the audio output, from any thread.
    private final class OutputRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var played: [(sound: PCMSound, source: VolumeLevels.Source)] = []

        func record(_ sound: PCMSound, _ source: VolumeLevels.Source) {
            lock.lock(); defer { lock.unlock() }
            played.append((sound, source))
        }

        var calls: [(sound: PCMSound, source: VolumeLevels.Source)] {
            lock.lock(); defer { lock.unlock() }
            return played
        }
    }

    private func makePack(category: String = "keyboard") -> Soundpack {
        Soundpack(id: UUID(), name: "Pack", brand: "Brand", author: "Author", category: category, path: "test/")
    }

    private func makeConfig(category: String = "keyboard") throws -> SoundpackConfig {
        let sounds = category == "mouse"
            ? "{\"left\": {\"down\": [\"d.wav\"], \"up\": [\"u.wav\"]}}"
            : "{\"default\": {\"down\": [\"k.wav\"], \"up\": []}}"
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "metadata": { "name": "Pack", "brand": "Brand", "author": "Author", "category": "\(category)" },
          "license": { "type": "MIT", "url": "https://example.com" },
          "sounds": \(sounds)
        }
        """
        return try JSONDecoder().decode(SoundpackConfig.self, from: Data(json.utf8))
    }

    /// A player whose loader returns a distinct PCMSound per pack, so tests can tell packs apart.
    private func makePlayer(config: SoundpackConfig?, recorder: OutputRecorder,
                            soundsByPack: [UUID: PCMSound] = [:]) -> SoundpackPreviewPlayer {
        SoundpackPreviewPlayer(
            configProvider: { _ in config },
            soundLoader: { names, pack in
                let sound = soundsByPack[pack.id] ?? PCMSound(data: [0, 0], frameCount: 1)
                return Dictionary(uniqueKeysWithValues: names.map { ($0, sound) })
            },
            output: { recorder.record($0, $1) }
        )
    }

    @Test func previewPlaysEveryStep() async throws {
        let recorder = OutputRecorder()
        let config = try makeConfig()
        let player = makePlayer(config: config, recorder: recorder)
        var rng = SystemRandomNumberGenerator()
        let expected = SoundpackPreviewSampler.steps(for: config, category: "keyboard", using: &rng).count

        player.preview(makePack())
        try await Task.sleep(for: .milliseconds(700))

        #expect(recorder.calls.count == expected)
        #expect(recorder.calls.allSatisfy { $0.source == .keyboard })
    }

    @Test func mousePreviewUsesMouseSource() async throws {
        let recorder = OutputRecorder()
        let player = makePlayer(config: try makeConfig(category: "mouse"), recorder: recorder)

        player.preview(makePack(category: "mouse"))
        try await Task.sleep(for: .milliseconds(300))

        #expect(recorder.calls.count == 2)
        #expect(recorder.calls.allSatisfy { $0.source == .mouse })
    }

    @Test func startingNewPreviewCancelsPrevious() async throws {
        let recorder = OutputRecorder()
        let packA = makePack(), packB = makePack()
        let soundA = PCMSound(data: [0, 0], frameCount: 1), soundB = PCMSound(data: [0, 0], frameCount: 1)
        let player = makePlayer(config: try makeConfig(), recorder: recorder,
                                soundsByPack: [packA.id: soundA, packB.id: soundB])

        player.preview(packA)
        try await Task.sleep(for: .milliseconds(10))
        player.preview(packB)
        try await Task.sleep(for: .milliseconds(700))

        #expect(!recorder.calls.isEmpty)
        #expect(recorder.calls.dropFirst().allSatisfy { $0.sound === soundB })
        #expect(player.cachedPackID == packB.id)
    }

    @Test func missingConfigPlaysNothing() async throws {
        let recorder = OutputRecorder()
        let player = makePlayer(config: nil, recorder: recorder)

        player.preview(makePack())
        try await Task.sleep(for: .milliseconds(300))

        #expect(recorder.calls.isEmpty)
    }

    @Test func cancelStopsPlayback() async throws {
        let recorder = OutputRecorder()
        let player = makePlayer(config: try makeConfig(), recorder: recorder)

        player.preview(makePack())
        player.cancel()
        try await Task.sleep(for: .milliseconds(700))

        #expect(recorder.calls.count <= 1)
    }

    @Test func previewDoesNotTouchLiveLibrary() {
        let before = SoundManager.shared.soundLibraryCount
        let keyUpBefore = SoundpackConfigManager.shared.supportsKeyUpSounds()
        let pack = makePack()

        _ = SoundpackConfigManager.shared.config(for: pack)
        _ = SoundManager.shared.loadSounds(named: ["k.wav"], for: pack)

        #expect(SoundManager.shared.soundLibraryCount == before)
        #expect(SoundpackConfigManager.shared.supportsKeyUpSounds() == keyUpBefore)
    }
}
