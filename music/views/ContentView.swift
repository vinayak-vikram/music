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
    case playlists = "Playlists"

    var id: String { rawValue }
}

struct ContentView: View {
    @EnvironmentObject private var trackStore: TrackStore
    @EnvironmentObject private var playerManager: PlayerManager
    @EnvironmentObject private var playlistStore: PlaylistStore

    @State private var isShowingAddSourceSheet = false
    @State private var isShowingFileImporter = false
    @State private var isShowingImportError = false
    @State private var isShowingMetadataEditor = false
    @State private var isShowingIMSLPPanel = false
    @State private var trackBeingEdited = ""

    @State private var groupingMode: LibraryGrouping = .allTracks
    @State private var selectedGroupID: String?
    @State private var selectedAlbumID: String?
    @State private var selectedPlaylistID: UUID?

    @State private var isShowingNewPlaylistPrompt = false
    @State private var newPlaylistName = ""

    private var groups: [LibraryGroup] {
        switch groupingMode {
        case .allTracks, .playlists: return []
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

    private var selectedPlaylist: Playlist? {
        playlistStore.playlists.first { $0.id == selectedPlaylistID }
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
            selectedPlaylistID = nil
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
        .alert("New Playlist", isPresented: $isShowingNewPlaylistPrompt) {
            TextField("Playlist Name", text: $newPlaylistName)
            Button("Cancel", role: .cancel) { newPlaylistName = "" }
            Button("Create") {
                guard !newPlaylistName.isEmpty else { return }
                let playlist = playlistStore.createPlaylist(named: newPlaylistName)
                selectedPlaylistID = playlist.id
                newPlaylistName = ""
            }
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

            switch groupingMode {
            case .allTracks:
                Spacer()
                Label("Every track in your library", systemImage: "music.note.list")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding()
                Spacer()
            case .composer, .artist:
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
            case .playlists:
                HStack {
                    Text("Playlists")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        isShowingNewPlaylistPrompt = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)

                List(playlistStore.playlists, selection: $selectedPlaylistID) { playlist in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(playlist.name)
                            Text("\(playlist.tracks.count) track\(playlist.tracks.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "music.note.list")
                            .foregroundStyle(.tint)
                    }
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            playlistStore.deletePlaylist(playlist)
                            if selectedPlaylistID == playlist.id {
                                selectedPlaylistID = nil
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 200)
    }

    @ViewBuilder
    private var content: some View {
        switch groupingMode {
        case .allTracks:
            List(trackStore.tracks, id: \.self) { track in
                TrackRow(track: track) {
                    playerManager.play(track)
                } onEditMetadata: {
                    trackBeingEdited = track
                    isShowingMetadataEditor = true
                } onDelete: {
                    deleteTrackFromLibrary(track)
                }
            }
            .navigationTitle("All Tracks")
        case .composer, .artist:
            if let selectedGroup {
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
                                    playerManager.play(track)
                                } onEditMetadata: {
                                    trackBeingEdited = track
                                    isShowingMetadataEditor = true
                                } onDelete: {
                                    deleteTrackFromLibrary(track)
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
        case .playlists:
            if let selectedPlaylist {
                if selectedPlaylist.tracks.isEmpty {
                    ContentUnavailableView("No Tracks Yet", systemImage: "music.note.list")
                } else {
                    List(selectedPlaylist.tracks, id: \.self) { track in
                        TrackRow(track: track) {
                            playerManager.play(track, playlist: selectedPlaylist)
                        } onEditMetadata: {
                            trackBeingEdited = track
                            isShowingMetadataEditor = true
                        } onDelete: {
                            deleteTrackFromLibrary(track)
                        } onRemoveFromPlaylist: {
                            playlistStore.removeTrack(track, from: selectedPlaylist)
                        }
                    }
                }
            } else {
                ContentUnavailableView("Select a Playlist", systemImage: "music.note.list")
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch groupingMode {
        case .allTracks, .playlists:
            EmptyView()
        case .composer, .artist:
            if let selectedAlbum {
                List(selectedAlbum.tracks, id: \.self) { track in
                    TrackRow(track: track, subtitleStyle: groupedTrackSubtitleStyle) {
                        playerManager.play(track)
                    } onEditMetadata: {
                        trackBeingEdited = track
                        isShowingMetadataEditor = true
                    } onDelete: {
                        deleteTrackFromLibrary(track)
                    }
                }
                .navigationTitle(selectedAlbum.id)
            } else {
                ContentUnavailableView("Select \(secondaryLevelNameWithArticle)", systemImage: "rectangle.stack")
            }
        }
    }

    private func deleteTrackFromLibrary(_ track: String) {
        if playerManager.currentTrack == track {
            playerManager.stop()
        }
        deleteTrack(track)
        for playlist in playlistStore.playlists where playlist.tracks.contains(track) {
            playlistStore.removeTrack(track, from: playlist)
        }
        trackStore.refresh()
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
    let onPlay: () -> Void
    let onEditMetadata: () -> Void
    let onDelete: () -> Void
    var onRemoveFromPlaylist: (() -> Void)? = nil

    @EnvironmentObject private var playerManager: PlayerManager
    @EnvironmentObject private var playlistStore: PlaylistStore

    @State private var isShowingNewPlaylistPrompt = false
    @State private var newPlaylistName = ""

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
        Button(action: onPlay) {
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
            Menu("Add to Playlist") {
                ForEach(playlistStore.playlists) { playlist in
                    Button(playlist.name) {
                        playlistStore.addTrack(track, to: playlist)
                    }
                }
                if !playlistStore.playlists.isEmpty {
                    Divider()
                }
                Button("New Playlist…") {
                    isShowingNewPlaylistPrompt = true
                }
            }
            if let onRemoveFromPlaylist {
                Button("Remove from Playlist", role: .destructive, action: onRemoveFromPlaylist)
            }
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
        .alert("New Playlist", isPresented: $isShowingNewPlaylistPrompt) {
            TextField("Playlist Name", text: $newPlaylistName)
            Button("Cancel", role: .cancel) { newPlaylistName = "" }
            Button("Create") {
                guard !newPlaylistName.isEmpty else { return }
                let playlist = playlistStore.createPlaylist(named: newPlaylistName)
                playlistStore.addTrack(track, to: playlist)
                newPlaylistName = ""
            }
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
        .environmentObject(PlaylistStore())
}
