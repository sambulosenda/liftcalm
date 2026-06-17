//
//  Enums.swift
//  LiftCalm
//
//  Shared value types used across the domain. Kept Codable + CaseIterable so
//  SwiftData can persist them directly and the UI can enumerate filters.
//

import SwiftUI

/// Primary muscle group a movement trains. Drives library filters and the
/// muscle-balance summary shown after a session.
enum MuscleGroup: String, Codable, CaseIterable, Identifiable, Sendable {
    case chest, back, shoulders, biceps, triceps
    case quads, hamstrings, glutes, calves
    case core, fullBody, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullBody: "Full Body"
        default: rawValue.capitalized
        }
    }

    /// Coarse region used to keep the post-workout balance chart readable.
    var region: Region {
        switch self {
        case .chest, .back, .shoulders, .biceps, .triceps: .upper
        case .quads, .hamstrings, .glutes, .calves: .lower
        case .core, .fullBody, .other: .core
        }
    }

    enum Region: String, Sendable { case upper, lower, core }
}

/// Equipment required for a movement. Used for library filtering and the
/// "alternative suggestion" feature (same muscle, different equipment).
enum Equipment: String, Codable, CaseIterable, Identifiable, Sendable {
    case barbell, dumbbell, machine, cable, kettlebell, bodyweight, band, other

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .barbell: "figure.strengthtraining.traditional"
        case .dumbbell: "dumbbell.fill"
        case .machine, .cable: "gearshape.fill"
        case .kettlebell: "figure.cooldown"
        case .bodyweight: "figure.run"
        case .band: "oval.portrait"
        case .other: "questionmark.circle"
        }
    }
}

/// User's preferred unit. Weights are always stored canonically in kilograms;
/// this only affects display and entry.
enum WeightUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case kilograms, pounds

    var id: String { rawValue }
    var abbreviation: String { self == .kilograms ? "kg" : "lb" }
    var displayName: String { self == .kilograms ? "Kilograms (kg)" : "Pounds (lb)" }

    private static let lbPerKg = 2.2046226218

    /// Convert a canonical kilogram value into this unit, for display.
    func fromKilograms(_ kg: Double) -> Double {
        self == .kilograms ? kg : kg * Self.lbPerKg
    }

    /// Convert a value entered in this unit back into canonical kilograms.
    func toKilograms(_ value: Double) -> Double {
        self == .kilograms ? value : value / Self.lbPerKg
    }
}

/// Body diagram shown on the muscle-activation map. A pure display preference —
/// LiftCalm collects no biological sex, so this never leaves the device and
/// drives nothing but which silhouette is drawn. Defaults to masculine.
enum BodyModel: String, Codable, CaseIterable, Identifiable, Sendable {
    case masculine, feminine
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

/// Captured during onboarding; tunes starter templates and copy tone.
enum ExperienceLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case beginner, intermediate, advanced
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

/// Primary training intent. Influences default rest durations and rep guidance.
enum TrainingGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case strength, hypertrophy, endurance, general

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general: "General Fitness"
        default: rawValue.capitalized
        }
    }

    /// Sensible default rest between working sets, in seconds.
    var defaultRestSeconds: Int {
        switch self {
        case .strength: 180
        case .hypertrophy: 90
        case .endurance: 45
        case .general: 90
        }
    }
}

/// Lightweight self-report logged per session, feeding future readiness work.
enum EnergyLevel: Int, Codable, CaseIterable, Identifiable, Sendable {
    case drained = 1, low, okay, good, great

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .drained: "Drained"
        case .low: "Low"
        case .okay: "Okay"
        case .good: "Good"
        case .great: "Great"
        }
    }

    var symbol: String {
        switch self {
        case .drained: "battery.0percent"
        case .low: "battery.25percent"
        case .okay: "battery.50percent"
        case .good: "battery.75percent"
        case .great: "battery.100percent"
        }
    }
}
