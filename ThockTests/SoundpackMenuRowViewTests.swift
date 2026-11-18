import Testing
import AppKit
@testable import Thock

@MainActor
struct SoundpackMenuRowViewTests {

    private func makeRow(isCurrent: Bool = false, onSelect: @escaping () -> Void = {}, onPreview: @escaping () -> Void = {}) -> SoundpackMenuRowView {
        SoundpackMenuRowView(title: "MX Blue", isCurrent: isCurrent, onSelect: onSelect, onPreview: onPreview)
    }

    private func previewButton(in row: SoundpackMenuRowView) -> NSButton? {
        row.subviews.compactMap { $0 as? NSButton }.first
    }

    @Test func previewButtonRunsPreviewOnly() {
        var previewed = 0, selected = 0
        let row = makeRow(onSelect: { selected += 1 }, onPreview: { previewed += 1 })

        previewButton(in: row)?.performClick(nil)

        #expect(previewed == 1)
        #expect(selected == 0)
    }

    @Test func previewButtonIsLabelledForVoiceOver() {
        let button = previewButton(in: makeRow())
        #expect(button?.accessibilityLabel() == L10n.previewSoundpack("MX Blue"))
    }

    @Test func rowIsAMenuItemNamedAfterThePack() {
        let row = makeRow(isCurrent: true)
        #expect(row.accessibilityRole() == .menuItem)
        #expect(row.accessibilityLabel() == "MX Blue")
        #expect(row.isAccessibilitySelected())
    }

    @Test func rowForOtherPackIsNotSelected() {
        #expect(!makeRow(isCurrent: false).isAccessibilitySelected())
    }
}
