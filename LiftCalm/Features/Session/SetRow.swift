//
//  SetRow.swift
//  LiftCalm
//
//  One logged set. Built for speed: tap a field, type a number, tap the next.
//  Weight is entered in the user's unit and stored canonically in kg.
//

import SwiftUI

/// Identifies a focusable numeric field so focus can hop weight → reps → next.
enum SetField: Hashable {
    case weight(UUID)
    case reps(UUID)
}

struct SetRow: View {
    @Bindable var set: SetEntry
    /// 1-based position shown in the leading column.
    let displayNumber: Int
    var focus: FocusState<SetField?>.Binding

    @Environment(AppSettings.self) private var settings
    @Environment(SessionController.self) private var session

    var body: some View {
        HStack(spacing: 10) {
            setBadge

            numberField(
                value: weightBinding,
                placeholder: "0",
                field: .weight(set.id),
                decimal: true
            )
            .accessibilityLabel("Weight in \(settings.weightUnit.abbreviation)")

            numberField(
                value: repsBinding,
                placeholder: "0",
                field: .reps(set.id),
                decimal: false
            )
            .accessibilityLabel("Repetitions")

            rpeMenu

            completeButton
        }
        .padding(.vertical, 2)
        .opacity(set.isCompleted ? 0.9 : 1)
        .listRowBackground(set.isCompleted ? Theme.success.opacity(0.08) : Color.clear)
    }

    // MARK: - Columns

    private var setBadge: some View {
        Text("\(displayNumber)")
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(set.isWarmup ? Theme.caution : .secondary)
            .frame(width: 26, height: 26)
            .background(.quaternary, in: .circle)
            .accessibilityLabel(set.isWarmup ? "Warm-up set \(displayNumber)" : "Set \(displayNumber)")
    }

    private func numberField(
        value: Binding<Double>,
        placeholder: String,
        field: SetField,
        decimal: Bool
    ) -> some View {
        TextField(
            placeholder,
            value: value,
            format: .number.precision(.fractionLength(decimal ? 0...1 : 0...0))
        )
        .keyboardType(decimal ? .decimalPad : .numberPad)
        .multilineTextAlignment(.center)
        .font(.body.monospacedDigit())
        .focused(focus, equals: field)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
        .submitLabel(decimal ? .next : .done)
        .onSubmit { advanceFocus(from: field) }
    }

    private var rpeMenu: some View {
        Menu {
            Picker("RPE", selection: rpeBinding) {
                Text("—").tag(Double?.none)
                ForEach(rpeOptions, id: \.self) { value in
                    Text(value.formatted(.number.precision(.fractionLength(0...1))))
                        .tag(Double?.some(value))
                }
            }
        } label: {
            Text(set.rpe.map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "RPE")
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(set.rpe == nil ? .secondary : Theme.calmBlue)
                .frame(width: 42, height: 34)
                .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
        }
        .accessibilityLabel("Rate of perceived exertion")
        .accessibilityValue(set.rpe.map { "\($0.formatted())" } ?? "not set")
    }

    private var completeButton: some View {
        Button {
            session.toggleCompletion(set)
        } label: {
            Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(set.isCompleted ? Theme.success : .secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .frame(width: 40, height: 40)
        // A set is completable only once it has reps; un-completing stays allowed
        // so a mistaken tap is always reversible.
        .disabled(!set.isCompleted && set.reps == 0)
        .sensoryFeedback(.success, trigger: set.isCompleted) { _, new in new }
        .accessibilityLabel(set.isCompleted ? "Mark set incomplete" : "Complete set")
        .accessibilityHint(set.reps == 0 && !set.isCompleted ? "Enter reps first" : "")
    }

    // MARK: - Bindings

    /// Converts between canonical kg storage and the user's display unit.
    private var weightBinding: Binding<Double> {
        Binding(
            get: { settings.weightUnit.fromKilograms(set.weightKilograms) },
            set: { set.weightKilograms = settings.weightUnit.toKilograms(max(0, $0)) }
        )
    }

    private var repsBinding: Binding<Double> {
        Binding(
            get: { Double(set.reps) },
            set: { set.reps = max(0, Int($0)) }
        )
    }

    private var rpeBinding: Binding<Double?> {
        Binding(get: { set.rpe }, set: { set.rpe = $0 })
    }

    private let rpeOptions: [Double] = stride(from: 6.0, through: 10.0, by: 0.5).map { $0 }

    // MARK: - Focus

    /// weight → reps within a row; reps → dismiss (next set is one tap away).
    private func advanceFocus(from field: SetField) {
        switch field {
        case .weight: focus.wrappedValue = .reps(set.id)
        case .reps: focus.wrappedValue = nil
        }
    }
}
