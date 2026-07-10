import SwiftUI

/// Semantic color tokens — Pine / Fern / Amber / Signal.
/// Features must use `Color.sv.*`, never raw hex.
enum SVPalette {
    static let pine950 = Color(hex: 0x0B_10_0C)
    static let pine900 = Color(hex: 0x15_1C_16)
    static let fern400 = Color(hex: 0x7D_C9_8F)
    static let amber400 = Color(hex: 0xDF_A7_5C)
    static let signal500 = Color(hex: 0xE2_69_5E)
    static let bone = Color(hex: 0xED_F1_EC)
    static let sage = Color(hex: 0x8F_A3_94)
}

extension Color {
    enum SV {
        static let canvas = SVPalette.pine950
        static let surface = SVPalette.pine900
        static let accent = SVPalette.fern400
        static let edit = SVPalette.amber400
        static let record = SVPalette.signal500
        static let textPrimary = SVPalette.bone
        static let textSecondary = SVPalette.sage
    }

    /// Namespace used as `Color.sv.canvas`.
    static let sv = SV.self

    /// Initializes from 0xRRGGBB.
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
