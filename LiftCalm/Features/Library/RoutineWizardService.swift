//
//  RoutineWizardService.swift
//  LiftCalm
//
//  On-device routine generation via Apple's Foundation Models framework.
//  Runs entirely on the Neural Engine — no network, no account, nothing leaves
//  the phone — so it keeps LiftCalm's privacy promise intact (unlike cloud
//  "AI coach" features that quietly upload your training data). The model only
//  ever sees the *names* of the user's exercise library and returns a typed
//  routine, which the caller maps back to real `Exercise` rows. UI lives in
//  RoutineWizardView.
//

import Foundation
import FoundationModels

// MARK: - Generated output (guided-generation schema)

/// The structured routine the on-device model is constrained to produce.
/// `@Generable` makes the model return this shape directly — no string parsing.
@Generable
struct GeneratedRoutine {
    @Guide(description: "A short, motivating routine name of 1 to 3 words, with no surrounding quotes.")
    var name: String

    @Guide(description: "A one-line summary of the muscle groups trained, e.g. 'Chest, shoulders, triceps'.")
    var summary: String

    @Guide(description: "The exercises to perform, ordered hardest first — big compound lifts before accessories.")
    var exercises: [GeneratedExercise]
}

@Generable
struct GeneratedExercise {
    @Guide(description: "An exercise name copied EXACTLY from the allowed list. Never invent a name.")
    var name: String

    @Guide(description: "Number of working sets for this exercise, normally 3 or 4.")
    var targetSets: Int
}

// MARK: - Request

struct RoutineRequest {
    var focus: TrainingFocus
    var goal: TrainingGoal
    var experience: ExperienceLevel
    var exerciseCount: Int
    /// Bumped on each "Generate again" so the model offers something fresh.
    var variation: Int = 0

    func prompt(allowedExercises: [String]) -> String {
        var text = """
        Design a \(focus.title) routine (\(focus.detail)).
        Training goal: \(goal.displayName) — \(goal.promptDetail).
        Experience level: \(experience.displayName).
        Include exactly \(exerciseCount) exercises.
        """
        if variation > 0 {
            text += "\nOffer a fresh take, noticeably different from a standard template."
        }
        text += """


        Allowed exercises — pick ONLY from this list and copy each name exactly:
        \(allowedExercises.map { "- \($0)" }.joined(separator: "\n"))
        """
        return text
    }
}

// MARK: - Service

enum RoutineWizardService {

    /// Generate one routine. Only exercise *names* are sent to the model; the
    /// caller maps them back to real `Exercise` rows afterward. Model
    /// availability lives in `AIModel`.
    static func generate(request: RoutineRequest, allowedExercises: [String]) async throws -> GeneratedRoutine {
        let session = LanguageModelSession {
            """
            You are a focused strength-training coach for the LiftCalm app.
            Design ONE gym routine that matches the lifter's request.
            - Choose exercises ONLY from the allowed list and copy each name exactly.
            - Order them hardest first: big compound lifts, then accessories.
            - Do not repeat an exercise. No warm-ups, cardio, or stretching.
            - Keep it balanced: when the focus spans the whole body, include both
              lower-body and upper-body movements and cover pushing and pulling.
            """
        }
        let response = try await session.respond(
            to: request.prompt(allowedExercises: allowedExercises),
            generating: GeneratedRoutine.self
        )
        return response.content
    }

    /// Pure name-resolution shared by the UI and tests: map generated exercise
    /// names back to positions in the catalog by normalized match, dropping any
    /// name not in the catalog or already used, and clamping sets to a sane range.
    /// Working on `(name, sets)` tuples (not the `@Generable` type) keeps it
    /// trivially unit-testable. Returns catalog indices the caller maps to rows.
    static func resolved(
        _ generated: [(name: String, targetSets: Int)],
        catalogNames: [String]
    ) -> [(index: Int, targetSets: Int)] {
        var lookup: [String: Int] = [:]
        for (i, name) in catalogNames.enumerated() {
            let key = normalizeName(name)
            if lookup[key] == nil { lookup[key] = i }   // first occurrence wins
        }
        var used = Set<Int>()
        var out: [(index: Int, targetSets: Int)] = []
        for item in generated {
            guard let idx = lookup[normalizeName(item.name)], used.insert(idx).inserted else { continue }
            out.append((idx, min(max(item.targetSets, 1), 10)))
        }
        return out
    }

    /// Lowercased, alphanumeric-only — tolerant of case/punctuation drift so
    /// "PULL UP", "Pull-Up", and "pull up" all resolve to the same row.
    static func normalizeName(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

// MARK: - Input options

enum TrainingFocus: String, CaseIterable, Identifiable {
    case fullBody, upper, lower, push, pull, legs
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fullBody: "Full Body"
        case .upper:    "Upper Body"
        case .lower:    "Lower Body"
        case .push:     "Push"
        case .pull:     "Pull"
        case .legs:     "Legs"
        }
    }
    var detail: String {
        switch self {
        case .fullBody: "a balanced whole-body session"
        case .upper:    "chest, back, shoulders, and arms"
        case .lower:    "quads, hamstrings, glutes, and calves"
        case .push:     "chest, shoulders, and triceps"
        case .pull:     "back and biceps"
        case .legs:     "quads, hamstrings, and glutes"
        }
    }
}

// `TrainingGoal` and `ExperienceLevel` already live in Models/Enums.swift; we
// reuse them and add only the prompt phrasing the coach needs.
extension TrainingGoal {
    var promptDetail: String {
        switch self {
        case .strength:    "lower reps with a heavy compound focus"
        case .hypertrophy: "moderate reps for muscle growth"
        case .endurance:   "higher reps with short rest"
        case .general:     "balanced, sustainable training"
        }
    }
}
