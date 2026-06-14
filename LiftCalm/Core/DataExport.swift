//
//  DataExport.swift
//  LiftCalm
//
//  Local-first means your data is yours: full CSV/JSON export, no lock-in.
//  Builds an export file in the temporary directory and returns its URL for
//  sharing. Always exports canonical kilograms (documented in the header/key).
//

import Foundation

/// Identifiable wrapper so a generated export can drive a `.sheet(item:)`.
struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

enum DataExport {

    enum Format { case csv, json }

    /// Produces an export file for the given finished workouts.
    /// Throws if encoding or writing fails so the caller can surface an error.
    /// MainActor-bound: reads SwiftData models and is always user-initiated.
    @MainActor
    static func makeFile(_ workouts: [Workout], format: Format) throws -> ExportFile {
        let (contents, ext) = switch format {
        case .csv: (csv(workouts), "csv")
        case .json: (try json(workouts), "json")
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiftCalm-Export.\(ext)")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return ExportFile(url: url)
    }

    // MARK: - CSV

    @MainActor
    private static func csv(_ workouts: [Workout]) -> String {
        var rows = ["date,template,exercise,set,weight_kg,reps,rpe,completed,warmup"]
        let dateFormat = Date.ISO8601FormatStyle()
        for workout in workouts.sorted(by: { $0.startedAt < $1.startedAt }) {
            let date = workout.startedAt.formatted(dateFormat)
            let template = escape(workout.templateName ?? "")
            for entry in workout.orderedEntries {
                let name = escape(entry.exercise?.name ?? "")
                for (index, set) in entry.orderedSets.enumerated() {
                    let rpe = set.rpe.map { String($0) } ?? ""
                    rows.append(
                        "\(date),\(template),\(name),\(index + 1),\(set.weightKilograms),\(set.reps),\(rpe),\(set.isCompleted),\(set.isWarmup)"
                    )
                }
            }
        }
        return rows.joined(separator: "\n")
    }

    /// Quote fields containing commas/quotes per RFC 4180.
    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else {
            return field
        }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    // MARK: - JSON

    @MainActor
    private static func json(_ workouts: [Workout]) throws -> String {
        let payload = workouts
            .sorted { $0.startedAt < $1.startedAt }
            .map(ExportWorkout.init)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        return String(decoding: data, as: UTF8.self)
    }

    // Plain Codable snapshot types — decoupled from the SwiftData models so the
    // export schema is stable even if storage changes.
    private struct ExportWorkout: Encodable {
        let startedAt: Date
        let endedAt: Date?
        let template: String?
        let exercises: [ExportExercise]

        @MainActor
        init(_ workout: Workout) {
            startedAt = workout.startedAt
            endedAt = workout.endedAt
            template = workout.templateName
            exercises = workout.orderedEntries.map(ExportExercise.init)
        }
    }

    private struct ExportExercise: Encodable {
        let name: String
        let muscleGroup: String
        let sets: [ExportSet]

        @MainActor
        init(_ entry: ExerciseEntry) {
            name = entry.exercise?.name ?? "Unknown"
            muscleGroup = entry.exercise?.muscleGroup.rawValue ?? "other"
            sets = entry.orderedSets.map(ExportSet.init)
        }
    }

    private struct ExportSet: Encodable {
        let weightKilograms: Double
        let reps: Int
        let rpe: Double?
        let completed: Bool
        let warmup: Bool

        @MainActor
        init(_ set: SetEntry) {
            weightKilograms = set.weightKilograms
            reps = set.reps
            rpe = set.rpe
            completed = set.isCompleted
            warmup = set.isWarmup
        }
    }
}
