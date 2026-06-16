//
//  QuickLogService.swift
//  LiftCalm
//
//  Natural-language set logging via Apple's Foundation Models framework. Mid-
//  workout the user types shorthand like "3x5 squat at 100kg"; the on-device
//  model parses it into a typed `ParsedSet` (guided generation — no string
//  parsing), which the UI maps to a real Exercise and logs through
//  SessionController. Runs entirely on-device, same privacy rationale as the
//  routine wizard (see RoutineWizardService).
//
//  NOTE: the availability check mirrors RoutineWizardService's on purpose, so
//  this feature stays self-contained. Both could later move to a shared helper.
//

import Foundation
import FoundationModels

/// Structured result of parsing one line of lifting shorthand.
@Generable
struct ParsedSet {
    @Guide(description: "The exercise name, copied EXACTLY from the allowed list. Never invent a name.")
    var exercise: String

    @Guide(description: "Number of sets — the first number in 'sets x reps'. Use 1 when only a rep count is given.")
    var sets: Int

    @Guide(description: "Reps in each set — the second number in 'sets x reps', or the bare rep count.")
    var reps: Int

    @Guide(description: "The weight as a plain number in whatever unit the user stated; 0 for bodyweight.")
    var weight: Double

    @Guide(description: "The unit the user stated: exactly \"kg\", \"lb\", or \"none\" when no unit was given or it's bodyweight.")
    var unit: String
}

enum QuickLogService {

    /// Parse one line of shorthand into a structured set. Only exercise *names*
    /// are sent to the model. Model availability lives in `AIModel`.
    static func parse(text: String, allowedExercises: [String]) async throws -> ParsedSet {
        let session = LanguageModelSession {
            """
            You convert a lifter's shorthand into ONE logged exercise for the LiftCalm app.
            Always read the numbers straight from the input — the examples below are
            formats only, never defaults.
            - "sets x reps": "4x6" → 4 sets of 6 reps; "3x10" → 3 sets of 10 reps.
            - A bare rep count ("8 reps", "x8", or "8 pull-ups") → 1 set of that many reps.
            - Pick the closest exercise from the allowed list, expanding abbreviations
              ("ohp" → Overhead Press, "bench" → Barbell Bench Press, "dl" → Deadlift).
              Copy the chosen name exactly.
            - Read the weight as a number and its unit ("kg" or "lb"); use "none"
              when no unit is written or the movement is bodyweight.
            """
        }
        let prompt = """
        Lifter input: "\(text)"

        Allowed exercises — choose only from this list and copy the name exactly:
        \(allowedExercises.map { "- \($0)" }.joined(separator: "\n"))
        """
        let response = try await session.respond(to: prompt, generating: ParsedSet.self)
        return response.content
    }

    // MARK: - Pure interpretation (unit-tested)

    /// Convert a parsed weight value + unit hint into canonical kilograms,
    /// falling back to the user's preferred unit when none was stated. Negative
    /// values clamp to zero.
    static func kilograms(value: Double, unitHint: String, defaultUnit: WeightUnit) -> Double {
        let hint = unitHint.lowercased()
        let unit: WeightUnit
        if hint.contains("lb") || hint.contains("pound") {
            unit = .pounds
        } else if hint.contains("kg") || hint.contains("kilo") {
            unit = .kilograms
        } else {
            unit = defaultUnit
        }
        return unit.toKilograms(max(0, value))
    }

    /// Match a parsed exercise name to a catalog position by normalized
    /// (lowercased, alphanumeric-only) comparison. Returns nil if nothing matches.
    static func matchIndex(name: String, catalogNames: [String]) -> Int? {
        let target = normalize(name)
        guard !target.isEmpty else { return nil }
        return catalogNames.firstIndex { normalize($0) == target }
    }

    static func normalize(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
