//
//  Theme.swift
//  LiftCalm
//
//  Calming palette — soft greens and blues. Defined in code so the app has a
//  consistent identity without requiring asset-catalog round-trips during the
//  foundation phase. Colors are chosen to keep contrast legible in both schemes.
//

import SwiftUI

enum Theme {
    /// Primary brand accent — a calm, grounded green.
    static let accent = Color(red: 0.31, green: 0.62, blue: 0.51)
    /// Secondary accent — soft blue, used for recovery / informational cues.
    static let calmBlue = Color(red: 0.36, green: 0.55, blue: 0.71)
    /// Positive / completion signal.
    static let success = Color(red: 0.30, green: 0.66, blue: 0.46)
    /// Gentle warning (e.g. deload hints) — never alarming red.
    static let caution = Color(red: 0.82, green: 0.62, blue: 0.35)

    /// Standard corner radius for cards so glass/material surfaces stay consistent.
    static let cardCornerRadius: CGFloat = 20
    static let controlCornerRadius: CGFloat = 14
}

extension ShapeStyle where Self == Color {
    static var brandAccent: Color { Theme.accent }
    static var calmBlue: Color { Theme.calmBlue }
}
