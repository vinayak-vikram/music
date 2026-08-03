//
//  IMSLPPanelView.swift
//  music
//
//  Created by Vinayak Vikram on 8/3/26.
//

import SwiftUI

struct IMSLPPanelView: View {
    @EnvironmentObject private var trackStore: TrackStore
    @ObservedObject private var client = IMSLPClient.shared

    @State private var hasCredentials = loadIMSLPCredentials() != nil
    @State private var usernameField = ""
    @State private var passwordField = ""

    @State private var searchQuery = ""
    @State private var composers: [IMSLPComposer] = []
    @State private var selectedComposerID: String?
    @State private var workTitles: [String] = []
    @State private var selectedWorkTitle: String?
    @State private var currentWork: IMSLPWork?

    @State private var isSearching = false
    @State private var isLoadingWorks = false
    @State private var isLoadingWork = false
    @State private var errorMessage: String?
    @State private var downloadingIDs: Set<UUID> = []
    @State private var downloadedIDs: Set<UUID> = []

    var body: some View {
        Group {
            if hasCredentials {
                browser
            } else {
                credentialsSetup
            }
        }
        .frame(minWidth: 900, idealWidth: 1000, minHeight: 480, idealHeight: 560)
    }

    private var credentialsSetup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connect Your IMSLP Account")
                .font(.headline)
            Text("Downloading recordings requires your IMSLP membership login.")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("Username", text: $usernameField)
            SecureField("Password", text: $passwordField)
            Button("Save") {
                saveIMSLPCredentials(IMSLPCredentials(username: usernameField, password: passwordField))
                hasCredentials = true
            }
            .disabled(usernameField.isEmpty || passwordField.isEmpty)
            .keyboardShortcut(.defaultAction)
        }
        .padding()
        .frame(width: 320)
    }

    private var browser: some View {
        NavigationSplitView {
            composerPane
                .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } content: {
            workPane
                .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        } detail: {
            recordingsPane
                .navigationSplitViewColumnWidth(min: 280, ideal: 420)
        }
    }

    private var composerPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Search composers…", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .padding(12)
                .onSubmit(searchComposers)

            if isSearching {
                ProgressView().padding()
            }

            List(composers, selection: $selectedComposerID) { composer in
                Text(composer.displayName)
            }
            .listStyle(.sidebar)
        }
        .onChange(of: selectedComposerID) { _, newValue in
            loadWorks(for: newValue)
        }
    }

    @ViewBuilder
    private var workPane: some View {
        if isLoadingWorks {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let selectedComposerID {
            List(workTitles, id: \.self, selection: $selectedWorkTitle) { title in
                Text(title)
            }
            .navigationTitle(selectedComposerID)
            .onChange(of: selectedWorkTitle) { _, newValue in
                loadWork(title: newValue, composer: selectedComposerID)
            }
        } else {
            ContentUnavailableView("Select a Composer", systemImage: "person.crop.square")
        }
    }

    private var recordingsPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding()
            }
            recordingsContent
        }
        .navigationTitle(currentWork?.title ?? "")
    }

    @ViewBuilder
    private var recordingsContent: some View {
        if isLoadingWork {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let currentWork {
            if currentWork.recordings.isEmpty {
                ContentUnavailableView("No Recordings Found", systemImage: "music.note")
            } else {
                List(currentWork.recordings) { recording in
                    recordingRow(recording, work: currentWork)
                }
            }
        } else {
            ContentUnavailableView("Select a Work", systemImage: "music.note")
        }
    }

    private func recordingRow(_ recording: IMSLPRecording, work: IMSLPWork) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(recording.movement ?? "Complete Performance")
                let subtitle = [recording.album, recording.artist].compactMap { $0 }.joined(separator: " — ")
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let duration = recording.duration {
                Text(formattedDuration(duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if downloadingIDs.contains(recording.id) {
                ProgressView()
                    .controlSize(.small)
            } else if downloadedIDs.contains(recording.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button {
                    download(recording, work: work)
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func searchComposers() {
        isSearching = true
        errorMessage = nil
        Task {
            do {
                composers = try await client.searchComposers(matching: searchQuery)
            } catch {
                errorMessage = error.localizedDescription
            }
            isSearching = false
        }
    }

    private func loadWorks(for composerID: String?) {
        workTitles = []
        selectedWorkTitle = nil
        currentWork = nil
        guard let composerID, let composer = composers.first(where: { $0.id == composerID }) else { return }

        isLoadingWorks = true
        errorMessage = nil
        Task {
            do {
                if !client.isLoggedIn {
                    try await client.login()
                }
                workTitles = try await client.fetchWorkTitles(for: composer)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoadingWorks = false
        }
    }

    private func loadWork(title: String?, composer composerID: String?) {
        currentWork = nil
        guard let title, let composerID else { return }

        isLoadingWork = true
        errorMessage = nil
        Task {
            do {
                currentWork = try await client.fetchWork(title: title, composer: composerID)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoadingWork = false
        }
    }

    private func download(_ recording: IMSLPRecording, work: IMSLPWork) {
        downloadingIDs.insert(recording.id)
        errorMessage = nil
        Task {
            defer { downloadingIDs.remove(recording.id) }
            do {
                let tempURL = try await client.downloadRecording(recording)
                let imported = importTrack(from: tempURL)
                try? FileManager.default.removeItem(at: tempURL)
                guard imported else {
                    errorMessage = "Couldn't add the downloaded file (is ffmpeg installed?)."
                    return
                }
                let importedName = tempURL.deletingPathExtension().lastPathComponent + ".mp3"
                saveMetadata(trackMetadata(for: recording, work: work), for: importedName)
                trackStore.refresh()
                downloadedIDs.insert(recording.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private func formattedDuration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded())
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%d:%02d", minutes, secs)
}

#Preview {
    IMSLPPanelView()
        .environmentObject(TrackStore())
}
