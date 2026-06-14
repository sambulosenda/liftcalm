//
//  SettingsView.swift
//  LiftCalm
//
//  Preferences, data export, and the privacy/disclaimer surface. Everything is
//  local by default — reinforced here so users trust where their data lives.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
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
}
