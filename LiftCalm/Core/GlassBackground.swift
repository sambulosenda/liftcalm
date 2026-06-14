//
//  GlassBackground.swift
//  LiftCalm
//
//  Liquid Glass adoption (iOS 26+) with a graceful material-based fallback.
//  The deployment target is iOS 26, but gating keeps the call sites honest and
//  ready if the floor ever lowers. Use these wrappers instead of calling
//  `glassEffect` directly so the fallback path lives in one place.
//

import SwiftUI

extension View {
    /// Applies a Liquid Glass surface, falling back to a blurred material on
    /// systems without the API. Apply *after* layout modifiers (padding/frame).
    @ViewBuilder
    func glassCard(
        cornerRadius: CGFloat = Theme.cardCornerRadius,
        fallbackMaterial: Material = .ultraThinMaterial
    ) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(
                fallbackMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }

    /// Interactive glass for tappable surfaces (chips, floating controls).
    @ViewBuilder
    func glassInteractive(
        in shape: some Shape = Capsule(),
        tint: Color? = nil
    ) -> some View {
        if #available(iOS 26, *) {
            let glass = tint.map { Glass.regular.tint($0).interactive() }
                ?? Glass.regular.interactive()
            self.glassEffect(glass, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}
