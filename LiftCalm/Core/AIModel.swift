//
//  AIModel.swift
//  LiftCalm
//
//  Shared gate for the on-device language model (Apple Foundation Models), used
//  by every AI feature (routine wizard, quick log). Keeps the availability
//  mapping in one place so features don't each re-derive it.
//

import FoundationModels

enum AIModel {
    enum Availability: Equatable {
        case ready
        case deviceNotEligible
        case appleIntelligenceOff
        case modelDownloading
        case unavailable

        /// The model can generate right now.
        var canRun: Bool { self == .ready }

        /// Whether to surface an AI entry point at all. Hidden only on hardware
        /// that can never run the model; transient states (downloading / Apple
        /// Intelligence off) still show so the feature can guide the user to fix them.
        var canOffer: Bool {
            switch self {
            case .deviceNotEligible, .unavailable: false
            default: true
            }
        }
    }

    /// Current availability of the on-device model. Cheap to query.
    static var availability: Availability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .ready
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:           return .deviceNotEligible
            case .appleIntelligenceNotEnabled: return .appleIntelligenceOff
            case .modelNotReady:               return .modelDownloading
            @unknown default:                  return .unavailable
            }
        @unknown default:
            return .unavailable
        }
    }
}
