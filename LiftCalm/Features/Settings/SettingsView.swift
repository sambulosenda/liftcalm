//
//  SettingsView.swift
//  LiftCalm
//
//  Preferences, data export, and the privacy/disclaimer surface. Everything is
//  local by default — reinforced here so users trust where their data lives.
//

import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(NotificationManager.self) private var notifications
    @Environment(StoreManager.self) private var store
    @Environment(\.presentPaywall) private var presentPaywall
    @Query(filter: #Predicate<Workout> { $0.endedAt != nil }) private var finishedWorkouts: [Workout]

    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Weight Unit", selection: $settings.weightUnit) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                }

                plusSection

                Section {
                    Stepper(
                        "Default rest: \(Formatting.clock(settings.defaultRestSeconds))",
                        value: $settings.defaultRestSeconds,
                        in: 15...600,
                        step: 15
                    )
                    Toggle("Auto-start rest timer", isOn: $settings.autoStartRest)
                    Toggle("Rest haptics", isOn: $settings.restHaptics)
                } header: {
                    Text("Rest Timer")
                } footer: {
                    Text("The timer starts automatically when you complete a set.")
                }

                Section {
                    Toggle("Rest timer alerts", isOn: $settings.restNotifications)
                        .onChange(of: settings.restNotifications) { _, on in
                            if on { Task { await notifications.requestAuthorization() } }
                        }
                    Toggle("Workout reminders", isOn: $settings.workoutReminderEnabled)
                        .onChange(of: settings.workoutReminderEnabled) { _, on in
                            if on {
                                notifications.scheduleDailyReminder(
                                    hour: settings.reminderHour, minute: settings.reminderMinute)
                            } else {
                                notifications.cancelDailyReminder()
                            }
                        }
                    if settings.workoutReminderEnabled {
                        DatePicker("Reminder time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    if notifications.authorizationStatus == .denied {
                        Text("Notifications are turned off. Enable them in iOS Settings to get rest and reminder alerts.")
                    } else {
                        Text("Rest alerts fire even when LiftCalm is in the background.")
                    }
                }

                Section("Training Profile") {
                    Picker("Experience", selection: $settings.experienceLevel) {
                        ForEach(ExperienceLevel.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    Picker("Goal", selection: $settings.goal) {
                        ForEach(TrainingGoal.allCases) { goal in
                            Text(goal.displayName).tag(goal)
                        }
                    }
                }

                Section {
                    exportButton("Export as CSV", systemImage: "tablecells", format: .csv)
                    exportButton("Export as JSON", systemImage: "curlybraces", format: .json)
                } header: {
                    Text("Your Data")
                } footer: {
                    Text("Export every workout. Weights are in kilograms. Stored only on this device.")
                }

                Section {
                    Label("All data stays on your device", systemImage: "lock.shield")
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("LiftCalm is not medical advice. Consult a professional before starting any program.")
                }
            }
            .navigationTitle("Settings")
            .sheet(item: $exportFile) { file in
                ExportShareSheet(file: file)
            }
            .alert("Export failed", isPresented: .constant(exportError != nil)) {
                Button("OK") { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
        }
    }

    @ViewBuilder
    private var plusSection: some View {
        Section {
            if store.isPlus {
                HStack {
                    Label("LiftCalm Plus", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Text("Unlocked")
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    presentPaywall(.generic)
                } label: {
                    HStack {
                        Label("Unlock LiftCalm Plus", systemImage: "sparkles")
                        Spacer()
                        if let price = store.plusProduct?.displayPrice {
                            Text(price).foregroundStyle(.secondary)
                        }
                    }
                }
                Button("Restore Purchases") { Task { await store.restore() } }
            }
        } header: {
            Text("LiftCalm Plus")
        } footer: {
            if store.isPlus {
                Text("Thanks for supporting LiftCalm. Every Plus feature is yours.")
            } else {
                Text("Unlimited routines, the full recovery breakdown, and more — a one-time unlock.")
            }
        }
    }

    /// Bridges the stored hour/minute to the DatePicker and reschedules on change.
    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    from: DateComponents(hour: settings.reminderHour, minute: settings.reminderMinute)
                ) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                settings.reminderHour = parts.hour ?? 18
                settings.reminderMinute = parts.minute ?? 0
                if settings.workoutReminderEnabled {
                    notifications.scheduleDailyReminder(
                        hour: settings.reminderHour, minute: settings.reminderMinute)
                }
            }
        )
    }

    private func exportButton(_ title: String, systemImage: String, format: DataExport.Format) -> some View {
        Button {
            export(format)
        } label: {
            Label(title, systemImage: systemImage)
        }
        .disabled(finishedWorkouts.isEmpty)
    }

    private func export(_ format: DataExport.Format) {
        do {
            exportFile = try DataExport.makeFile(finishedWorkouts, format: format)
        } catch {
            exportError = error.localizedDescription
        }
    }
}

/// Wraps a ShareLink so export presents in a sheet once the file is ready.
private struct ExportShareSheet: View {
    let file: ExportFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up.on.square")
                    .font(.system(size: 52))
                    .foregroundStyle(Theme.accent)
                Text("Your export is ready")
                    .font(.headline)
                ShareLink(item: file.url) {
                    Label("Share File", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminentCompat)
                .controlSize(.large)
            }
            .padding(28)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    SettingsView()
        .modelContainer(PreviewData.container)
        .environment(AppSettings())
        .environment(NotificationManager())
        .environment(StoreManager())
}
