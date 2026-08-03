//
//  ContentView.swift
//  music
//
//  Created by Vinayak Vikram on 8/2/26.
//

import SwiftUI
import UniformTypeIdentifiers

private enum LibraryGrouping: String, CaseIterable, Identifiable {
    case allTracks = "All Tracks"
    case composer = "Composer"
    case artist = "Artist"

    var id: String { rawValue }
}

struct ContentView: View {
    @EnvironmentObject private var trackStore: TrackStore
    @EnvironmentObject private var playerManager: PlayerManager

    @State private var isShowingAddSourceSheet = false
    @State private var isShowingFileImporter = false
    @State private var isShowingImportError = false
    @State private var isShowingMetadataEditor = false
    @State private var isShowingIMSLPPanel = false
    @State private var trackBeingEdited = ""

    @State private var groupingMode: LibraryGrouping = .allTracks
    @State private var selectedGroupID: String?
    @State private var selectedAlbumID: String?

    private var groups: [LibraryGroup] {
        switch groupingMode {
        case .allTracks: return []
        case .composer: return groupedLibrary(tracks: trackStore.tracks, by: .composer)
        case .artist: return groupedLibrary(tracks: trackStore.tracks, by: .artist)
        }
    }

    private var selectedGroup: LibraryGroup? {
        groups.first { $0.id == selectedGroupID }
    }

    private var selectedAlbum: AlbumGroup? {
        selectedGroup?.albums.first { $0.id == selectedAlbumID }
    }

    private var groupedTrackSubtitleStyle: TrackSubtitleStyle {
        groupingMode == .composer ? .artistOnly : .hidden
    }

    private var secondaryLevelName: String {
        groupingMode == .composer ? "Piece" : "Album"
    }

    private var groupLevelNameWithArticle: String {
        groupingMode == .composer ? "a Composer" : "an Artist"
    }

    private var secondaryLevelNameWithArticle: String {
        groupingMode == .composer ? "a Piece" : "an Album"
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            content
        } detail: {
            detail
        }
        .onAppear {
            trackStore.refresh()
        }
        .onChange(of: groupingMode) { _, _ in
            selectedGroupID = nil
            selectedAlbumID = nil
        }
        .onChange(of: selectedGroupID) { _, _ in
            selectedAlbumID = nil
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    isShowingAddSourceSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                Button {
                    trackStore.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                Button {
                    isShowingIMSLPPanel = true
                } label: {
                    Image(systemName: "opticaldisc")
                }
            }
        }
        .sheet(isPresented: $isShowingAddSourceSheet) {
            AddTrackSourceView {
                isShowingAddSourceSheet = false
                isShowingFileImporter = true
            }
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.audio, .movie],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                if importTrack(from: url) {
                    trackStore.refresh()
                } else {
                    isShowingImportError = true
                }
            }
        }
        .alert("Couldn't Add Track", isPresented: $isShowingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("install ffmpeg (via brew, etc.)")
        }
        .sheet(isPresented: $isShowingMetadataEditor) {
            MetadataEditView(track: trackBeingEdited)
        }
        .sheet(isPresented: $isShowingIMSLPPanel) {
            IMSLPPanelView()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Browse", selection: $groupingMode) {
                ForEach(LibraryGrouping.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)

            if groupingMode == .allTracks {
                Spacer()
                Label("Every track in your library", systemImage: "music.note.list")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding()
                Spacer()
            } else {
                List(groups, selection: $selectedGroupID) { group in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.id)
                            Text("\(group.albums.count) \(secondaryLevelName.lowercased())\(group.albums.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.tint)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 200)
    }

    @ViewBuilder
    private var content: some View {
        if groupingMode == .allTracks {
            List(trackStore.tracks, id: \.self) { track in
                TrackRow(track: track) {
                    trackBeingEdited = track
                    isShowingMetadataEditor = true
                }
            }
            .navigationTitle("All Tracks")
        } else if let selectedGroup {
            List(selection: $selectedAlbumID) {
                if !selectedGroup.albums.isEmpty {
                    Section("\(secondaryLevelName)s") {
                        ForEach(selectedGroup.albums) { album in
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(album.id)
                                    Text("\(album.tracks.count) track\(album.tracks.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "rectangle.stack.fill")
                                    .foregroundStyle(.tint)
                            }
                            .tag(album.id)
                        }
                    }
                }
                if !selectedGroup.singles.isEmpty {
                    Section("Singles") {
                        ForEach(selectedGroup.singles, id: \.self) { track in
                            TrackRow(track: track, subtitleStyle: groupedTrackSubtitleStyle) {
                                trackBeingEdited = track
                                isShowingMetadataEditor = true
                            }
                        }
                    }
                }
            }
            .navigationTitle(selectedGroup.id)
        } else {
            ContentUnavailableView(
                "Select \(groupLevelNameWithArticle)",
                systemImage: "folder"
            )
        }
    }

    @ViewBuilder
    private var detail: some View {
        if groupingMode == .allTracks {
            EmptyView()
        } else if let selectedAlbum {
            List(selectedAlbum.tracks, id: \.self) { track in
                TrackRow(track: track, subtitleStyle: groupedTrackSubtitleStyle) {
                    trackBeingEdited = track
                    isShowingMetadataEditor = true
                }
            }
            .navigationTitle(selectedAlbum.id)
        } else {
            ContentUnavailableView("Select \(secondaryLevelNameWithArticle)", systemImage: "rectangle.stack")
        }
    }
}

private enum TrackSubtitleStyle {
    case artistAndAlbum
    case artistOnly
    case hidden
}

private struct TrackRow: View {
    let track: String
    var subtitleStyle: TrackSubtitleStyle = .artistAndAlbum
    let onEditMetadata: () -> Void

    @EnvironmentObject private var playerManager: PlayerManager

    private var subtitle: String? {
        switch subtitleStyle {
        case .hidden:
            return nil
        case .artistOnly:
            let artist = cachedMetadata(for: track)?.artist
            return (artist?.isEmpty == false) ? artist : nil
        case .artistAndAlbum:
            return trackSubtitle(for: track)
        }
    }

    var body: some View {
        Button {
            playerManager.play(track)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(resolvedTitle(for: track))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if track == playerManager.currentTrack {
                    Spacer()
                    Image(systemName: playerManager.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                        .foregroundStyle(.tint)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit Metadata…", action: onEditMetadata)
        }
    }
}

private struct AddTrackSourceView: View {
    let onSelectDisk: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Track From")
                .font(.headline)
            Button("Disk") {
                onSelectDisk()
            }
        }
        .padding()
        .frame(width: 240)
    }
}

#Preview {
    ContentView()
        .environmentObject(TrackStore())
        .environmentObject(PlayerManager())
}
