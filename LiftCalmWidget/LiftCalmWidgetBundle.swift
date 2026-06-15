//
//  LiftCalmWidgetBundle.swift
//  LiftCalmWidget
//
//  Entry point for the Home Screen / Lock Screen widgets.
//

import WidgetKit
import SwiftUI

@main
struct LiftCalmWidgetBundle: WidgetBundle {
    var body: some Widget {
        ReadinessWidget()
    }
}
