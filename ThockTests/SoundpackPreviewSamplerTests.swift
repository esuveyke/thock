import Testing
import Foundation
@testable import Thock

struct SoundpackPreviewSamplerTests {

    /// Builds a config from a `sounds` JSON object, the same shape as a pack's config.json.
    private func makeConfig(sounds: String, supportsKeyUp: Bool = true, category: String = "keyboard") throws -> SoundpackConfig {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "metadata": { "name": "Test", "brand": "Brand", "author": "Author",
                        "category": "\(category)", "supportsKeyUp": \(supportsKeyUp) },
          "license": { "type": "MIT", "url": "https://example.com" },
          "sounds": \(sounds)
        }
        """
        return try JSONDecoder().decode(SoundpackConfig.self, from: Data(json.utf8))
    }

    /// Every sample key with its own down and up files, e.g. "h-down.wav" and "h-up.wav".
    private var perKeySounds: String {
        let keys = SoundpackPreviewSampler.sampleKeyCodes.map { KeyMapper.fromKeyCode($0) }
        let entries = keys.map { "\"\($0)\": {\"down\": [\"\($0)-down.wav\"], \"up\": [\"\($0)-up.wav\"]}" }
        return "{" + entries.joined(separator: ",") + "}"
    }

    private func steps(_ config: SoundpackConfig, category: String = "keyboard") -> [PreviewStep] {
        var rng = SystemRandomNumberGenerator()
        return SoundpackPreviewSampler.steps(for: config, category: category, using: &rng)
    }

    @Test func keyboardProducesThreeToFourDownSteps() throws {
        let result = steps(try makeConfig(sounds: perKeySounds))
        let downs = result.filter { $0.fileName.hasSuffix("-down.wav") }
        #expect((3...4).contains(downs.count))
        let sampleKeys = SoundpackPreviewSampler.sampleKeyCodes.map { KeyMapper.fromKeyCode($0) }
        #expect(downs.map(\.fileName) == sampleKeys.prefix(downs.count).map { "\($0)-down.wav" })
    }

    @Test func keyGapsWithinRange() throws {
        let downs = steps(try makeConfig(sounds: perKeySounds)).filter { $0.fileName.hasSuffix("-down.wav") }
        #expect(downs.first?.offsetMs == 0)
        for (previous, next) in zip(downs, downs.dropFirst()) {
            #expect((90...160).contains(next.offsetMs - previous.offsetMs))
        }
    }

    @Test func keyUpOmittedWhenUnsupported() throws {
        let result = steps(try makeConfig(sounds: perKeySounds, supportsKeyUp: false))
        #expect(!result.isEmpty)
        #expect(result.allSatisfy { $0.fileName.hasSuffix("-down.wav") })
    }

    @Test func fallsBackToUnknownKey() throws {
        let sounds = "{\"\(KeyMapper.keyCodeNotFound)\": {\"down\": [\"any.wav\"], \"up\": []}}"
        let result = steps(try makeConfig(sounds: sounds))
        #expect(result.count >= 3)
        #expect(result.allSatisfy { $0.fileName == "any.wav" })
    }

    @Test func mouseProducesOneClick() throws {
        let sounds = "{\"left\": {\"down\": [\"d.wav\"], \"up\": [\"u.wav\"]}}"
        let result = steps(try makeConfig(sounds: sounds, category: "mouse"), category: "mouse")
        #expect(result == [PreviewStep(fileName: "d.wav", offsetMs: 0), PreviewStep(fileName: "u.wav", offsetMs: 80)])
    }

    @Test func emptyConfigProducesNoSteps() throws {
        #expect(steps(try makeConfig(sounds: "{}")).isEmpty)
    }
}
