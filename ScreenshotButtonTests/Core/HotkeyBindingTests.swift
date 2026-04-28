import Foundation
import Testing
import Carbon.HIToolbox    // for kVK_F1...kVK_F19

@testable import ScreenshotButton

@Suite("HotkeyBinding")
struct HotkeyBindingTests {
    @Test("init?(fKeyNumber:) maps 1...19 to the matching kVK_F* keyCode",
          arguments: [
            (1, UInt16(kVK_F1)),  (2, UInt16(kVK_F2)),  (3, UInt16(kVK_F3)),
            (4, UInt16(kVK_F4)),  (5, UInt16(kVK_F5)),  (6, UInt16(kVK_F6)),
            (7, UInt16(kVK_F7)),  (8, UInt16(kVK_F8)),  (9, UInt16(kVK_F9)),
            (10, UInt16(kVK_F10)),(11, UInt16(kVK_F11)),(12, UInt16(kVK_F12)),
            (13, UInt16(kVK_F13)),(14, UInt16(kVK_F14)),(15, UInt16(kVK_F15)),
            (16, UInt16(kVK_F16)),(17, UInt16(kVK_F17)),(18, UInt16(kVK_F18)),
            (19, UInt16(kVK_F19))
          ])
    func mapsFKeyNumberToKeyCode(number: Int, expected: UInt16) {
        let binding = HotkeyBinding(fKeyNumber: number)
        #expect(binding?.keyCode == expected)
        #expect(binding?.label == "F\(number)")
    }

    @Test("init?(fKeyNumber:) returns nil for out-of-range values",
          arguments: [0, -1, 20, 100, Int.max, Int.min])
    func rejectsOutOfRange(number: Int) {
        #expect(HotkeyBinding(fKeyNumber: number) == nil)
    }

    @Test("allFKeys lists F1 through F19 in order")
    func allFKeysIsF1ThroughF19() {
        let labels = HotkeyBinding.allFKeys.map(\.label)
        #expect(labels == (1...19).map { "F\($0)" })
    }

    @Test("Codable round-trip preserves the binding")
    func codableRoundTrip() throws {
        let original = HotkeyBinding(fKeyNumber: 5)!
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HotkeyBinding.self, from: data)
        #expect(decoded == original)
    }
}
