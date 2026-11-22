import Testing
import Foundation
@testable import Thock

struct SoundpackPreviewTargetTests {

    private func makeEntry() throws -> SoundpackRegistryEntry {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "metadata": { "name": "MX Blue", "brand": "Cherry", "author": "Author", "supportsKeyUp": true },
          "content": { "path": "packs/mx-blue/" },
          "download": { "url": "https://example.com/mx-blue.zip", "size": 1024 },
          "license": { "type": "MIT", "url": "https://example.com" }
        }
        """
        return try JSONDecoder().decode(SoundpackRegistryEntry.self, from: Data(json.utf8))
    }

    private func makePack(id: UUID) -> Soundpack {
        Soundpack(id: id, name: "MX Blue", brand: "Cherry", author: "Author", category: "keyboard", path: "\(id)/")
    }

    @Test func notDownloadedHasNoPreview() throws {
        var lookups = 0
        let result = SoundpackPreviewTarget.soundpack(for: try makeEntry(), isInstalled: false) { id in
            lookups += 1
            return makePack(id: id)
        }
        #expect(result == nil)
        #expect(lookups == 0)
    }

    @Test func downloadedResolvesPack() throws {
        let entry = try makeEntry()
        let result = SoundpackPreviewTarget.soundpack(for: entry, isInstalled: true) { makePack(id: $0) }
        #expect(result?.id == entry.id)
    }

    @Test func downloadedButMissingHasNoPreview() throws {
        let result = SoundpackPreviewTarget.soundpack(for: try makeEntry(), isInstalled: true) { _ in nil }
        #expect(result == nil)
    }
}
