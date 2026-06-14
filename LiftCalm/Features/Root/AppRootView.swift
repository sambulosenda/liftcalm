//
//  AppRootView.swift
//  LiftCalm
//
//  Chooses between first-run onboarding and the main app, crossfading once the
//  user finishes setup.
//

import SwiftUI

struct AppRootView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Group {
            if settings.hasCompletedOnboarding {
                RootView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.4), value: settings.hasCompletedOnboarding)
    }
}
