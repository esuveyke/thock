import Foundation

/// Decides which catalog packs in Settings can be previewed.
enum SoundpackPreviewTarget {
    /// Returns the downloaded pack behind a catalog entry, or nil when there's nothing on disk to
    /// play: the pack isn't downloaded, or its files can't be found.
    static func soundpack(for entry: SoundpackRegistryEntry, isInstalled: Bool,
                          lookup: (UUID) -> Soundpack?) -> Soundpack? {
        guard isInstalled else { return nil }
        return lookup(entry.id)
    }
}
