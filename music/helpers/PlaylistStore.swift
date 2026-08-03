//
//  PlaylistStore.swift
//  music
//
//  Created by Vinayak Vikram on 8/3/26.
//

import Combine
import Foundation

struct Playlist: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var tracks: [String]
}

private func listsFileURL() -> URL? {
    dataDirectoryURL()?.appendingPathComponent("lists.json")
}

private func loadPlaylistsFromDisk() -> [Playlist] {
    guard let url = listsFileURL(), let data = try? Data(contentsOf: url) else { return [] }
    return (try? JSONDecoder().decode([Playlist].self, from: data)) ?? []
}

private func savePlaylistsToDisk(_ playlists: [Playlist]) {
    guard let url = listsFileURL(), let data = try? JSONEncoder().encode(playlists) else { return }
    try? data.write(to: url, options: .atomic)
}

@MainActor
final class PlaylistStore: ObservableObject {
    @Published private(set) var playlists: [Playlist] = []

    init() {
        refresh()
    }

    func refresh() {
        playlists = loadPlaylistsFromDisk()
    }

    @discardableResult
    func createPlaylist(named name: String) -> Playlist {
        let playlist = Playlist(name: name, tracks: [])
        playlists.append(playlist)
        savePlaylistsToDisk(playlists)
        return playlist
    }

    func rename(_ playlist: Playlist, to newName: String) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].name = newName
        savePlaylistsToDisk(playlists)
    }

    func deletePlaylist(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
        savePlaylistsToDisk(playlists)
    }

    func addTrack(_ track: String, to playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }),
              !playlists[index].tracks.contains(track)
        else { return }
        playlists[index].tracks.append(track)
        savePlaylistsToDisk(playlists)
    }

    func removeTrack(_ track: String, from playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].tracks.removeAll { $0 == track }
        savePlaylistsToDisk(playlists)
    }
}
