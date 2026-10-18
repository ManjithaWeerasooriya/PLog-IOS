//
//  DataTransferSection.swift
//  PLog
//
//  The "Data" section of Settings: export everything to a JSON backup, or import one.
//  Import is a full replace, so it previews what's in the file and confirms first.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataTransferSection: View {
    @Environment(\.modelContext) private var context

    @State private var exportDocument: BackupDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false

    /// A parsed backup waiting on the "Replace all data?" confirmation.
    @State private var pendingImport: PLogBackup?
    @State private var resultMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        Section {
            Button {
                exportData()
            } label: {
                Label("Export Data…", systemImage: "square.and.arrow.up")
            }
            Button {
                showingImporter = true
            } label: {
                Label("Import Data…", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Export saves your exercises, plans, logged workouts, profile and Progress layout as a JSON file. Importing a backup replaces everything currently in the app.")
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: DataBackup.suggestedFilename()
        ) { result in
            if case .failure(let error) = result {
                errorMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                loadBackup(at: url)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        // `.alert`, not `.confirmationDialog` — see AGENT.md on destructive confirmations.
        .alert("Replace All Data?", isPresented: isShowingImportConfirmation) {
            Button("Replace", role: .destructive, action: confirmImport)
            Button("Cancel", role: .cancel) { pendingImport = nil }
        } message: {
            if let backup = pendingImport {
                Text(importSummary(for: backup))
            }
        }
        .alert("Import Complete", isPresented: isShowingResult) {
            Button("OK", role: .cancel) { resultMessage = nil }
        } message: {
            Text(resultMessage ?? "")
        }
        .alert("Something Went Wrong", isPresented: isShowingError) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Actions

    private func exportData() {
        do {
            exportDocument = BackupDocument(data: try DataBackup.export(from: context))
            showingExporter = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Reads and validates the picked file, then stages it for confirmation. The URL from
    /// the picker is security-scoped, so access has to be opened around the read.
    private func loadBackup(at url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            guard let data = try? Data(contentsOf: url) else {
                throw DataBackup.ImportError.unreadableFile
            }
            pendingImport = try DataBackup.decode(data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func confirmImport() {
        guard let backup = pendingImport else { return }
        pendingImport = nil
        do {
            try DataBackup.restore(backup, into: context)
            resultMessage = "Restored \(importSummary(for: backup, leadIn: ""))"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importSummary(for backup: PLogBackup, leadIn: String = "This backup has ") -> String {
        let parts = [
            count(backup.exercises.count, "exercise"),
            count(backup.plans.count, "plan"),
            count(backup.workouts.count, "workout"),
            count(backup.setCount, "set"),
        ]
        let list = parts.joined(separator: ", ")
        let from = backup.exportedAt.formatted(date: .abbreviated, time: .shortened)
        return "\(leadIn)\(list) (exported \(from)).\(leadIn.isEmpty ? "" : " Everything currently in PLog will be replaced.")"
    }

    private func count(_ n: Int, _ noun: String) -> String {
        "\(n) \(noun)\(n == 1 ? "" : "s")"
    }

    // MARK: - Alert bindings

    private var isShowingImportConfirmation: Binding<Bool> {
        Binding(
            get: { pendingImport != nil },
            set: { if !$0 { pendingImport = nil } }
        )
    }

    private var isShowingResult: Binding<Bool> {
        Binding(
            get: { resultMessage != nil },
            set: { if !$0 { resultMessage = nil } }
        )
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

/// Wraps the exported JSON for `.fileExporter`. `nonisolated` because `FileDocument`'s
/// requirements are nonisolated and the project defaults to main-actor isolation.
nonisolated struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    Form {
        DataTransferSection()
    }
    .modelContainer(SampleData.container)
}
