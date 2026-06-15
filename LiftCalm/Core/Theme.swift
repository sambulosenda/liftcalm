//
//  Theme.swift
//  LiftCalm
//
//  Calming palette — soft greens and blues. Each brand color is tuned *per
//  scheme*: the light value is deepened so it stays legible as text/tint over
//  light backgrounds, the dark value is lightened so it glows gently over dark.
//  All four pass WCAG AA as small text in both schemes. Defined in code so the
//  light/dark pair lives side-by-side and the brand stays a single source of
//  truth (no asset-catalog drift) — call sites just use `Theme.accent`.
//

import SwiftUI
import UIKit

enum Theme {
    /// Raw brand hex pairs `(light, dark)` — the single source for both the
    /// SwiftUI tokens below and the widget snapshot (which bakes resolved hex so
    /// the extension needs zero app code). `0xRRGGBB`.
    enum Hex {
        static let accent: (light: UInt32, dark: UInt32) = (0x277552, 0x5CB897)
        static let calmBlue: (light: UInt32, dark: UInt32) = (0x34699A, 0x6FA0C7)
        static let success: (light: UInt32, dark: UInt32) = (0x2E7D4F, 0x5CBA85)
        static let caution: (light: UInt32, dark: UInt32) = (0x8A5E10, 0xE0A95C)
    }

    /// Primary brand accent — a calm, grounded green. (L 5.0:1 · D 7.1:1)
    static let accent = Color(light: Hex.accent.light, dark: Hex.accent.dark)
    /// Secondary accent — soft blue, used for recovery / informational cues. (L 5.2:1 · D 6.1:1)
    static let calmBlue = Color(light: Hex.calmBlue.light, dark: Hex.calmBlue.dark)
    /// Positive / completion signal. (L 4.5:1 · D 7.1:1)
    static let success = Color(light: Hex.success.light, dark: Hex.success.dark)
    /// Gentle warning (e.g. deload hints) — warm amber, never alarming red. (L 5.1:1 · D 8.1:1)
    static let caution = Color(light: Hex.caution.light, dark: Hex.caution.dark)

    /// Standard corner radius for cards so glass/material surfaces stay consistent.
    static let cardCornerRadius: CGFloat = 20
    static let controlCornerRadius: CGFloat = 14

    /// Spacing rhythm on a 4pt grid. Use these for stack spacing and content
    /// insets so the whole app shares one cadence; the tenth screen is free.
    /// (Fixed control dimensions and icon-alignment insets are not spacing —
    /// keep those as literals.)
    enum Spacing {
        /// 4 — micro gaps (title ↔ subtitle).
        static let xs: CGFloat = 4
        /// 8 — tight grouping.
        static let sm: CGFloat = 8
        /// 12 — default inter-item gap.
        static let md: CGFloat = 12
        /// 16 — screen gutters, card padding.
        static let lg: CGFloat = 16
        /// 24 — gaps between sections.
        static let xl: CGFloat = 24
        /// 32 — major / hero separation.
        static let xxl: CGFloat = 32
    }
}

extension Color {
    /// A color that resolves to `light` in light mode and `dark` in dark mode.
    /// Hex literals are `0xRRGGBB`. The dynamic `UIColor` provider also tracks
    /// runtime appearance changes (e.g. Settings → Display), so every surface
    /// that reads the token re-renders for free.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    /// 0xRRGGBB → opaque sRGB color.
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension ShapeStyle where Self == Color {
    static var brandAccent: Color { Theme.accent }
    static var calmBlue: Color { Theme.calmBlue }
}
