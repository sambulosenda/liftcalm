//
//  QuickLogView.swift
//  LiftCalm
//
//  "Quick Log with AI" sheet, presented from the active workout. The user types
//  shorthand ("3x5 squat at 100kg"); the on-device model (QuickLogService)
//  parses it, we resolve the exercise against the library and show what was
//  understood, then log it through SessionController on confirm.
//

import SwiftUI
import SwiftData

struct QuickLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionController.self) private var session
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var input = ""
    @State private var phase: Phase = .input
    @State private var availability: AIModel.Availability = .ready
    @State private var parsed: Parsed?
    @State private var loggedToken = false
    @State private var task: Task<Void, Never>?
    @FocusState private var inputFocused: Bool

    enum Phase: Equatable { case input, parsing, confirm, notFound(String), failed(String) }

    /// A parse resolved against the library, ready to log.
    struct Parsed {
        let exercise: Exercise
        let sets: Int
        let reps: Int
        let kilograms: Double
    }

    var body: some View {
        NavigationStack {
            Group {
                if availability == .ready {
                    switch phase {
                    case .input:           inputView
                    case .parsing:         parsingView
                    case .confirm:         confirmView
                    case .notFound(let n): notFoundView(n)
                    case .failed(let m):   failedView(m)
                    }
                } else {
                    unavailableView
                }
            }
            .navigationTitle("Quick Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { task?.cancel(); dismiss() }
                }
            }
            .sensoryFeedback(.success, trigger: loggedToken)
            .onAppear {
                availability = AIModel.availability
                if availability == .ready { inputFocused = true }
            }
            .onDisappear { task?.cancel() }
        }
    }

    // MARK: - Input

    private var inputView: some View {
        Form {
            Section {
                TextField("e.g. 3×5 squat at 100kg", text: $input)
                    .focused($inputFocused)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(parse)
            } footer: {
                Text("Type what you did — exercise, sets × reps, and weight, e.g. “bench 3x8 80kg”. It runs entirely on your device.")
            }
            Section {
                Button { parse() } label: {
                    Label("Continue", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminentCompat)
                .listRowBackground(Color.clear)
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // MARK: - Parsing

    private var parsingView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ProgressView().controlSize(.large)
            Text("Reading your set…")
                .font(.headline)
            Text("On your device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Confirm

    @ViewBuilder
    private var confirmView: some View {
        if let p = parsed {
            Form {
                Section("Logging") {
                    LabeledContent("Exercise", value: p.exercise.name)
                    LabeledContent("Sets", value: "\(p.sets)")
                    LabeledContent("Reps", value: "\(p.reps) each")
                    LabeledContent(
                        "Weight",
                        value: p.kilograms > 0
                            ? Formatting.weight(p.kilograms, unit: settings.weightUnit)
                            : "Bodyweight"
                    )
                }
                Section {
                    Button { log(p) } label: {
                        Label("Add \(p.sets) set\(p.sets == 1 ? "" : "s") to workout",
                              systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminentCompat)
                    .listRowBackground(Color.clear)
                    Button {
                        phase = .input
                        inputFocused = true
                    } label: {
                        Text("Edit").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .listRowBackground(Color.clear)
                }
            }
        }
    }

    // MARK: - Not found / failed / unavailable

    private func notFoundView(_ name: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't find that exercise", systemImage: "questionmark.circle")
        } description: {
            Text("“\(name)” isn't in your library. Add it from the Library tab, or try a different name.")
        } actions: {
            Button("Try again") { phase = .input; inputFocused = true }
                .buttonStyle(.glassProminentCompat)
        }
    }

    private func failedView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't read that", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try again") { phase = .input; inputFocused = true }
                .buttonStyle(.glassProminentCompat)
        }
    }

    private var unavailableView: some View {
        ContentUnavailableView {
            Label(unavailableTitle, systemImage: "exclamationmark.triangle")
        } description: {
            Text(unavailableMessage)
        } actions: {
            Button("Done") { dismiss() }
                .buttonStyle(.glassProminentCompat)
        }
    }

    private var unavailableTitle: String {
        switch availability {
        case .deviceNotEligible:    "Not available on this device"
        case .appleIntelligenceOff: "Apple Intelligence is off"
        case .modelDownloading:     "Getting ready"
        default:                    "AI is unavailable"
        }
    }

    private var unavailableMessage: String {
        switch availability {
        case .deviceNotEligible:
            "Text logging needs a device that supports Apple Intelligence. You can still log sets by hand."
        case .appleIntelligenceOff:
            "Turn on Apple Intelligence in Settings to log sets by voice or text — or log them by hand."
        case .modelDownloading:
            "The on-device model is still downloading. Try again shortly, or log sets by hand."
        default:
            "On-device text logging isn't available right now. You can still log sets by hand."
        }
    }

    // MARK: - Flow

    private func parse() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputFocused = false
        task?.cancel()
        phase = .parsing
        let names = exercises.map(\.name)
        task = Task { @MainActor in
            do {
                let result = try await QuickLogService.parse(text: text, allowedExercises: names)
                if Task.isCancelled { return }
                apply(result)
            } catch is CancellationError {
                // User moved on — ignore.
            } catch {
                if Task.isCancelled { return }
                phase = .failed("Try rephrasing, e.g. “squat 3x5 100kg”.")
            }
        }
    }

    private func apply(_ result: ParsedSet) {
        guard let index = QuickLogService.matchIndex(name: result.exercise, catalogNames: exercises.map(\.name)) else {
            phase = .notFound(result.exercise)
            return
        }
        parsed = Parsed(
            exercise: exercises[index],
            sets: min(max(result.sets, 1), 20),
            reps: max(0, result.reps),
            kilograms: QuickLogService.kilograms(
                value: result.weight, unitHint: result.unit, defaultUnit: settings.weightUnit
            )
        )
        phase = .confirm
    }

    private func log(_ p: Parsed) {
        guard let workout = session.activeWorkout else { dismiss(); return }
        session.logSets(
            exercise: p.exercise,
            weightKilograms: p.kilograms,
            reps: p.reps,
            setCount: p.sets,
            markCompleted: true,
            in: workout
        )
        loggedToken.toggle()
        dismiss()
    }
}

#Preview {
    let container = PreviewData.container
    let session = SessionController()
    session.configure(context: container.mainContext, settings: AppSettings(), notifications: NotificationManager())
    session.startEmptyWorkout()
    return QuickLogView()
        .modelContainer(container)
        .environment(AppSettings())
        .environment(session)
}
