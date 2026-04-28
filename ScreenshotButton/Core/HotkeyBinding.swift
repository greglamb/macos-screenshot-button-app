import Carbon.HIToolbox
import Foundation

struct HotkeyBinding: Sendable, Hashable, Codable {
    let keyCode: UInt16

    var label: String {
        // F1..F19 → derive number from the kVK_F* constants.
        for n in 1...19 {
            if keyCode == HotkeyBinding.keyCode(forFKeyNumber: n) { return "F\(n)" }
        }
        return "?"
    }

    init?(fKeyNumber: Int) {
        guard (1...19).contains(fKeyNumber),
              let code = HotkeyBinding.keyCode(forFKeyNumber: fKeyNumber)
        else { return nil }
        self.keyCode = code
    }

    static let allFKeys: [HotkeyBinding] = (1...19).compactMap(HotkeyBinding.init(fKeyNumber:))

    private static func keyCode(forFKeyNumber n: Int) -> UInt16? {
        switch n {
        case 1:  return UInt16(kVK_F1)
        case 2:  return UInt16(kVK_F2)
        case 3:  return UInt16(kVK_F3)
        case 4:  return UInt16(kVK_F4)
        case 5:  return UInt16(kVK_F5)
        case 6:  return UInt16(kVK_F6)
        case 7:  return UInt16(kVK_F7)
        case 8:  return UInt16(kVK_F8)
        case 9:  return UInt16(kVK_F9)
        case 10: return UInt16(kVK_F10)
        case 11: return UInt16(kVK_F11)
        case 12: return UInt16(kVK_F12)
        case 13: return UInt16(kVK_F13)
        case 14: return UInt16(kVK_F14)
        case 15: return UInt16(kVK_F15)
        case 16: return UInt16(kVK_F16)
        case 17: return UInt16(kVK_F17)
        case 18: return UInt16(kVK_F18)
        case 19: return UInt16(kVK_F19)
        default: return nil
        }
    }
}
